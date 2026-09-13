locals {
  resolver_vpc_id = {
    for resolver_key, resolver_config in var.route53_resolver_parameters :
    resolver_key => try(resolver_config.vpc_id, var.route53_resolver_defaults.vpc_id, null) != null ? try(resolver_config.vpc_id, var.route53_resolver_defaults.vpc_id) : try(var.vpc_parameter.vpcs[try(resolver_config.vpc, var.route53_resolver_defaults.vpc)].vpc_id, null)
  }

  resolver_subnet_ids = {
    for resolver_key, resolver_config in var.route53_resolver_parameters :
    resolver_key => [
      for subnet in try(resolver_config.subnet_ids, var.route53_resolver_defaults.subnet_ids, []) :
      try(var.vpc_parameter.subnets["${try(resolver_config.vpc, var.route53_resolver_defaults.vpc)}-${subnet}"].id, var.vpc_parameter.subnets[subnet].id, subnet)
    ]
  }
}
