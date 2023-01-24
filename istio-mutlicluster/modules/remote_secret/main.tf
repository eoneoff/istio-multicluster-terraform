terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      configuration_aliases = [ kubernetes.local, kubernetes.remote ]
    }
  }
}


data "kubernetes_service_account" "istio-reader-service-account" {

    provider = kubernetes.local

    metadata {
        name = "istio-reader-service-account"
        namespace = "istio-system"
    }
}

data "kubernetes_secret" "istio-reader-service-account-token" {

    provider = kubernetes.local

    metadata {
        name = coalesce(data.kubernetes_service_account.istio-reader-service-account.default_secret_name, coalescelist(data.kubernetes_service_account.istio-reader-service-account.secret, [{name = null}]).0.name)
        namespace = "istio-system"
    }

    depends_on = [
        data.kubernetes_service_account.istio-reader-service-account
    ]
}

resource "kubernetes_secret" "remote-secret" {

    provider = kubernetes.remote

    metadata {
        name = "istio-remote-secret-${var.cluster_name}"
        namespace = "istio-system"
        labels = {
            "istio/multiCluster" = "true"
        }

        annotations = {
          "networking.istio.io/cluster" = var.cluster_name
        }
    }

    data = {
      "${var.cluster_name}" = templatefile("${path.module}/istio-remote-secret.yaml", {
        certificate_authority_data = var.ca_data,
        server = var.server
        name = var.cluster_name
        cluster = var.cluster_name
        context_name = var.cluster_name
        current_context = var.cluster_name
        user = var.cluster_name
        token = data.kubernetes_secret.istio-reader-service-account-token.data.token
      })
    }

    depends_on = [
      data.kubernetes_secret.istio-reader-service-account-token
    ]
}