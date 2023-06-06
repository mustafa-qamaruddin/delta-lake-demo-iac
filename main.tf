# main.tf

data "http" "k3s_install_script" {
  url = "https://example.com/install_k3s.sh"
}

resource "null_resource" "provision_cluster" {
  provisioner "local-exec" {
    command = <<-EOT
      chmod +x /path/to/install_k3s.sh
      /path/to/install_k3s.sh \
        --node-name=my-node \
        --node-ip=192.168.0.10 \
        --disable-agent \
        --docker \
        --data-dir=/var/lib/k3s \
        --cluster-cidr=10.42.0.0/16 \
        --service-cidr=10.43.0.0/16 \
        --node-label=my-label \
        --token=my-token \
        --server=https://my-k3s-server:6443
    EOT
  }
}

terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
      version = "2.4.1"
    }
  }
}

provider "helm" {}

resource "helm_release" "gitlab" {
  name       = "gitlab"
  repository = "https://charts.gitlab.io"
  chart      = "gitlab"
  version    = "5.7.5"
}
resource "tls_private_key" "argocd_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_public_key" "argocd_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
  private_key_pem = tls_private_key.argocd_ssh_key.private_key_pem
}

output "argocd_ssh_private_key" {
  value       = tls_private_key.argocd_ssh_key.private_key_pem
  description = "SSH private key for Argo CD"
}
data "terraform_remote_state" "argocd" {
  backend = "remote"
  config = {
    organization = "<your_organization>"
    workspaces = {
      name = "<your_workspace_name>"
    }
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "3.15.2"

  set {
    name  = "server.extraArgs.gpg.enabled"
    value = "false"
  }

  set {
    name  = "server.extraArgs.gpg.keyFile"
    value = "/app/config/keys/gpg/pubkey.gpg"
  }

  set {
    name  = "server.extraArgs.repoServerPrivateKey"
    value = data.terraform_remote_state.argocd.outputs.argocd_ssh_private_key
  }
}

resource "helm_release" "kafka" {
  name       = "kafka"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "kafka"
  version    = "12.16.0"
}

resource "helm_release" "spark" {
  name       = "spark"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "spark"
  version    = "5.0.10"
}

resource "helm_release" "delta_lake" {
  name       = "delta-lake"
  repository = "https://charts.databricks.com"
  chart      = "delta-lake-operator"
  version    = "0.6.0"
}
