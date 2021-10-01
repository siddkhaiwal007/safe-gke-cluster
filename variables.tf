#########
# Project Metadata
#########
variable "creds_file" {
    default = "cloudmatos-demoblog-904b756a20fd.json"
}
variable "project_id" {
    type        = string
    description = "Project ID where the network resides"
    default     = "test-cm-project"
}
variable "region" {
    type        = string
    default     = "us-west3"
}

#########
# Other varibales
#########
variable "k8s_prefix" {
    type        = string
    default     = "scgke"
}

locals {
    zones = ["${var.region}-a", "${var.region}-b", "${var.region}-c"]
    network_name = "${var.k8s_prefix}-vpc"
    shared_vpc_host = null
    cluster_name = "${var.k8s_prefix}-k8s"
    service_account = "${var.k8s_prefix}-k8s-admin"
    node_locations = "${var.region}-a,${var.region}-b,${var.region}-c"

    firewall_rules = [
        {
          name          = "iap-ssh-access"
          description   = "Allow SSH access to instances through the IAP system"
          ports         = ["22"]
          target_tags   = ["ssh-ingress"]
          source_ranges = ["35.235.240.0/20","0.0.0.0/0"] #GCP IAP Service Range
        },
        {
          name          = "http-access"
          description   = "Allow HHTP access to instances through the IAP system"
          ports         = ["80"]
          target_tags   = ["http-server"]
          source_ranges = ["0.0.0.0/0"] # open to all
        },
        {
          name          = "https-access"
          description   = "Allow HHTPS access to instances through the IAP system"
          ports         = ["443"]
          target_tags   = ["https-server"]
          source_ranges = ["0.0.0.0/0"] # open to all
        },
    ]

    service_subnets_final = [
        {
            subnet_name           = "${var.k8s_prefix}-subnet-01"
            subnet_ip             = "10.2.0.0/16"
            subnet_region         = "${var.region}"
            subnet_private_access = "true"
        },
        {
            subnet_name           = "${var.k8s_prefix}-subnet-02"
            subnet_ip             = "10.3.0.0/16"
            subnet_region         = "${var.region}"
            subnet_private_access = "true"
            subnet_flow_logs      = "true"
            description           = "This subnet has a description"
            role                  = "ACTIVE"
        }
    ]

    service_subnet_secondary_ranges = {
        "${var.k8s_prefix}-subnet-01" = [
            {
                range_name    = "${var.k8s_prefix}-subnet-01-pods"
                ip_cidr_range = "10.4.0.0/16"
            },
            {
                range_name    = "${var.k8s_prefix}-subnet-01-services"
                ip_cidr_range = "10.5.0.0/16"
            }
        ]
    }

    routes_final = [
        {
            name                   = "${var.k8s_prefix}-egress-internet"
            description            = "route through IGW to access internet"
            destination_range      = "0.0.0.0/0"
            tags                   = "egress-inet"
            next_hop_internet      = "true"
        }
    ]
}

variable "service_account_iam_roles" {
  type = list

  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/iam.serviceAccountUser"
  ]
  description = <<-EOF
  List of the default IAM roles to attach to the service account on the
  GKE Nodes.
  EOF
}

variable "service_account_custom_iam_roles" {
  type = list
  default = []

  description = <<-EOF
  List of arbitrary additional IAM roles to attach to the service account on
  the GKE nodes.
  EOF
}

variable "project_services" {
  type = list

  default = [
    "cloudresourcemanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "container.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "sqladmin.googleapis.com",
    "securetoken.googleapis.com",
  ]
  description = <<-EOF
  The GCP APIs that should be enabled in this project.
  EOF
}

variable "master_ipv4_cidr_block" {
    type = string
    default = "10.0.0.0/28"
}

variable "master_authorized_networks" {
    type =list(map(string))
    default = [{ cidr_block ="0.0.0.0/0",display_name = "mypublicip"}]
}

variable "node_pools_tags" {
    type = list
    default= ["egress-inet"]
}
