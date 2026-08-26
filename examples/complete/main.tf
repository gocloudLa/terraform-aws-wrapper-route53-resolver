module "wrapper_route53_resolver" {
  source = "../../"

  metadata = local.metadata
  # Standalone example only. Standard Platform modules/base sets vpc_parameter = module.wrapper_vpc.
  vpc_parameter = local.vpc_parameter

  route53_resolver_parameters = {
    # Hybrid DNS over Site-to-Site VPN (vpn-01).
    # Place both endpoints in private subnets that already route to on-premises via vpn-01 / TGW.
    #
    # Outbound: AWS → on-premises. Workloads in vpc-01 (and RAM-shared spokes) resolve
    # pjcaba.gob.ar against on-premises DNS over vpn-01.
    "vpn-01-outbound" = {
      vpc        = "vpc-01"
      subnet_ids = ["private-a", "private-b"]
      direction  = "OUTBOUND"

      rules = {
        "pjcaba" = {
          domain_name = "pjcaba.gob.ar"
          rule_type   = "FORWARD"
          # Replace with the on-premises DNS server IP(s) reachable over vpn-01.
          target_ips = ["10.45.1.10", "10.45.1.11"]
        }
      }

      ## Share FORWARD rules with the organization, or with specific account IDs
      ram_share_with_organization = true
      # share_rules    = true
      # ram_principals = [
      #   "123456789012",
      #   "234567890123"
      # ]
      # ram_allow_external_principals = false
      # ram_name                      = null
    }

    # Inbound: on-premises → AWS. On-premises resolvers over vpn-01 query this endpoint
    # so they can resolve private hosted zones in AWS. No FORWARD rules — inbound
    # creates the endpoint because direction is INBOUND. After apply, give the inbound
    # ENI IPs (resolver_endpoint_ip_addresses) to on-premises DNS as forwarders.
    "vpn-01-inbound" = {
      vpc        = "vpc-01"
      subnet_ids = ["private-a", "private-b"]
      direction  = "INBOUND"
      # Optional: inbound already implies create_endpoint = true when rules is empty.
      # create_endpoint = true

      # Networks allowed to query this endpoint on TCP/UDP 53 (vpn-01 on-prem CIDRs).
      ingress_cidr_blocks = [
        "10.45.0.0/16", # Central1-Yrigoyen
        "10.49.0.0/16", # Central2-Roca
        "10.66.0.0/16", # Central3-Suipacha
        "10.54.0.0/16", # floating HA between central nodes
        "10.48.0.0/16"  # Roca 530
      ]
    }

    # Same hub using AWS resource IDs instead of wrapper keys:
    # "vpn-01-outbound-by-id" = {
    #   resource_ids = {
    #     vpc_id     = "vpc-01xxxxxxxxxxxxx"
    #     subnet_ids = ["subnet-01xxxxxxxxxxxxx", "subnet-02xxxxxxxxxxxxx"]
    #   }
    #   direction = "OUTBOUND"
    #   rules = {
    #     "pjcaba" = {
    #       domain_name = "pjcaba.gob.ar"
    #       target_ips  = ["10.45.1.10"]
    #     }
    #   }
    # }

    # Spoke VPC: attach a rule already shared via RAM. No endpoint, rules, or RAM share.
    "shared-onprem" = {
      vpc = "vpc-01"
      shared_rules = {
        "pjcaba" = "rslvr-rr-01xxxxxxxxxxxxx"
      }
      # Lookup by rule name or domain instead of ID:
      # rule_associations = {
      #   "pjcaba" = { rule_name = "pjcaba" }
      #   # "pjcaba" = { domain_name = "pjcaba.gob.ar" }
      #   # "pjcaba" = { resource_id = "rslvr-rr-01xxxxxxxxxxxxx" }
      # }
      # If the RAM invite is not auto-accepted:
      # accept_resource_share  = true
      # ram_resource_share_arn = "arn:aws:ram:us-east-2:123456789012:resource-share/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    }
  }

}
