data "aws_organizations_organization" "this" {
  count = local.lookup_organization ? 1 : 0
}

data "aws_vpc" "this" {
  for_each = local.vpc_lookup_names

  filter {
    name   = "tag:Name"
    values = [each.value]
  }
}

data "aws_subnet" "this" {
  for_each = local.subnet_lookups

  vpc_id = try(local.resolved_vpc_id[each.value.resolver_key], null)

  filter {
    name   = "tag:Name"
    values = [each.value.ref]
  }
}

data "aws_subnets" "this" {
  for_each = local.subnet_name_lookups

  filter {
    name   = "vpc-id"
    values = [local.resolved_vpc_id[each.key]]
  }

  tags = {
    Name = each.value
  }
}
