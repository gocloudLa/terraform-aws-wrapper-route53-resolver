locals {
  ip_addresses = length(var.ip_addresses) > 0 ? var.ip_addresses : [
    for subnet_id in var.subnet_ids : {
      subnet_id = subnet_id
      ip        = null
    }
  ]

  target_ip_cidrs = distinct(compact(flatten([
    for _, rule in var.rules : [
      for target in try(rule.target_ips, []) : "${target.ip}/32"
    ]
  ])))

  egress_cidrs = length(var.egress_cidr_blocks) > 0 ? var.egress_cidr_blocks : (
    length(local.target_ip_cidrs) > 0 ? local.target_ip_cidrs : ["0.0.0.0/0"]
  )

  security_group_ids = compact(concat(
    var.create_security_group && var.create_endpoint ? [aws_security_group.this[0].id] : [],
    var.security_group_ids
  ))

  resolver_endpoint_id = var.create_endpoint ? aws_route53_resolver_endpoint.this[0].id : var.resolver_endpoint_id

  share_rules = var.share_rules && length(var.ram_principals) > 0

  forward_rule_keys = [
    for rule_key, rule in var.rules : rule_key
    if try(rule.rule_type, "FORWARD") == "FORWARD"
  ]

  create_ram_share = local.share_rules && var.ram_resource_share_arn == null && length(local.forward_rule_keys) > 0

  ram_share_arn = var.ram_resource_share_arn != null ? var.ram_resource_share_arn : try(aws_ram_resource_share.this[0].arn, null)

  created_rule_associations_tmp = flatten([
    for rule_key, rule in var.rules : [
      for vpc_id in distinct(concat(
        var.associate_vpc && var.vpc_id != null ? [var.vpc_id] : [],
        try(rule.associate_vpc_ids, [])
        )) : {
        "${rule_key}-${vpc_id}" = {
          resolver_rule_id = aws_route53_resolver_rule.this[rule_key].id
          vpc_id           = vpc_id
          name             = try(rule.name, rule_key)
        }
      }
    ]
  ])

  created_rule_associations = length(local.created_rule_associations_tmp) > 0 ? merge(local.created_rule_associations_tmp...) : {}

  imported_rule_associations = {
    for k, v in var.rule_associations : k => {
      resolver_rule_id = contains(keys(data.aws_route53_resolver_rule.shared), k) ? data.aws_route53_resolver_rule.shared[k].id : try(v.resolver_rule_id, null)
      vpc_id           = v.vpc_id
      name             = try(v.name, k)
    }
  }

  rule_associations = merge(local.created_rule_associations, local.imported_rule_associations)

  shareable_rule_arns = {
    for rule_key, rule in aws_route53_resolver_rule.this :
    rule_key => rule.arn
    if rule.rule_type == "FORWARD"
  }
}
