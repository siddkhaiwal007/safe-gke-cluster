variable "project_id" {
    type        = string
    description = "Project ID where the network resides"
    default     = "test-cm-project"
}
variable "k8s_prefix" {
    type        = string
    default     = "scgke"
}
variable "network_name" {
  type        = string
  description = "Name of the network this firewall rule will be associated with"
}

locals {
    firewall_description = "${var.description} Managed by Terraform cwan-network-firewall-rule"

    allow_block = var.action == "allow" ? {
      allow = {
        protocol = var.protocol
        ports    = var.ports
      }
    } : {}
    deny_block = var.action == "deny" ? {
      allow = {
        protocol = var.protocol
        ports    = var.ports
      }
    } : {}

    # Setup precidence of source filters
    source_tags = var.direction == "INGRESS" ? var.source_tags : null
    source_service_accounts = var.direction == "INGRESS" ? (
      local.source_tags == null ? var.source_service_accounts : null
    ) : null
    source_ranges = var.direction == "INGRESS" ? (
      local.source_service_accounts == null ? var.source_ranges : null
    ) : null

    destination_ranges = var.direction == "EGRESS" ? var.destination_ranges : null
}

#########
# Firewall Rule Config
#########
variable "name" {
  type        = string
  description = "Name of the firewall rule"
  default     = "scgke_firewall"
}
variable "description" {
  type        = string
  description = "Brief description of the use and need for this rule"
  default     = "Firewall Rules"
}
variable "priority" {
  type        = number
  description = "Integer value of the firewall rule priority"
  default     = 1000
}
variable "direction" {
  type        = string
  description = "Direction of traffic for the firewall rule, must be `INGRESS` or `EGRESS`"
  default     = "INGRESS"
  validation {
    condition     = can(regex("^(INGRESS)|(EGRESS)$", var.direction))
    error_message = "`direction` must be set to either INGRESS or EGRESS."
  }
}
variable "action" {
  type        = string
  description = "Action for firewall to take, must be `allow` or `deny`"
  default     = "allow"
  validation {
    condition     = can(regex("^(allow)|(deny)$", var.action))
    error_message = "`action` must be set to either allow or deny."
  }
}
variable "protocol" {
  type        = string
  description = <<EOT
    (Required) The IP protocol to which this rule applies.
    The protocol type is required when creating a firewall rule.
    This value can either be one of the following well known protocol strings (tcp, udp, icmp)
    EOT
  default     = "tcp"
  validation {
    condition     = can(regex("^(tcp)|(udp)|(icmp)$", var.protocol))
    error_message = "`protocol` must be set to either tcp, udp, or icmp."
  }
}
variable "ports" {
  type        = list(string)
  description = <<EOT
    (Required for TCP or UDP) list of ports to which this rule applies.
    This field is only applicable for UDP or TCP protocol.
    Each entry must be either an integer or a range.
    If not specified, this rule applies to connections through any port.
    EOT
  default     = null
}

#########
# Network resource targets
#########
variable "target_tags" {
  type        = list(string)
  description = "List of network tags this firewall rule will target. target_tags and target_service_accounts are mutualy exclusive, only one may be specified."
  default     = null
}
variable "target_service_accounts" {
  type        = list(string)
  description = "List of service tags this firewall rule will target. target_tags and target_service_accounts are mutualy exclusive, only one may be specified."
  default     = null
}

#########
# Ingress source filters
#########
variable "source_tags" {
  type        = list(string)
  description = <<EOT
    (Optional) If source tags are specified, the firewall will apply only to traffic with source IP that belongs to a tag listed in source tags.
    If source_tags, source_service_accounts, and source_ranges are specified precidence order will be inforced: source_tags -> source_service_accounts -> source_ranges
    EOT
  default     = null
}
variable "source_service_accounts" {
  type        = list(string)
  description = <<EOT
    (Optional) If source service accounts are specified, the firewall will apply only to traffic originating from an instance with a service account in this list.
    If source_tags, source_service_accounts, and source_ranges are specified precidence order will be inforced: source_tags -> source_service_accounts -> source_ranges
    EOT
  default     = null
}
variable "source_ranges" {
  type        = list(string)
  description = <<EOT
    (Optional) If source ranges are specified, the firewall will apply only to traffic that has source IP address in these ranges.
    If source_tags, source_service_accounts, and source_ranges are specified precidence order will be inforced: source_tags -> source_service_accounts -> source_ranges
    EOT
  default     = null
}

#########
# Egress destination filters
#########
variable "destination_ranges" {
  type        = list(string)
  description = <<EOT
    (Optional) If destination ranges are specified, the firewall will apply only to traffic that has destination IP address in these ranges.
    EOT
  default     = null
}
