variable "vpc_parameter" {
  type        = any
  description = "Outputs from wrapper VPC: vpcs and subnets."
  default     = {}
}

variable "route53_resolver_defaults" {
  type        = any
  description = "Optional defaults merged across route53_resolver_parameters."
  default     = {}
}
