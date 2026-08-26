resource "aws_security_group" "this" {
  count = var.create_endpoint && var.create_security_group ? 1 : 0

  name        = coalesce(var.security_group_name, "${var.name}-sg")
  description = var.security_group_description
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.direction == "INBOUND" ? ["udp", "tcp"] : []

    content {
      description = "DNS ${ingress.value} from allowed resolvers"
      from_port   = 53
      to_port     = 53
      protocol    = ingress.value
      cidr_blocks = length(var.ingress_cidr_blocks) > 0 ? var.ingress_cidr_blocks : ["0.0.0.0/0"]
    }
  }

  dynamic "egress" {
    for_each = ["udp", "tcp"]

    content {
      description = "DNS ${egress.value} to on-premises or VPC resolvers"
      from_port   = 53
      to_port     = 53
      protocol    = egress.value
      cidr_blocks = local.egress_cidrs
    }
  }

  tags = merge(var.tags, { Name = coalesce(var.security_group_name, "${var.name}-sg") })
}

resource "aws_route53_resolver_endpoint" "this" {
  count = var.create_endpoint ? 1 : 0

  name                   = var.name
  direction              = var.direction
  security_group_ids     = local.security_group_ids
  protocols              = var.protocols
  resolver_endpoint_type = var.resolver_endpoint_type

  dynamic "ip_address" {
    for_each = local.ip_addresses

    content {
      subnet_id = ip_address.value.subnet_id
      ip        = try(ip_address.value.ip, null)
    }
  }

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    precondition {
      condition     = length(local.ip_addresses) >= 2
      error_message = "A Route 53 Resolver endpoint requires at least two IP addresses in different Availability Zones."
    }

    precondition {
      condition     = var.vpc_id != null && var.vpc_id != ""
      error_message = "vpc_id is required when create_endpoint is true."
    }
  }
}

resource "aws_route53_resolver_rule" "this" {
  for_each = var.rules

  domain_name          = each.value.domain_name
  name                 = try(each.value.name, each.key)
  rule_type            = try(each.value.rule_type, "FORWARD")
  resolver_endpoint_id = try(each.value.rule_type, "FORWARD") == "FORWARD" ? local.resolver_endpoint_id : null

  dynamic "target_ip" {
    for_each = try(each.value.rule_type, "FORWARD") == "FORWARD" ? try(each.value.target_ips, []) : []

    content {
      ip   = target_ip.value.ip
      port = try(target_ip.value.port, 53)
    }
  }

  tags = merge(var.tags, try(each.value.tags, {}), { Name = try(each.value.name, each.key) })
}

resource "aws_ram_resource_share_accepter" "this" {
  count = var.ram_accept_share && var.ram_resource_share_arn != null ? 1 : 0

  share_arn = var.ram_resource_share_arn
}

resource "aws_route53_resolver_rule_association" "this" {
  for_each = local.rule_associations

  name             = try(each.value.name, each.key)
  resolver_rule_id = each.value.resolver_rule_id
  vpc_id           = each.value.vpc_id

  depends_on = [aws_ram_resource_share_accepter.this]

  lifecycle {
    precondition {
      condition     = each.value.vpc_id != null && each.value.vpc_id != ""
      error_message = "Rule association ${each.key} needs a VPC. Set vpc or vpc_id on the wrapper entry or on the association."
    }

    precondition {
      condition     = each.value.resolver_rule_id != null && each.value.resolver_rule_id != ""
      error_message = "Rule association ${each.key} needs resolver_rule_id, rule_name, or domain_name of a shared FORWARD rule."
    }
  }
}

resource "aws_ram_resource_share" "this" {
  count = local.create_ram_share ? 1 : 0

  name                      = coalesce(var.ram_name, "${var.name}-rules")
  allow_external_principals = var.ram_allow_external_principals

  tags = merge(var.tags, { Name = coalesce(var.ram_name, "${var.name}-rules") })

  lifecycle {
    precondition {
      condition     = length(var.ram_principals) > 0
      error_message = "Sharing resolver rules requires ram_principals (account IDs) or ram_share_with_organization = true."
    }
  }
}

resource "aws_ram_resource_association" "this" {
  for_each = local.share_rules ? local.shareable_rule_arns : {}

  resource_arn       = each.value
  resource_share_arn = local.ram_share_arn
}

resource "aws_ram_principal_association" "this" {
  for_each = local.create_ram_share ? toset(var.ram_principals) : toset([])

  principal          = each.value
  resource_share_arn = aws_ram_resource_share.this[0].arn
}
