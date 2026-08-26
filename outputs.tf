output "route53_resolvers" {
  description = "Route 53 Resolver endpoints, rules, associations, and RAM shares."
  value       = module.route53_resolver
}

output "resolver_endpoint_ids" {
  description = "Map of resolver endpoint IDs."
  value       = { for k, v in module.route53_resolver : k => v.resolver_endpoint_id }
}

output "resolver_endpoint_ip_addresses" {
  description = "Map of resolver endpoint ENI IPv4 addresses. Use the INBOUND values as on-premises DNS forwarders."
  value       = { for k, v in module.route53_resolver : k => v.resolver_endpoint_ip_addresses }
}

output "resolver_rule_ids" {
  description = "Map of resolver rule ID maps keyed by endpoint."
  value       = { for k, v in module.route53_resolver : k => v.resolver_rule_ids }
}

output "resolver_rule_arns" {
  description = "Map of resolver rule ARN maps keyed by endpoint."
  value       = { for k, v in module.route53_resolver : k => v.resolver_rule_arns }
}

output "ram_resource_share_arns" {
  description = "Map of RAM resource share ARNs keyed by endpoint."
  value       = { for k, v in module.route53_resolver : k => v.ram_resource_share_arn }
}
