terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 3.61.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.0.2"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.0.2"
    }
  }
}

data "google_container_cluster" "cluster" {
  project  = var.gke_project_id
  name     = var.cluster_name
  location = var.gke_region
}

resource "kubernetes_namespace" "gatekeeper" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "gatekeeper" {
  chart      = "gatekeeper"
  repository = "https://open-policy-agent.github.io/gatekeeper/charts"
  name       = var.helm_release_name
  namespace  = var.namespace
  version    = "3.5.1"

  depends_on = [
    kubernetes_namespace.gatekeeper
  ]
}

resource "helm_release" "gatekeeper-templates" {
  chart     = "${path.module}/helm-gatekeeper-templates"
  name      = "gatekeeper-templates"
  namespace = var.namespace
  version   = "0.0.3"

  depends_on = [
    helm_release.gatekeeper
  ]
}

resource "helm_release" "gatekeeper-constraints" {
  chart     = "${path.module}/helm-gatekeeper-constraints"
  name      = "gatekeeper-constraints"
  namespace = var.namespace
  version   = "0.0.3"

  depends_on = [
    helm_release.gatekeeper-templates
  ]
}

resource "google_compute_firewall" "gatekeeper-firewall" {
  project     = var.vpc_project_id
  name        = "${data.google_container_cluster.cluster.name}-gatekeeper"
  description = "Allows admission controller queries from master to gatekeeper"
  network     = data.google_container_cluster.cluster.network

  allow {
    protocol = "tcp"
    ports    = ["8443","443"]
  }

  target_tags   = ["gke-${data.google_container_cluster.cluster.name}"]
  source_ranges = [data.google_container_cluster.cluster.private_cluster_config.0.master_ipv4_cidr_block]
}