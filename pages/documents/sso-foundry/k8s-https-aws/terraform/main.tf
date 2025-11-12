provider "aws" {
  region = "ca-central-1"
}

provider "kubernetes" {
  config_path = "~/.kube/config"
  # or host/token/cluster_ca_certificate if running in CI
}

module "alias_for_traefik" {
  source           = "./modules/route53-alias-for-k8s-lb"
  zone_name        = "servicefoundry.org"
  record_name      = "@"                     # root apex; use "app" for app.servicefoundry.org
  k8s_namespace    = "traefik"
  k8s_ingress_name = "traefik-alb"
  create_aaaa      = false
}