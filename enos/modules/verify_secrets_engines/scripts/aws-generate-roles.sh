#!/usr/bin/env bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: BUSL-1.1

set -e

fail() {
  echo "$1" 1>&2
  exit 1
}

# # -------PKI TESTING
MOUNT=aws
AWS_REGION=us-east-1
AWS_IAM_ROLE=enos-aws-main-role
AWS_POLICY=enos-aws-test-role-policy
VAULT_ADDR=http://127.0.0.1:8200
VAULT_INSTALL_DIR=/opt/homebrew/bin
VAULT_TOKEN=root
TEST_POLICY_ARN="arn:aws:iam::774305585021:policy/${AWS_POLICY}"
ROLE_ARNS="arn:aws:iam::774305585021:role/${AWS_IAM_ROLE}"
vault secrets enable --path=${MOUNT} aws > /dev/null 2>&1  || echo "AWS Engine already enabled!"
echo -e "------------|${AWS_REGION}|-----------|${AWS_ACCESS_KEY_ID}|-------|${AWS_SECRET_ACCESS_KEY}|-----\n"

[[ -z "$AWS_REGION" ]] && fail "AWS_REGION env variable has not been set"
[[ -z "$AWS_IAM_ROLE" ]] && fail "AWS_IAM_ROLE env variable has not been set"
[[ -z "$MOUNT" ]] && fail "MOUNT env variable has not been set"
[[ -z "$VAULT_ADDR" ]] && fail "VAULT_ADDR env variable has not been set"
[[ -z "$VAULT_INSTALL_DIR" ]] && fail "VAULT_INSTALL_DIR env variable has not been set"
[[ -z "$VAULT_TOKEN" ]] && fail "VAULT_TOKEN env variable has not been set"

binpath=${VAULT_INSTALL_DIR}/vault
test -x "$binpath" || fail "unable to locate vault binary at $binpath"

export VAULT_FORMAT=json

echo "Configuring Vault AWS"
#"$binpath" write "${MOUNT}/config/root" region=${AWS_REGION} || fail "Cannot set vault AWS credentials"
USERNAME_TEMPLATE="{{ if (eq .Type \"STS\") }}{{ printf \"${AWS_IAM_ROLE}-%s-%s\" (random 20) (unix_time) | truncate 32 }}{{ else }}{{ printf \"${AWS_IAM_ROLE}-%s-%s\" (unix_time) (random 20) | truncate 60 }}{{ end }}"
"$binpath" write "${MOUNT}/config/root" region=${AWS_REGION} username_template="${USERNAME_TEMPLATE}"

echo "Creating Role to create user"
"$binpath" write "aws/roles/${AWS_IAM_ROLE}" tl="1h" max_ttl="2h" \
    credential_type=iam_user \
    permissions_boundary_arn="$TEST_POLICY_ARN" \
    policy_document=-<<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:DescribeRegions",
      "Action": "ec2:*",
      "Resource": "*"
    }
  ]
}
EOF

echo "Creating Role to assume role"
"$binpath" write "aws/roles/${AWS_IAM_ROLE}_assume_role" tl="1h" max_ttl="2h"\
    credential_type="assumed_role" \
    role_arns="$ROLE_ARNS" \

echo "Verifying root config"
ROOT_USERNAME_TEMPLATE=$("$binpath" read "${MOUNT}/config/root" | jq -r '.data.username_template')
[[ "$ROOT_USERNAME_TEMPLATE" == *"$AWS_IAM_ROLE"* ]] || echo "Uername Template does not include the current role"

echo "Verifying roles list"
ROLE=$("$binpath" list "${MOUNT}/roles" | jq -r '.[]')
[[ -z "$ROLE" ]] && fail "No AWS roles created!"

echo "Verifying New Credentials"
"$binpath" read "${MOUNT}/creds/${AWS_IAM_ROLE}" || echo "FAILED TO READ: ${AWS_IAM_ROLE}_user"
"$binpath" read "${MOUNT}/creds/${AWS_IAM_ROLE}_assume_role" || echo "FAILED TO READ: ${AWS_IAM_ROLE}_assume_role"