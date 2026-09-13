# Standard Platform - Terraform Module 🚀🚀
<p align="right"><a href="https://partners.amazonaws.com/partners/0018a00001hHve4AAC/GoCloud"><img src="https://img.shields.io/badge/AWS%20Partner-Advanced-orange?style=for-the-badge&logo=amazonaws&logoColor=white" alt="AWS Partner"/></a><a href="LICENSE"><img src="https://img.shields.io/badge/License-Apache%202.0-green?style=for-the-badge&logo=apache&logoColor=white" alt="LICENSE"/></a></p>

Welcome to the Standard Platform — a suite of reusable and production-ready Terraform modules purpose-built for AWS environments.
Each module encapsulates best practices, security configurations, and sensible defaults to simplify and standardize infrastructure provisioning across projects.

## 📦 Module: Terraform Route53 Resolver Module
<p align="right"><a href="https://github.com/gocloudLa/terraform-aws-wrapper-route53-resolver/releases/latest"><img src="https://img.shields.io/github/v/release/gocloudLa/terraform-aws-wrapper-route53-resolver.svg?style=for-the-badge" alt="Latest Release"/></a><a href=""><img src="https://img.shields.io/github/last-commit/gocloudLa/terraform-aws-wrapper-route53-resolver.svg?style=for-the-badge" alt="Last Commit"/></a><a href="https://registry.terraform.io/modules/gocloudLa/wrapper-route53-resolver/aws"><img src="https://img.shields.io/badge/Terraform-Registry-7B42BC?style=for-the-badge&logo=terraform&logoColor=white" alt="Terraform Registry"/></a></p>
The Terraform Wrapper for Route 53 Resolver provisions outbound and inbound resolver endpoints, forwarding rules toward on-premises DNS, VPC associations, and AWS RAM shares so other accounts and VPCs can resolve those domains.


### ✨ Features

- 🛰️ [Outbound forwarding to on-premises DNS](#outbound-forwarding-to-on-premises-dns) - Resolver endpoint in the hub VPC with FORWARD rules targeting on-premises IPs reachable over VPN or Transit Gateway

- 🔄 [Hybrid DNS over Site-to-Site VPN](#hybrid-dns-over-site-to-site-vpn) - Pair an OUTBOUND and an INBOUND endpoint so AWS and on-premises can resolve each other's private domains

- 🔗 [RAM sharing of resolver rules](#ram-sharing-of-resolver-rules) - Share FORWARD rules with account IDs, OUs, or an organization ARN so spoke VPCs can resolve the same domains

- 🛡️ [Security group for DNS to on-premises](#security-group-for-dns-to-on-premises) - Auto-created security group allowing TCP/UDP 53 toward rule target IPs




## 🚀 Quick Start
```hcl
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

    share_rules    = true # Default: false
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
  # they can resolve private hosted zones in AWS. No FORWARD rules — inbound
  # creates the endpoint because direction is INBOUND. After apply, give the
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

  # Spoke VPC: attach a rule already shared via RAM. No endpoint, rules, or RAM share.
  "shared-onprem" = {
    vpc = "vpc-01"
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
```


## 🔧 Additional Features Usage

### Outbound forwarding to on-premises DNS
Create an OUTBOUND endpoint in private subnets that already have a route to on-premises networks (Site-to-Site VPN, TGW). Each rule in `rules` forwards a domain to one or more target IPs (`ip`, `ip:port`, or `{ ip, port }`). The wrapper associates the rules with the endpoint VPC by default (`associate_vpc = true`). An OUTBOUND endpoint is created when `rules` is non-empty (or `create_endpoint = true`). At least two subnets in different AZs are required.


<details><summary>Forward a corporate domain to on-premises DNS</summary>

```hcl
route53_resolver_parameters = {
  "onprem" = {
    vpc        = "vpc-01"
    subnet_ids = ["private-a", "private-b"]
    direction  = "OUTBOUND"
    rules = {
      "corp" = {
        domain_name = "corp.example.com"
        target_ips  = ["172.0.0.1", "172.0.0.2"]
      }
    }
  }
}
```


</details>


### Hybrid DNS over Site-to-Site VPN
Bidirectional hybrid DNS needs two endpoints in the same private subnets that already route over Site-to-Site VPN and Transit Gateway. OUTBOUND is AWS → on-premises: workloads (and RAM-shared spokes) forward `corp.example.com` to on-premises DNS IPs. INBOUND is on-premises → AWS: on-premises resolvers query the inbound ENIs so they can resolve private hosted zones. INBOUND does not use `rules`; `direction = "INBOUND"` creates the endpoint. Restrict `ingress_cidr_blocks` to the on-premises CIDRs. After apply, configure on-premises DNS to forward AWS private zones to `resolver_endpoint_ip_addresses["vpn-01-inbound"]`. RAM shares only the outbound FORWARD rules, not the inbound endpoint.


<details><summary>Outbound (AWS resolves on-premises domains)</summary>

```hcl
route53_resolver_parameters = {
  "vpn-01-outbound" = {
    vpc        = "vpc-01"
    subnet_ids = ["private-a", "private-b"]
    direction  = "OUTBOUND"
    rules = {
      "onprem" = {
        domain_name = "corp.example.com"
        target_ips  = ["172.0.0.1", "172.0.0.2"]
      }
    }
    share_rules    = true
    ram_principals = ["123456789012"]
  }
}
```


</details>

<details><summary>Inbound (on-premises resolves AWS private zones)</summary>

```hcl
route53_resolver_parameters = {
  "vpn-01-inbound" = {
    vpc                 = "vpc-01"
    subnet_ids          = ["private-a", "private-b"]
    direction           = "INBOUND"
    ingress_cidr_blocks = ["172.0.0.0/16"]
  }
}
```


</details>


### RAM sharing of resolver rules
AWS RAM shares the resolver rules, not the endpoint. Set `share_rules = true` and `ram_principals`: account IDs, OU ARNs, or the organization ARN (`arn:aws:organizations::<management-account>:organization/o-…`), the same contract as the TGW wrapper. In the consumer account, pass `vpc` plus `rule_associations` (`resolver_rule_id`, `rule_name`, or `domain_name`) — no endpoint or RAM share when `rules` is empty. Enable RAM sharing with AWS Organizations in the management account so intra-org shares are auto-accepted. If the invite is not auto-accepted, set `accept_resource_share = true` and `ram_resource_share_arn`.


<details><summary>Share rules with specific account IDs</summary>

```hcl
route53_resolver_parameters = {
  "onprem" = {
    vpc        = "vpc-01"
    subnet_ids = ["private-a", "private-b"]
    rules = {
      "corp" = {
        domain_name = "corp.example.com"
        target_ips  = ["172.0.0.1"]
      }
    }
    share_rules    = true
    ram_principals = ["123456789012", "234567890123"]
  }
}
```


</details>

<details><summary>Share rules with the organization</summary>

```hcl
route53_resolver_parameters = {
  "onprem" = {
    vpc        = "vpc-01"
    subnet_ids = ["private-a", "private-b"]
    rules = {
      "corp" = {
        domain_name = "corp.example.com"
        target_ips  = ["172.0.0.1"]
      }
    }
    share_rules    = true
    ram_principals = ["arn:aws:organizations::123456789012:organization/o-xxxxxxxxxx"]
  }
}
```


</details>

<details><summary>Associate a shared rule in a spoke VPC</summary>

```hcl
route53_resolver_parameters = {
  "shared-onprem" = {
    vpc = "vpc-01"
    rule_associations = {
      "corp" = {
        resolver_rule_id = "rslvr-rr-01xxxxxxxxxxxxx"
        # rule_name    = "corp"
        # domain_name  = "corp.example.com"
      }
    }
  }
}
```


</details>


### Security group for DNS to on-premises
When `create_security_group = true`, the wrapper creates a security group on the endpoint. OUTBOUND endpoints egress TCP/UDP 53 to the rule target IPs (or `egress_cidr_blocks`). INBOUND endpoints allow TCP/UDP 53 from `ingress_cidr_blocks` only — empty ingress is rejected rather than opened to `0.0.0.0/0`. Pass extra IDs with `security_group_ids`.


<details><summary>Restrict egress to on-premises DNS CIDRs</summary>

```hcl
route53_resolver_parameters = {
  "onprem" = {
    vpc                = "vpc-01"
    subnet_ids         = ["private-a", "private-b"]
    egress_cidr_blocks = ["172.0.0.1/32", "172.0.0.2/32"]
    rules = {
      "corp" = {
        domain_name = "corp.example.com"
        target_ips  = ["172.0.0.1", "172.0.0.2"]
      }
    }
  }
}
```


</details>

<details><summary>Restrict inbound queries to on-premises CIDRs</summary>

```hcl
route53_resolver_parameters = {
  "vpn-01-inbound" = {
    vpc                 = "vpc-01"
    subnet_ids          = ["private-a", "private-b"]
    direction           = "INBOUND"
    ingress_cidr_blocks = ["172.0.0.0/16"]
  }
}
```


</details>




## 📑 Inputs
| Name                          | Description                                                                                        | Type         | Default    | Required |
| ----------------------------- | -------------------------------------------------------------------------------------------------- | ------------ | ---------- | -------- |
| vpc                           | Key into `vpc_parameter.vpcs` (for example `vpc-01`). Not an AWS VPC ID.                           | string       | null       | no       |
| vpc_id                        | Explicit AWS VPC ID; wins over `vpc` when set.                                                     | string       | null       | no       |
| subnet_ids                    | Wrapper keys (`private-a` → `{vpc}-private-a`) or AWS subnet IDs.                                  | list(string) | []         | no       |
| ip_addresses                  | Optional explicit ENI IPs (`subnet_id`, `ip`).                                                     | list(object) | []         | no       |
| direction                     | Resolver endpoint direction (`OUTBOUND` or `INBOUND`).                                             | string       | "OUTBOUND" | no       |
| create_endpoint               | Create the resolver endpoint. When omitted, true if `rules` is set or `direction` is `INBOUND`.    | bool         | null       | no       |
| create_security_group         | Create the endpoint security group.                                                                | bool         | true       | no       |
| security_group_ids            | Additional security group IDs attached to the endpoint.                                            | list(string) | []         | no       |
| ingress_cidr_blocks           | CIDRs allowed to query an INBOUND endpoint on port 53.                                             | list(string) | []         | no       |
| egress_cidr_blocks            | CIDRs the endpoint may reach on port 53. Defaults to rule target IPs.                              | list(string) | []         | no       |
| protocols                     | Resolver protocols (`Do53`, `DoH`, `DoH-FIPS`).                                                    | list(string) | null       | no       |
| resolver_endpoint_type        | Endpoint IP type (`IPV4`, `IPV6`, `DUALSTACK`).                                                    | string       | "IPV4"     | no       |
| rules                         | Map of forwarding rules (`domain_name`, `target_ips`, `rule_type`).                                | map          | {}         | no       |
| associate_vpc                 | Associate created rules with the endpoint VPC.                                                     | bool         | true       | no       |
| rule_associations             | Associations for existing or RAM-shared rules (`resolver_rule_id`, `rule_name`, or `domain_name`). | map          | {}         | no       |
| share_rules                   | Share FORWARD rules through AWS RAM.                                                               | bool         | false      | no       |
| ram_name                      | RAM resource share name.                                                                           | string       | null       | no       |
| ram_principals                | Account IDs, Organization ARNs, or OU ARNs.                                                        | list(string) | []         | no       |
| ram_allow_external_principals | Allow principals outside the organization.                                                         | bool         | false      | no       |
| ram_resource_share_arn        | Existing RAM share ARN (producer reuse or consumer accept).                                        | string       | null       | no       |
| accept_resource_share         | Consumer: accept `ram_resource_share_arn` before associating shared rules.                         | bool         | false      | no       |
| tags                          | Additional tags merged with common metadata tags.                                                  | map(string)  | {}         | no       |







## ⚠️ Important Notes
- ⚠️ **Connectivity**: The endpoint subnets must already route to the on-premises DNS IPs (VPN or TGW). The wrapper does not create VPN or TGW routes.
- ⚠️ **Two AZs**: A resolver endpoint requires at least two IP addresses in different Availability Zones (`subnet_ids` of length >= 2).
- 🔒 **INBOUND ingress**: `ingress_cidr_blocks` is required when creating an INBOUND endpoint security group. The wrapper does not default that rule to `0.0.0.0/0`.
- ℹ️ **vpc_parameter**: Standard Platform `modules/base` sets `vpc_parameter = module.wrapper_vpc`. Set `vpc` / `subnet_ids` to wrapper keys (`vpc-01`, `private-a` → `subnets["vpc-01-private-a"]`). Use `vpc_id` and raw subnet IDs when there is no wrapper-vpc output. `vpc-01` is a map key, not an AWS VPC ID.
- ℹ️ **Inbound vs outbound**: OUTBOUND forwards AWS queries to on-premises DNS (`rules`). INBOUND lets on-premises resolvers query AWS private hosted zones; it has no `rules`. `direction = "INBOUND"` creates the endpoint. After apply, point on-premises DNS at `resolver_endpoint_ip_addresses`.
- ℹ️ **RAM vs endpoint**: Only FORWARD rules are shareable. Spoke VPCs associate the shared rule (`vpc` + `rule_associations`). An OUTBOUND endpoint is created only when `rules` is non-empty (or `create_endpoint = true`).



---

## 🤝 Contributing
We welcome contributions! Please see our contributing guidelines for more details.

## 🆘 Support
- 📧 **Email**: info@gocloud.la

## 🧑‍💻 About
We are focused on Cloud Engineering, DevOps, and Infrastructure as Code.
We specialize in helping companies design, implement, and operate secure and scalable cloud-native platforms.
- 🌎 [www.gocloud.la](https://www.gocloud.la)
- ☁️ AWS Advanced Partner (Terraform, DevOps, GenAI)
- 📫 Contact: info@gocloud.la

## 📄 License
This project is licensed under the Apache 2.0 License - see the [LICENSE](LICENSE) file for details. 