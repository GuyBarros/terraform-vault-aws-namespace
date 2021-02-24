# you need to export VAULT_ADDR and VAULT_TOKEN as env variables before running this code
# this can be added to you TFC env vars

resource "vault_namespace" "default" {
  path = local.application_name
}

provider "vault" {
  alias     = "default"
  namespace = trimsuffix(vault_namespace.default.id, "/")
}

locals {
  application_name = "terraform-modules-development-aws"
  env              = "dev"
  service          = "guy"
}

# Credentials will be in the following environment variables:
# AWS_ACCESS_KEY AWS_SECRET_KEY, AWS_REGION
# It is best to create an "trusted" Lamba function which will trigger upon the
# vault-audit log showing a successful request of aws-secrets-backend
# the function is to send a POST the following endpoint: /aws/config/rotate-root
module "aws" {
  # source     = "../../"
  source           = "git::https://github.com/devops-adeel/terraform-vault-secrets-aws?ref=v0.1.0"
   providers = {
    vault = vault.default
  }
  entity_ids = [module.vault_approle.entity_id]
}

resource "vault_auth_backend" "auth_backend" {
  type = "approle"
  provider = vault.default
}

module "vault_approle" {
  source           = "git::https://github.com/devops-adeel/terraform-vault-approle.git?ref=v0.6.1"
  application_name = local.application_name
  env              = local.env
  service          = local.service
  mount_accessor   = vault_auth_backend.auth_backend.accessor
   providers = {
    vault = vault.default
  }
}

resource "vault_aws_secret_backend_role" "default" {
  provider = vault.default
  backend         = module.default.backend_path
  name            = format("%s-%s", local.env, local.service)
  credential_type = "assumed_role"
  role_arns = [ "arn:aws:iam::11111111111111:instance-profile/exampleAWSrole" ]
}

resource "vault_aws_secret_backend_role" "iam-role" {
  provider = vault.default
  backend         = module.default.backend_path
  name            = "iam-role"
  credential_type = "iam_user"
  policy_document = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "iam:*",
      "Resource": "*"
    }
  ]
}
EOT
}


### Test that you can generate a dynamic credential
/*
provider "aws" {
  access_key = data.vault_aws_access_credentials.default.access_key
  secret_key = data.vault_aws_access_credentials.default.secret_key
}

data "vault_aws_access_credentials" "default" {
  backend = module.default.backend_path
  role    = vault_aws_secret_backend_role.default.name
}

resource "aws_s3_bucket" "default" {
  bucket = local.application_name
  acl    = "private"
}
*/
