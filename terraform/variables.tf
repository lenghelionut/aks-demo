variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "project" {
  description = "Project name used for resource naming"
  type        = string
  default     = "aksdemo"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "germanywestcentral"
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version"
  type        = string
  default     = "1.35"
}

variable "system_node_count" {
  description = "Number of nodes in the system node pool"
  type        = number
  default     = 2
}

variable "app_node_min" {
  description = "Minimum nodes in the application node pool"
  type        = number
  default     = 1
}

variable "app_node_max" {
  description = "Maximum nodes in the application node pool"
  type        = number
  default     = 3
}

variable "gitops_repo_url" {
  description = "GitHub repository URL for GitOps manifests"
  type        = string
  default     = "https://github.com/lenghelionut/aks-demo.git"
}
