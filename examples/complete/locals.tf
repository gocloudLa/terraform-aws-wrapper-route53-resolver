locals {
  # Simulated outputs from wrapper-vpc (replace with actual remote_state / module outputs)
  vpc_parameter = {
    vpcs = {
      "vpc-01" = {
        vpc_id = "vpc-01xxxxxxxxxxxxx"
      }
    }
    subnets = {
      "vpc-01-private-a" = { id = "subnet-01xxxxxxxxxxxxx" }
      "vpc-01-private-b" = { id = "subnet-02xxxxxxxxxxxxx" }
      "vpc-01-private-c" = { id = "subnet-03xxxxxxxxxxxxx" }
    }
  }
}
