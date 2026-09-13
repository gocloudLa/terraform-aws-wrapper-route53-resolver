module "route53_resolver" {
  source = "./modules/aws/terraform-aws-route53-resolver"

  for_each = var.route53_resolver_parameters

  create_endpoint = try(each.value.create_endpoint, var.route53_resolver_defaults.create_endpoint, length(try(each.value.rules, var.route53_resolver_defaults.rules, {})) > 0 || upper(try(each.value.direction, var.route53_resolver_defaults.direction, "OUTBOUND")) == "INBOUND")
  name            = try(each.value.name, var.route53_resolver_defaults.name, "${local.common_name}-${each.key}")
  vpc_id          = local.resolver_vpc_id[each.key]
  subnet_ids      = local.resolver_subnet_ids[each.key]
  ip_addresses = [
    for address in try(each.value.ip_addresses, var.route53_resolver_defaults.ip_addresses, []) : {
      subnet_id = try(var.vpc_parameter.subnets["${try(each.value.vpc, var.route53_resolver_defaults.vpc)}-${address.subnet_id}"].id, var.vpc_parameter.subnets[address.subnet_id].id, address.subnet_id)
      ip        = try(address.ip, null)
    }
  ]
  direction                  = upper(try(each.value.direction, var.route53_resolver_defaults.direction, "OUTBOUND"))
  protocols                  = try(each.value.protocols, var.route53_resolver_defaults.protocols, null)
  resolver_endpoint_type     = try(each.value.resolver_endpoint_type, var.route53_resolver_defaults.resolver_endpoint_type, "IPV4")
  resolver_endpoint_id       = try(each.value.resolver_endpoint_id, var.route53_resolver_defaults.resolver_endpoint_id, null)
  create_security_group      = try(each.value.create_security_group, var.route53_resolver_defaults.create_security_group, true)
  security_group_name        = try(each.value.security_group_name, var.route53_resolver_defaults.security_group_name, "${local.common_name}-${each.key}-sg")
  security_group_description = try(each.value.security_group_description, var.route53_resolver_defaults.security_group_description, "Security group for Route 53 Resolver endpoint")
  security_group_ids         = try(each.value.security_group_ids, var.route53_resolver_defaults.security_group_ids, [])
  ingress_cidr_blocks        = try(each.value.ingress_cidr_blocks, var.route53_resolver_defaults.ingress_cidr_blocks, [])
  egress_cidr_blocks         = try(each.value.egress_cidr_blocks, var.route53_resolver_defaults.egress_cidr_blocks, [])
  rules = {
    for rule_key, rule in try(each.value.rules, var.route53_resolver_defaults.rules, {}) :
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
  associate_vpc = try(each.value.associate_vpc, var.route53_resolver_defaults.associate_vpc, true)
  rule_associations = {
    for association_key, association in try(each.value.rule_associations, var.route53_resolver_defaults.rule_associations, {}) :
    association_key => {
      resolver_rule_id = try(association.resolver_rule_id, null)
      domain_name      = try(association.domain_name, null)
      rule_name        = try(association.rule_name, null)
      vpc_id           = try(association.vpc_id, null) != null ? association.vpc_id : try(var.vpc_parameter.vpcs[association.vpc].vpc_id, local.resolver_vpc_id[each.key])
      name             = try(association.name, association_key)
    }
  }
  share_rules                   = try(each.value.share_rules, var.route53_resolver_defaults.share_rules, false)
  ram_name                      = try(each.value.ram_name, var.route53_resolver_defaults.ram_name, "${local.common_name}-${each.key}-rules")
  ram_principals                = try(each.value.ram_principals, var.route53_resolver_defaults.ram_principals, [])
  ram_allow_external_principals = try(each.value.ram_allow_external_principals, var.route53_resolver_defaults.ram_allow_external_principals, false)
  ram_resource_share_arn        = try(each.value.ram_resource_share_arn, var.route53_resolver_defaults.ram_resource_share_arn, null)
  ram_accept_share              = try(each.value.accept_resource_share, var.route53_resolver_defaults.accept_resource_share, false)
  tags                          = merge(local.common_tags, try(each.value.tags, var.route53_resolver_defaults.tags, null), { Name = "${local.common_name}-${each.key}" })
}
