############################
# Variables
############################
variable "zone_name" {
  description = "Hosted zone name (e.g., servicefoundry.org). No trailing dot."
  type        = string
}

variable "record_name" {
  description = "Record label (e.g., '@', 'app', 'traefik')."
  type        = string
  default     = "@"
}

variable "k8s_namespace" {
  description = "Namespace of the Kubernetes Service (exposed by LB Controller)."
  type        = string
}

variable "k8s_ingress_name" {
  description = "Name of the Kubernetes Service."
  type        = string
}

variable "create_aaaa" {
  description = "Also create AAAA (IPv6) alias to the same LB."
  type        = bool
  default     = true
}