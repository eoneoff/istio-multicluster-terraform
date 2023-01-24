terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
        source = "hashicorp/helm"
    }
    kubectl = {
        source  = "gavinbunney/kubectl"
    }
  }
}

resource "kubernetes_namespace" "istio-system" {
    metadata {
        name = "istio-system"

        labels = {
          "topology.istio.io/network" = var.network
        }
    }
}

resource "kubernetes_secret" "cacerts" {
    metadata {
        name = "cacerts"
        namespace = "istio-system"
    }
    data = {
      "ca-cert.pem" = var.cert
      "ca-key.pem" = var.key
      "root-cert.pem" = var.ca-root
      "cert-chain.pem" = "${var.cert}${var.ca-root}"
    }

    depends_on = [
        kubernetes_namespace.istio-system
    ]
}

resource "helm_release" "istio-base" {
    name = "istio-base"
    namespace = "istio-system"
    create_namespace = true
    repository = "https://istio-release.storage.googleapis.com/charts"
    chart = "base"
    timeout = 300
    cleanup_on_fail = true

    depends_on = [
        kubernetes_secret.cacerts
    ]
}

resource "helm_release" "istiod" {
    name = "istiod"
    namespace = "istio-system"
    create_namespace = true
    repository = "https://istio-release.storage.googleapis.com/charts"
    chart = "istiod"
    timeout = 900
    cleanup_on_fail = true
    wait = true

    set {
        name = "global.meshID"
        value = var.mesh_id
    }

    set {
        name = "global.multiCluster.clusterName"
        value = var.cluster_name
    }

    set {
        name = "global.network"
        value = var.network
    }

    set {
        name = "meshConfig.defaultConfig.proxyMetadata.ISTIO_META_DNS_CAPTURE"
        value = "true"
        type = "string"
    }

    depends_on = [
      helm_release.istio-base
    ]
}

resource "helm_release" "cross-network-gateway" {

    name = "cross-network-gateway"
    namespace = "istio-system"
    create_namespace = true
    repository = "https://istio-release.storage.googleapis.com/charts"
    chart = "gateway"
    timeout = 900
    cleanup_on_fail = true

    values = [
        templatefile("${path.module}/cross-network-gateway-config.yaml", {
            network = var.network
        })
    ]

    depends_on = [
      helm_release.istiod
    ]
}

resource "kubectl_manifest" "expose-services" {
    yaml_body = file("${path.module}/expose-services.yaml")

    depends_on = [
      helm_release.istiod
    ]
}