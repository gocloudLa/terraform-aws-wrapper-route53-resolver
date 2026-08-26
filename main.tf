module "route53_resolver" {
  source = "./modules/aws/terraform-aws-route53-resolver"

  for_each = local.resolvers

  create_endpoint               = each.value.create_endpoint
  name                          = each.value.name
  vpc_id                        = each.value.vpc_id
  subnet_ids                    = each.value.subnet_ids
  ip_addresses                  = each.value.ip_addresses
  direction                     = each.value.direction
  protocols                     = each.value.protocols
  resolver_endpoint_type        = each.value.resolver_endpoint_type
  resolver_endpoint_id          = each.value.resolver_endpoint_id
  create_security_group         = each.value.create_security_group
  security_group_name           = each.value.security_group_name
  security_group_description    = each.value.security_group_description
  security_group_ids            = each.value.security_group_ids
  ingress_cidr_blocks           = each.value.ingress_cidr_blocks
  egress_cidr_blocks            = each.value.egress_cidr_blocks
  rules                         = each.value.rules
  associate_vpc                 = each.value.associate_vpc
  rule_associations             = each.value.rule_associations
  share_rules                   = each.value.share_rules
  ram_name                      = each.value.ram_name
  ram_principals                = each.value.ram_principals
  ram_allow_external_principals = each.value.ram_allow_external_principals
  ram_resource_share_arn        = each.value.ram_resource_share_arn
  ram_accept_share              = each.value.accept_resource_share
  tags                          = merge(each.value.tags, { Name = each.value.name })
}
