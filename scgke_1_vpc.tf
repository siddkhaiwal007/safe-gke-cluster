// Creating VPC and subnet
module "vpc" {
  source  = "terraform-google-modules/network/google//modules/vpc"

  project_id                             = var.project_id
  network_name                           = local.network_name
  shared_vpc_host                        = local.shared_vpc_host == null ? "false" : "true"
  delete_default_internet_gateway_routes = true
}

module "service_subnets" {
  source  = "terraform-google-modules/network/google//modules/subnets-beta"

  project_id       = var.project_id
  network_name     = module.vpc.network_name
  subnets          = local.service_subnets_final
  secondary_ranges = local.service_subnet_secondary_ranges
}

module "routes" {
  source  = "terraform-google-modules/network/google//modules/routes"

  project_id        = var.project_id
  routes            = local.routes_final
  network_name      = module.vpc.network_name
  module_depends_on = [module.service_subnets.subnets]
}

#########
# Network Default Firewall rules
module "network_firewall_rule" {
  source = "./modules/terraform-google-cwan-network-firewall-rule"
  network_name = module.vpc.network_name
  for_each = {
    for rule in local.firewall_rules :
    rule.name => rule
  }

  name          = each.value.name
  description   = each.value.description
  ports         = each.value.ports
  target_tags   = each.value.target_tags
  source_ranges = each.value.source_ranges
}
