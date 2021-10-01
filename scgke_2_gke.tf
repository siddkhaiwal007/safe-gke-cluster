locals {
  # Get environment specific files in current directory
  nodepool_files = fileset(path.module, "/data/dev/**.yaml")
  # Parse out for defined type of nodepool
  nodepool_map = {
    for nodepool_files in local.nodepool_files :
    yamldecode(file(nodepool_files))["name"] => yamldecode(file(nodepool_files))
    if yamldecode(file(nodepool_files))["type"] == "nodepool"
  }
}

data "google_client_config" "default" {}

provider "kubernetes" {
  host  = "https://${module.gke.endpoint}"
  token = data.google_client_config.default.access_token

  cluster_ca_certificate = base64decode(
    module.gke.ca_certificate
  )
}

data "google_project" "service_project" {
  project_id = var.project_id
}

// Create a service account with hard coded role and account id.
resource "google_service_account" "gke-sa" {
  project = var.project_id
  account_id = local.service_account
  display_name = "GKE Admin & Security Service Account"
}

// Add the service account to the project
resource "google_project_iam_member" "service-account" {
  count   = length(var.service_account_iam_roles)
  project = var.project_id
  role    = element(var.service_account_iam_roles, count.index)
  member  = format("serviceAccount:%s", google_service_account.gke-sa.email)
}

// Add user-specified roles
resource "google_project_iam_member" "service-account-custom" {
  count   = length(var.service_account_custom_iam_roles)
  project = var.project_id
  role    = element(var.service_account_custom_iam_roles, count.index)
  member  = format("serviceAccount:%s", google_service_account.gke-sa.email)
}

// Enable required services on the project
resource "google_project_service" "service" {
  count   = length(var.project_services)
  project = var.project_id
  service = element(var.project_services, count.index)

  // Do not disable the service on destroy. On destroy, we are going to
  // destroy the project, but we need the APIs available to destroy the
  // underlying resources.
  disable_on_destroy = false
}

module "gke" {
  source                            = "terraform-google-modules/kubernetes-engine/google//modules/beta-private-cluster-update-variant"
  project_id                        = var.project_id
  name                              = local.cluster_name
  region                            = var.region
  zones                             = local.zones
  network                           = module.vpc.network_name
  subnetwork                        = "${var.k8s_prefix}-subnet-01"
  ip_range_pods                     = "${var.k8s_prefix}-subnet-01-pods"
  ip_range_services                 = "${var.k8s_prefix}-subnet-01-services"
  http_load_balancing               = false
  horizontal_pod_autoscaling        = true
  network_policy                    = true
  enable_private_endpoint           = false
  enable_private_nodes              = true
  master_ipv4_cidr_block            = var.master_ipv4_cidr_block
  master_authorized_networks        = var.master_authorized_networks
  istio                             = true
  cloudrun                          = false
  dns_cache                         = false
  enable_shielded_nodes	            = true
  remove_default_node_pool          = true
  disable_legacy_metadata_endpoints = false
  create_service_account            = true
  add_cluster_firewall_rules        = true
  firewall_inbound_ports            = ["9443", "15017"]
  # Hardening parameters
  enable_intranode_vivibility       = true
  release_channel                   = "STABLE"
  maintetenance_start_time          = "2021-09-25T23:00:00Z"
  maintetenance_end_time            = "2021-09-25T05:00:00Z"
  maintetenance_recurrence          = "FREQ=WEEKLY;BYDAY=SA,SU"
  node_metadata                     = "GKE_METADATA_SERVER"

  node_pools = [
    for nodepool in local.nodepool_map :
    {
      name                          = nodepool["name"]
      machine_type                  = nodepool["machine_type"]
      min_count                     = nodepool["min_count"]
      max_count                     = nodepool["max_count"]
      max_pods_per_node             = nodepool["pods_per_node"]
      local_ssd_count               = nodepool["local_ssd_count"]
      local_ssd_ephemeral_count     = nodepool["local_ssd_ephemeral_count"]
      disk_size_gb                  = nodepool["disk_size_gb"]
      disk_type                     = nodepool["disk_type"] 
      image_type                    = nodepool["image_type"]
      initial_node_count            = nodepool["initial_node_count"]
      enable_secure_boot            = true
      ip_allocation_policy          = true
      pod_security_policy_config    = true
      auto_upgrade                  = true
      workload_metadata_config      = "SECURE"
      disable_legacy_endpoints      = true
      preemptible                   = false
      service_account = google_service_account.gke-sa.email
    }
  ]

  node_pools_oauth_scopes = {
    all = []
    default-node-pool = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  node_pools_labels = {
    for nodepool in local.nodepool_map :
	"dev-$(nodepool["name"]}" => {
	  cost_center = "it-dev"
	  tier        = local.tier
	  is_public   = false
	  owner       = nodepool["team_dist"]
	  product     = nodepool["product"]
	}
  }
  
  node_pools_metadata = {
    for nodepool in local.nodepool_map :
	"dev-$(nodepool["name"]}" => {
	}
  }
  
  node_pools_taints = {
    all = []
  }
  node_pools_tags = {
    all = var.node_pools_tags
  }

  depends_on = [
    module.vpc,
    module.service_subnets,
    google_service_account.gke-sa,
    google_project_iam_member.service-account
  ]
}


module "workload_identity_existing_gsa" {
  source              = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  project_id          = var.project_id
  name                = google_service_account.gke-sa.account_id
  use_existing_gcp_sa = true

  # wait till custom GSA is created to force module data source read during apply
  depends_on = [google_service_account.gke-sa]
}

# example without existing KSA
module "workload_identity" {
  source              = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  project_id          = var.project_id
  name                = "iden-${module.gke.name}"
  namespace           = "default"
  use_existing_k8s_sa = false
}

# Deploying gatekeeper using helm charts and applying OPA policy to apply taint using node selector
module "gatekeeper" {
  count                         = var.enable_gatekeeper ? 1 : 0
  source                        = ".//modules/k8s-gatekeeper"
  gke_project_id                = var.project_id
  vpc_project_id                = module.vpc.network_name
  cluster_name                  = local.cluster_name
  gke_region                    = var.region
  namespace                     = var.gatekeeper_namespace
  helm_release_name             = var.gatekeeper_helm_release_name
  depends_on = [
    module.workload_identity
  ]
}