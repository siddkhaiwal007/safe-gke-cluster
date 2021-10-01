resource "google_compute_firewall" "rule" {
  project = var.project_id
  network = var.network_name

  name        = var.name
  description = var.description
  priority    = var.priority
  direction   = var.direction

  target_tags             = var.target_tags
  target_service_accounts = var.target_service_accounts

  source_tags             = local.source_tags
  source_service_accounts = local.source_service_accounts
  source_ranges           = local.source_ranges

  destination_ranges = local.destination_ranges

  dynamic "allow" {
    for_each = local.allow_block
    content {
      protocol = allow.value.protocol
      ports    = allow.value.ports
    }
  }

  dynamic "deny" {
    for_each = local.deny_block
    content {
      protocol = deny.value.protocol
      ports    = deny.value.ports
    }
  }
}
