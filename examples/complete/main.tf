module "wrapper_route53_resolver" {
  source = "../../"

  metadata = local.metadata
  # Standalone example only. Standard Platform modules/base sets vpc_parameter = module.wrapper_vpc.
  vpc_parameter = local.vpc_parameter

  route53_resolver_parameters = {
    # Hybrid DNS over Site-to-Site VPN / Transit Gateway.
    # Place both endpoints in private subnets that already route to on-premises.
    #
    # Outbound: AWS → on-premises. Workloads in vpc-01 (and RAM-shared spokes)
    # resolve corp.example.com against on-premises DNS.
    "vpn-01-outbound" = {
      vpc        = "vpc-01"
      subnet_ids = ["private-a", "private-b"]
      direction  = "OUTBOUND" # Default: "OUTBOUND"

      rules = {
        "onprem" = {
          domain_name = "corp.example.com"
          rule_type   = "FORWARD" # Default: "FORWARD"
          # Replace with the on-premises DNS server IP(s) reachable over VPN / TGW.
          target_ips = ["172.0.0.1", "172.0.0.2"]
        }
      }

      share_rules = true # Default: false
      ram_principals = [
        "123456789012",
        "234567890123"
      ]
      # Share with the whole organization (same RAM principal as TGW):
      # ram_principals = ["arn:aws:organizations::123456789012:organization/o-xxxxxxxxxx"]
      # ram_allow_external_principals = false # Default: false
      # ram_name                      = null
    }

    # Inbound: on-premises → AWS. On-premises resolvers query this endpoint so
    # they can resolve private hosted zones in AWS. No FORWARD rules. After apply, give the
    # inbound ENI IPs (resolver_endpoint_ip_addresses) to on-premises DNS as forwarders.
    "vpn-01-inbound" = {
      vpc        = "vpc-01"
      subnet_ids = ["private-a", "private-b"]
      direction  = "INBOUND" # Default: "OUTBOUND"

      # Networks allowed to query this endpoint on TCP/UDP 53 (on-premises CIDRs).
      ingress_cidr_blocks = [
        "172.0.0.0/16"
      ]
    }

    # Same hub using AWS resource IDs instead of wrapper keys:
    # "vpn-01-outbound-by-id" = {
    #   vpc_id     = "vpc-01xxxxxxxxxxxxx"
    #   subnet_ids = ["subnet-01xxxxxxxxxxxxx", "subnet-02xxxxxxxxxxxxx"]
    #   direction  = "OUTBOUND"
    #   rules = {
    #     "onprem" = {
    #       domain_name = "corp.example.com"
    #       target_ips  = ["172.0.0.1"]
    #     }
    #   }
    # }

    # Spoke account: associate a RAM-shared rule. Requires create_endpoint = false.
    "shared-onprem" = {
      vpc             = "vpc-01"
      create_endpoint = false # Default: true
      rule_associations = {
        "onprem" = {
          resolver_rule_id = "rslvr-rr-01xxxxxxxxxxxxx"
        }
      }
      # Lookup by rule name or domain instead of ID:
      # rule_associations = {
      #   "onprem" = { rule_name = "onprem" }
      #   # "onprem" = { domain_name = "corp.example.com" }
      # }
      # If the RAM invite is not auto-accepted:
      # accept_resource_share  = true # Default: false
      # ram_resource_share_arn = "arn:aws:ram:us-east-2:123456789012:resource-share/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    }
  }

  route53_resolver_defaults = var.route53_resolver_defaults
}
