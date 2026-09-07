/*----------------------------------------------------------------------*/
/* Common |                                                             */
/*----------------------------------------------------------------------*/

variable "metadata" {
  type        = any
  description = "Platform metadata (company, env, regions, tags)."
}

variable "vpc_parameter" {
  type        = any
  description = "Full wrapper-vpc output (vpcs, subnets, route_tables) used to resolve keys to IDs."
  default     = {}
}

/*----------------------------------------------------------------------*/
/* Route53 Resolver | Variable Definition                               */
/*----------------------------------------------------------------------*/

variable "route53_resolver_parameters" {
  type        = any
  description = "Map of Route 53 Resolver endpoints, forwarding rules, and RAM shares."
  default     = {}
}

variable "route53_resolver_defaults" {
  type        = any
  description = "Default values merged into each entry of route53_resolver_parameters."
  default     = {}
}
