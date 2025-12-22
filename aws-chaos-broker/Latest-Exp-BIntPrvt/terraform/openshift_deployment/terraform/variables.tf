variable "kubeconfig_path" {
  description = "Path to kubeconfig file for OpenShift cluster"
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Kubernetes context to use (for OpenShift cluster)"
  type        = string
  default     = null
}

variable "namespace" {
  description = "Namespace to deploy chaos-broker"
  type        = string
  default     = "chaos-broker"
}

variable "handler_image" {
  description = "Container image for handler service"
  type        = string
  default     = "chaos-broker-handler:latest"
}

variable "orchestrator_image" {
  description = "Container image for orchestrator service"
  type        = string
  default     = "chaos-broker-orchestrator:latest"
}

variable "handler_replicas" {
  description = "Number of handler service replicas"
  type        = number
  default     = 2
}

variable "orchestrator_replicas" {
  description = "Number of orchestrator service replicas"
  type        = number
  default     = 1
}

variable "storage_size" {
  description = "Size of persistent volume for experiments and journals"
  type        = string
  default     = "10Gi"
}

variable "storage_class" {
  description = "Storage class for persistent volume (leave empty for default)"
  type        = string
  default     = ""
}

variable "local_mode" {
  description = "Enable local/OpenShift mode (skip AWS services)"
  type        = bool
  default     = true
}

variable "openshift_storage_path" {
  description = "Path for OpenShift storage"
  type        = string
  default     = "/mnt/chaos-broker/storage"
}

variable "tags" {
  description = "Additional resource tags/labels"
  type        = map(string)
  default     = {
    app = "chaos-broker"
    managed-by = "terraform"
  }
}

