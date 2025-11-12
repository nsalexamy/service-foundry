terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.19.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.30.0"
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.3"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2"
    }
  }
}


# Fetch the hostname via kubectl (we also use it as a sanity check / output)
# data "external" "svc_lb" {
#   program    = ["/bin/bash", "-lc", <<-EOT
#     H=$(kubectl get svc ${var.k8s_service_name} -n ${var.k8s_namespace} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
#     jq -n --arg hostname "$H" '{hostname: $hostname}'
#   EOT
#   ]
# }

############################
# Discover the AWS LB by controller tag (robust + gives us zone_id)
############################
# The AWS Load Balancer Controller tags LBs with:
#   kubernetes.io/service-name = "<namespace>/<service>"
data "aws_lb" "this" {
  # name = "${var.k8s_service_name}-alb"
  # Tag filter works well with controller-managed LBs
  tags = {
    #"kubernetes.io/service-name" = "${var.k8s_namespace}/${var.k8s_service_name}"
    "servicefoundry.org/service-name" = "${var.k8s_namespace}/${var.k8s_ingress_name}"
  }

}

############################
# Route53
############################
data "aws_route53_zone" "this" {
  name         = var.zone_name
  private_zone = false
}

locals {
  fqdn = var.record_name == "@" ? var.zone_name : "${var.record_name}.${var.zone_name}"
}

# A record → ALB/NLB Alias
resource "aws_route53_record" "a_alias" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = local.fqdn
  type    = "A"

  alias {
    name                   = data.aws_lb.this.dns_name
    zone_id                = data.aws_lb.this.zone_id
    evaluate_target_health = true
  }
}

# Optional AAAA record for IPv6
resource "aws_route53_record" "aaaa_alias" {
  count   = var.create_aaaa ? 1 : 0
  zone_id = data.aws_route53_zone.this.zone_id
  name    = local.fqdn
  type    = "AAAA"

  alias {
    name                   = data.aws_lb.this.dns_name
    zone_id                = data.aws_lb.this.zone_id
    evaluate_target_health = true
  }
}

############################
# Outputs
############################
output "lb_dns_name" {
  value       = data.aws_lb.this.dns_name
  description = "Discovered Load Balancer DNS name."
}

# output "k8s_service_lb_hostname" {
#   value       = data.external.svc_lb.result.hostname
#   description = "LB hostname reported on the Kubernetes Service (for visibility)."
# }

output "record_fqdn" {
  value       = local.fqdn
  description = "The fully-qualified DNS name created in Route53."
}