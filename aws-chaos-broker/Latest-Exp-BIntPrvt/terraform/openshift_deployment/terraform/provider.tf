terraform {
  required_version = ">= 1.0"
  
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# Configure Kubernetes provider for OpenShift
provider "kubernetes" {
  config_path = var.kubeconfig_path
  config_context = var.kube_context
}

# Note: For OpenShift, you may need additional provider configuration
# or use the openshift provider if available

