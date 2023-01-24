terraform {
  required_providers {
    kubectl = {
        source  = "gavinbunney/kubectl"
    }
  }
}


provider kubernetes {
    alias = "west"

    config_path = var.kubeconfig_path
    config_context = "west"
}

provider kubernetes {
    alias = "east"

    config_path = var.kubeconfig_path
    config_context = "east"
}

provider helm {
    alias = "west"

    kubernetes {
      config_path = var.kubeconfig_path
      config_context = "west"
    }
}

provider helm {
    alias = "east"

    kubernetes {
      config_path = var.kubeconfig_path
      config_context = "east"
    }
}

provider kubectl {
    alias = "west"
    config_path = var.kubeconfig_path
    config_context = "west"
}

provider kubectl {
    alias = "east"
    config_path = var.kubeconfig_path
    config_context = "east"
}

module "cacerts" {
    source = "./modules/cacerts"
    clusters = ["west","east"]    
}

module "istio-west" {

    providers = {
        kubernetes = kubernetes.west
        helm = helm.west
        kubectl = kubectl.west
    }

    source = "./modules/istio"
    network = "west-network"
    mesh_id = "mymesh"
    cluster_name= "west-cluster"
    ca-root = module.cacerts.root-cert
    cert = module.cacerts.certs["west"]
    key = module.cacerts.keys["west"]

    depends_on = [
      module.cacerts
    ]
}

module "istio-east" {

    providers = {
        kubernetes = kubernetes.east
        helm = helm.east
        kubectl = kubectl.east
    }

    source = "./modules/istio"
    network = "east-network"
    mesh_id = "mymesh"
    cluster_name= "east-cluster"
    ca-root = module.cacerts.root-cert
    cert = module.cacerts.certs["east"]
    key = module.cacerts.keys["east"]

    depends_on = [
      module.cacerts
    ]
}

module "remote-secret-west" {

    providers = {
        kubernetes.local = kubernetes.west
        kubernetes.remote = kubernetes.east
     }

    source = "./modules/remote_secret"

    cluster_name = "west-cluster"
    ca_data = var.ca_data_west
    server = var.server_west

    depends_on = [
        module.istio-west,
        module.istio-east
    ]
}

module "remote-secret-east" {

    providers = {
        kubernetes.local = kubernetes.east
        kubernetes.remote = kubernetes.west
     }

    source = "./modules/remote_secret"

    cluster_name = "east-cluster"
    ca_data = var.ca_data_east
    server = var.server_east

    depends_on = [
        module.istio-east,
        module.istio-west
    ]
}