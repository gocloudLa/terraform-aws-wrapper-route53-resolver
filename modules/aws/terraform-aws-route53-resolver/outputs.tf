output "resolver_endpoint_id" {
  description = "ID of the Route 53 Resolver endpoint."
  value       = try(aws_route53_resolver_endpoint.this[0].id, var.resolver_endpoint_id, null)
}

output "resolver_endpoint_arn" {
  description = "ARN of the Route 53 Resolver endpoint."
  value       = try(aws_route53_resolver_endpoint.this[0].arn, null)
}

output "resolver_endpoint_host_vpc_id" {
  description = "VPC ID that hosts the resolver endpoint."
  value       = try(aws_route53_resolver_endpoint.this[0].host_vpc_id, var.vpc_id, null)
}

output "resolver_endpoint_ip_addresses" {
  description = "IPv4 addresses of the resolver endpoint ENIs. Configure on-premises DNS to forward to these IPs for INBOUND endpoints."
  value       = try([for addr in aws_route53_resolver_endpoint.this[0].ip_address : addr.ip], [])
}

output "security_group_id" {
  description = "ID of the created resolver security group."
  value       = try(aws_security_group.this[0].id, null)
}

output "security_group_ids" {
  description = "Security group IDs attached to the resolver endpoint."
  value       = local.security_group_ids
}

output "resolver_rule_ids" {
  description = "Map of resolver rule IDs."
  value       = { for k, v in aws_route53_resolver_rule.this : k => v.id }
}

output "resolver_rule_arns" {
  description = "Map of resolver rule ARNs."
  value       = { for k, v in aws_route53_resolver_rule.this : k => v.arn }
}

output "resolver_rule_association_ids" {
  description = "Map of resolver rule association IDs."
  value       = { for k, v in aws_route53_resolver_rule_association.this : k => v.id }
}

output "ram_resource_share_arn" {
  description = "ARN of the RAM resource share used for resolver rules."
  value       = local.ram_share_arn
}

output "ram_principal_associations" {
  description = "Map of RAM principal association IDs."
  value       = { for k, v in aws_ram_principal_association.this : k => v.id }
}

output "ram_resource_share_accepter_id" {
  description = "ID of the RAM resource share accepter when ram_accept_share is true."
  value       = try(aws_ram_resource_share_accepter.this[0].id, null)
}
