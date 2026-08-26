data "aws_route53_resolver_rule" "shared" {
  for_each = {
    for k, v in var.rule_associations : k => v
    if try(v.resolver_rule_id, null) == null && (try(v.domain_name, null) != null || try(v.rule_name, null) != null)
  }

  name        = try(each.value.rule_name, null)
  domain_name = try(each.value.domain_name, null)
  rule_type   = "FORWARD"

  depends_on = [aws_ram_resource_share_accepter.this]
}
