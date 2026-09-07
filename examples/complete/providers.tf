# Default provider. Aliased providers can assume into a spoke / consumer account.
provider "aws" {
  region = local.metadata.aws_region
}

# Optional: spoke account that associates RAM-shared resolver rules.
# provider "aws" {
#   alias  = "spoke"
#   region = local.metadata.aws_region
#   # profile = "democorp-spoke"
# }
