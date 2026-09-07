variable "create_endpoint" {
  type        = bool
  description = "Whether to create the Route 53 Resolver endpoint."
  default     = true
}

variable "name" {
  type        = string
  description = "Name for the resolver endpoint and related resources."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID that hosts the resolver endpoint ENIs."
  default     = null
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for resolver endpoint ENIs. At least two AZs are required when creating an endpoint."
  default     = []
}

variable "ip_addresses" {
  type = list(object({
    subnet_id = string
    ip        = optional(string)
  }))
  description = "Optional explicit ENI IPs. When empty, one ENI is created per subnet_id."
  default     = []
}

variable "direction" {
  type        = string
  description = "Resolver endpoint direction: OUTBOUND or INBOUND."
  default     = "OUTBOUND"
}

variable "protocols" {
  type        = list(string)
  description = "Resolver endpoint protocols (Do53, DoH, DoH-FIPS)."
  default     = null
}

variable "resolver_endpoint_type" {
  type        = string
  description = "Endpoint IP type: IPV4, IPV6, or DUALSTACK."
  default     = "IPV4"
}

variable "resolver_endpoint_id" {
  type        = string
  description = "Existing resolver endpoint ID when create_endpoint is false."
  default     = null
}

variable "create_security_group" {
  type        = bool
  description = "Whether to create a security group for the resolver endpoint."
  default     = true
}

variable "security_group_name" {
  type        = string
  description = "Name of the created security group."
  default     = null
}

variable "security_group_description" {
  type        = string
  description = "Description of the created security group."
  default     = "Security group for Route 53 Resolver endpoint"
}

variable "security_group_ids" {
  type        = list(string)
  description = "Additional security group IDs attached to the endpoint."
  default     = []
}

variable "ingress_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks allowed to send DNS to an INBOUND endpoint."
  default     = []
}

variable "egress_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks the endpoint may reach on TCP/UDP 53. Defaults to rule target IPs."
  default     = []
}

variable "rules" {
  type = map(object({
    domain_name = string
    name        = optional(string)
    rule_type   = optional(string, "FORWARD")
    target_ips = optional(list(object({
      ip   = string
      port = optional(number, 53)
    })), [])
    associate_vpc_ids = optional(list(string), [])
    tags              = optional(map(string), {})
  }))
  description = "Map of resolver rules. FORWARD rules use the endpoint and on-prem target IPs."
  default     = {}
}

variable "associate_vpc" {
  type        = bool
  description = "Associate created rules with vpc_id."
  default     = true
}

variable "rule_associations" {
  type = map(object({
    resolver_rule_id = optional(string)
    domain_name      = optional(string)
    rule_name        = optional(string)
    vpc_id           = optional(string)
    name             = optional(string)
  }))
  description = "Associations for existing or RAM-shared resolver rules (resolver_rule_id, rule_name, or domain_name)."
  default     = {}
}

variable "share_rules" {
  type        = bool
  description = "Share FORWARD rules through AWS RAM."
  default     = false
}

variable "ram_name" {
  type        = string
  description = "RAM resource share name."
  default     = null
}

variable "ram_principals" {
  type        = list(string)
  description = "Account IDs, Organization ARNs, or OU ARNs that receive the shared rules."
  default     = []
}

variable "ram_allow_external_principals" {
  type        = bool
  description = "Allow principals outside the organization."
  default     = false
}

variable "ram_resource_share_arn" {
  type        = string
  description = "Existing RAM share ARN. When set, rules are associated to it instead of creating a share."
  default     = null
}

variable "ram_accept_share" {
  type        = bool
  description = "Accept a RAM resource share in this account before associating shared rules."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags for resolver and RAM resources."
  default     = {}
}
