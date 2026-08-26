locals {
  vpc_id_pattern           = "^vpc-[0-9a-f]{8,17}$"
  subnet_id_pattern        = "^subnet-[0-9a-f]{8,17}$"
  resolver_rule_id_pattern = "^rslvr-rr-"

  lookup_organization = anytrue([
    for _, resolver_config in var.route53_resolver_parameters :
    try(resolver_config.ram_share_with_organization, var.route53_resolver_defaults.ram_share_with_organization, false)
  ])

  organization_arn = try(data.aws_organizations_organization.this[0].arn, null)

  vpc_from_parameters = {
    for resolver_key, resolver_config in var.route53_resolver_parameters :
    resolver_key => try(
      regex(local.vpc_id_pattern, resolver_config.resource_ids.vpc_id),
      regex(local.vpc_id_pattern, resolver_config.vpc_id),
      regex(local.vpc_id_pattern, resolver_config.vpc),
      var.vpc_parameter.vpcs[resolver_config.vpc].vpc_id,
      var.vpc_parameter.vpcs[resolver_config.vpc].id,
      var.vpc_parameter[resolver_config.vpc].vpc_id,
      null
    )
  }

  vpc_lookup_names = {
    for resolver_key, resolver_config in var.route53_resolver_parameters :
    resolver_key => try(
      resolver_config.vpc_name,
      var.route53_resolver_defaults.vpc_name,
      local.default_vpc_name
    )
    if local.vpc_from_parameters[resolver_key] == null
  }

  resolved_vpc_id = {
    for resolver_key, _ in var.route53_resolver_parameters :
    resolver_key => contains(keys(data.aws_vpc.this), resolver_key) ? data.aws_vpc.this[resolver_key].id : local.vpc_from_parameters[resolver_key]
  }

  subnet_ids_raw = {
    for resolver_key, resolver_config in var.route53_resolver_parameters :
    resolver_key => try(
      resolver_config.resource_ids.subnet_ids,
      resolver_config.subnet_ids,
      var.route53_resolver_defaults.subnet_ids,
      []
    )
  }

  subnet_lookups_tmp = flatten([
    for resolver_key, resolver_config in var.route53_resolver_parameters : concat(
      [
        for subnet in local.subnet_ids_raw[resolver_key] : {
          key          = "${resolver_key}:${subnet}"
          resolver_key = resolver_key
          ref          = subnet
        }
      ],
      [
        for address in try(resolver_config.ip_addresses, var.route53_resolver_defaults.ip_addresses, []) : {
          key          = "${resolver_key}:${address.subnet_id}"
          resolver_key = resolver_key
          ref          = address.subnet_id
        }
      ]
    )
  ])

  subnet_lookups = {
    for item in local.subnet_lookups_tmp : item.key => item
    if !can(regex(local.subnet_id_pattern, item.ref)) && try(
      var.vpc_parameter.subnets[item.ref].id,
      var.vpc_parameter.subnets["${try(var.route53_resolver_parameters[item.resolver_key].vpc, "")}-${item.ref}"].id,
      null
    ) == null
  }

  wrapper_private_subnet_ids = {
    for resolver_key, resolver_config in var.route53_resolver_parameters :
    resolver_key => [
      for subnet_key, subnet in try(var.vpc_parameter.subnets, {}) :
      subnet.id
      if try(resolver_config.vpc, null) != null ? startswith(subnet_key, "${resolver_config.vpc}-private-") : false
    ]
  }

  subnet_name_lookups = {
    for resolver_key, resolver_config in var.route53_resolver_parameters :
    resolver_key => try(
      resolver_config.subnet_name,
      var.route53_resolver_defaults.subnet_name,
      local.default_subnet_private_name
    )
    if try(resolver_config.create_endpoint, var.route53_resolver_defaults.create_endpoint, length(try(resolver_config.rules, {})) > 0 || upper(try(resolver_config.direction, var.route53_resolver_defaults.direction, "OUTBOUND")) == "INBOUND") && length(local.subnet_ids_raw[resolver_key]) == 0 && length(local.wrapper_private_subnet_ids[resolver_key]) == 0
  }

  resolved_subnet_ids = {
    for resolver_key, resolver_config in var.route53_resolver_parameters :
    resolver_key => length(local.subnet_ids_raw[resolver_key]) > 0 ? [
      for subnet in local.subnet_ids_raw[resolver_key] :
      can(regex(local.subnet_id_pattern, subnet)) ? subnet : try(
        var.vpc_parameter.subnets[subnet].id,
        var.vpc_parameter.subnets["${try(resolver_config.vpc, "")}-${subnet}"].id,
        data.aws_subnet.this["${resolver_key}:${subnet}"].id,
        subnet
      )
      ] : (
      length(local.wrapper_private_subnet_ids[resolver_key]) > 0 ? local.wrapper_private_subnet_ids[resolver_key] : (
        contains(keys(data.aws_subnets.this), resolver_key) ? data.aws_subnets.this[resolver_key].ids : []
      )
    )
  }

  resolvers = {
    for resolver_key, resolver_config in var.route53_resolver_parameters :
    resolver_key => {
      create_endpoint = try(
        resolver_config.create_endpoint,
        var.route53_resolver_defaults.create_endpoint,
        length(try(resolver_config.rules, {})) > 0 || upper(try(resolver_config.direction, var.route53_resolver_defaults.direction, "OUTBOUND")) == "INBOUND"
      )
      create_security_group = try(
        resolver_config.create_security_group,
        var.route53_resolver_defaults.create_security_group,
        try(resolver_config.create_endpoint, var.route53_resolver_defaults.create_endpoint, length(try(resolver_config.rules, {})) > 0 || upper(try(resolver_config.direction, var.route53_resolver_defaults.direction, "OUTBOUND")) == "INBOUND")
      )
      name       = try(resolver_config.name, var.route53_resolver_defaults.name, "${local.common_name}-${resolver_key}")
      vpc_id     = local.resolved_vpc_id[resolver_key]
      subnet_ids = local.resolved_subnet_ids[resolver_key]
      ip_addresses = [
        for address in try(resolver_config.ip_addresses, var.route53_resolver_defaults.ip_addresses, []) : {
          subnet_id = can(regex(local.subnet_id_pattern, address.subnet_id)) ? address.subnet_id : try(
            var.vpc_parameter.subnets[address.subnet_id].id,
            var.vpc_parameter.subnets["${try(resolver_config.vpc, "")}-${address.subnet_id}"].id,
            data.aws_subnet.this["${resolver_key}:${address.subnet_id}"].id,
            address.subnet_id
          )
          ip = try(address.ip, null)
        }
      ]
      direction              = try(resolver_config.direction, var.route53_resolver_defaults.direction, "OUTBOUND")
      protocols              = try(resolver_config.protocols, var.route53_resolver_defaults.protocols, null)
      resolver_endpoint_type = try(resolver_config.resolver_endpoint_type, var.route53_resolver_defaults.resolver_endpoint_type, "IPV4")
      resolver_endpoint_id   = try(resolver_config.resolver_endpoint_id, var.route53_resolver_defaults.resolver_endpoint_id, null)
      security_group_name    = try(resolver_config.security_group_name, var.route53_resolver_defaults.security_group_name, "${local.common_name}-${resolver_key}-sg")
      security_group_description = try(
        resolver_config.security_group_description,
        var.route53_resolver_defaults.security_group_description,
        "Security group for Route 53 Resolver endpoint"
      )
      security_group_ids  = try(resolver_config.security_group_ids, var.route53_resolver_defaults.security_group_ids, [])
      ingress_cidr_blocks = try(resolver_config.ingress_cidr_blocks, var.route53_resolver_defaults.ingress_cidr_blocks, [])
      egress_cidr_blocks  = try(resolver_config.egress_cidr_blocks, var.route53_resolver_defaults.egress_cidr_blocks, [])
      associate_vpc       = try(resolver_config.associate_vpc, var.route53_resolver_defaults.associate_vpc, true)
      share_rules = try(
        resolver_config.share_rules,
        var.route53_resolver_defaults.share_rules,
        resolver_config.ram_share_with_organization,
        var.route53_resolver_defaults.ram_share_with_organization,
        false
      )
      ram_name = try(resolver_config.ram_name, var.route53_resolver_defaults.ram_name, "${local.common_name}-${resolver_key}-rules")
      ram_principals = distinct(concat(
        try(resolver_config.ram_principals, var.route53_resolver_defaults.ram_principals, []),
        try(resolver_config.ram_share_with_organization, var.route53_resolver_defaults.ram_share_with_organization, false) ? compact([local.organization_arn]) : []
      ))
      ram_allow_external_principals = try(
        resolver_config.ram_allow_external_principals,
        var.route53_resolver_defaults.ram_allow_external_principals,
        false
      )
      ram_resource_share_arn = try(resolver_config.ram_resource_share_arn, var.route53_resolver_defaults.ram_resource_share_arn, null)
      accept_resource_share = try(
        resolver_config.accept_resource_share,
        var.route53_resolver_defaults.accept_resource_share,
        false
      )
      tags = merge(local.common_tags, try(resolver_config.tags, var.route53_resolver_defaults.tags, {}))
      rules = {
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
            can(regex(local.vpc_id_pattern, vpc_ref)) ? vpc_ref : try(
              var.vpc_parameter.vpcs[vpc_ref].vpc_id,
              var.vpc_parameter.vpcs[vpc_ref].id,
              vpc_ref
            )
          ]
          tags = try(rule.tags, {})
        }
      }
      rule_associations = {
        for association_key, association in merge(
          {
            for k, v in try(resolver_config.shared_rules, {}) : k => {
              id_or_name  = can(keys(v)) ? try(v.resolver_rule_id, v.resource_id, null) : tostring(v)
              domain_name = try(v.domain_name, null)
              rule_name   = try(v.rule_name, null)
              vpc_id      = try(v.vpc_id, v.resource_ids.vpc_id, null)
              vpc         = try(v.vpc, null)
              name        = try(v.name, k)
            }
          },
          {
            for k, v in try(resolver_config.rule_associations, {}) : k => {
              id_or_name  = can(keys(v)) ? try(v.resolver_rule_id, v.resource_id, null) : tostring(v)
              domain_name = try(v.domain_name, null)
              rule_name   = try(v.rule_name, null)
              vpc_id      = try(v.vpc_id, v.resource_ids.vpc_id, null)
              vpc         = try(v.vpc, null)
              name        = try(v.name, k)
            }
          }
        ) :
        association_key => {
          resolver_rule_id = can(regex(local.resolver_rule_id_pattern, try(association.id_or_name, ""))) ? association.id_or_name : null
          domain_name      = association.domain_name
          rule_name        = association.rule_name != null ? association.rule_name : (can(regex(local.resolver_rule_id_pattern, try(association.id_or_name, ""))) ? null : association.id_or_name)
          vpc_id = try(
            regex(local.vpc_id_pattern, association.vpc_id),
            regex(local.vpc_id_pattern, association.vpc),
            var.vpc_parameter.vpcs[association.vpc].vpc_id,
            var.vpc_parameter.vpcs[association.vpc].id,
            local.resolved_vpc_id[resolver_key]
          )
          name = association.name
        }
      }
    }
  }
}
