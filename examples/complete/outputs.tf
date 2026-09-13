output "resolver_endpoint_ids" {
  description = "Map of resolver endpoint IDs."
  value       = module.wrapper_route53_resolver.resolver_endpoint_ids
}

output "resolver_endpoint_ip_addresses" {
  description = "Map of resolver endpoint ENI IPv4 addresses. Use the INBOUND values as on-premises DNS forwarders."
  value       = module.wrapper_route53_resolver.resolver_endpoint_ip_addresses
}

output "resolver_rule_ids" {
  description = "Map of resolver rule ID maps keyed by endpoint."
  value       = module.wrapper_route53_resolver.resolver_rule_ids
}

output "ram_resource_share_arns" {
  description = "Map of RAM resource share ARNs keyed by endpoint."
  value       = module.wrapper_route53_resolver.ram_resource_share_arns
}
