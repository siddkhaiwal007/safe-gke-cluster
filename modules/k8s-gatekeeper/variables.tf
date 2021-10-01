variable "namespace" {
  description = "Name of the gatekeeper namespace"
  type        = string
  default     = "gatekeeper-system"
}

variable "helm_release_name" {
  description = "Name of the gatekeeper helm release"
  type        = string
  default     = "gatekeeper"
}

variable "gke_project_id" {
  description = "GCP project containing the gke cluster control plane"
  type        = string
}

variable "cluster_name" {
  description = "GCP gke cluster name"
  type        = string
}

variable "vpc_project_id" {
  description = "GCP project containing the shared vpc"
  type        = string
}

variable "gke_region" {
  type        = string
  description = "GKE region"
}