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

  # ENI IPs per resolver. Key: route53_resolver_parameters map key.
  resolver_ip_addresses_tmp = [
    for resolver_key, resolver_config in var.route53_resolver_parameters : {
      "${resolver_key}" = [
        for address in try(resolver_config.ip_addresses, var.route53_resolver_defaults.ip_addresses, []) : {
          subnet_id = try(var.vpc_parameter.subnets["${try(resolver_config.vpc, var.route53_resolver_defaults.vpc)}-${address.subnet_id}"].id, var.vpc_parameter.subnets[address.subnet_id].id, address.subnet_id)
          ip        = try(address.ip, null)
        }
      ]
    }
  ]
  resolver_ip_addresses = merge(flatten(local.resolver_ip_addresses_tmp)...)
  # output "debug_resolver_ip_addresses" { value = local.resolver_ip_addresses }

  # FORWARD rules per resolver. Key: route53_resolver_parameters map key.
  resolver_rules_tmp = [
    for resolver_key, resolver_config in var.route53_resolver_parameters : {
      "${resolver_key}" = {
        for rule_key, rule in try(resolver_config.rules, var.route53_resolver_defaults.rules, {}) :
        rule_key => {
          domain_name = rule.domain_name
          name        = try(rule.name, rule_key)
          rule_type   = try(rule.rule_type, "FORWARD")
          target_ips = [
            for target in try(rule.target_ips, []) : {
              ip   = try(target.ip, split(":", target)[0])
              port = try(target.port, tonumber(split(":", target)[1]), 53)
            }
          ]
          associate_vpc_ids = [
            for vpc_ref in try(rule.associate_vpc_ids, []) :
            try(var.vpc_parameter.vpcs[vpc_ref].vpc_id, vpc_ref)
          ]
          tags = try(rule.tags, {})
        }
      }
    }
  ]
  resolver_rules = merge(flatten(local.resolver_rules_tmp)...)
  # output "debug_resolver_rules" { value = local.resolver_rules }

  # RAM-shared / existing rule associations. Key: route53_resolver_parameters map key.
  resolver_rule_associations_tmp = [
    for resolver_key, resolver_config in var.route53_resolver_parameters : {
      "${resolver_key}" = {
        for association_key, association in try(resolver_config.rule_associations, var.route53_resolver_defaults.rule_associations, {}) :
        association_key => {
          resolver_rule_id = try(association.resolver_rule_id, null)
          domain_name      = try(association.domain_name, null)
          rule_name        = try(association.rule_name, null)
          vpc_id           = try(association.vpc_id, null) != null ? association.vpc_id : try(var.vpc_parameter.vpcs[association.vpc].vpc_id, local.resolver_vpc_id[resolver_key])
          name             = try(association.name, association_key)
        }
      }
    }
  ]
  resolver_rule_associations = merge(flatten(local.resolver_rule_associations_tmp)...)
  # output "debug_resolver_rule_associations" { value = local.resolver_rule_associations }
}
