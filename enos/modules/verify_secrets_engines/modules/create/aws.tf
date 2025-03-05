# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: BUSL-1.1

locals {
  // Variables
  aws_mount             = "aws"                    # Vault aws engine
  aws_main_role         = "enos-aws-main-role"   # Role name
  aws_test_role         = "enos-aws-test-role" # Temp Role name
  aws_region            = var.aws_region
  policy_name           = format("%s-policy", aws_iam_role.enos_aws_test_role.name)

  // Construct role_resource without referencing the aws_iam_role resource directly in locals
  user_resource         = format("arn:aws:iam::%s:user/%s", data.aws_caller_identity.aws_identity.account_id, local.aws_test_role)
  role_main_resource         = format("arn:aws:iam::%s:role/%s", data.aws_caller_identity.aws_identity.account_id, local.aws_main_role)
  role_test_resource         = format("arn:aws:iam::%s:role/%s", data.aws_caller_identity.aws_identity.account_id, local.aws_test_role)
  policy_resource       = format("arn:aws:iam::%s:policy/%s", data.aws_caller_identity.aws_identity.account_id, local.aws_test_role)

  // Output
  aws_output = {
    mount             = local.aws_mount
    vault_role        = local.aws_main_role
    region            = local.aws_region
    aws_role          = local.aws_main_role
  }
}

output "aws" {
  value = local.aws_output
}

data "aws_region" "aws_region" {}

data "aws_caller_identity" "aws_identity" {}

resource "aws_iam_role_policy_attachments_exclusive" "enos_aws_main_role" {
  role_name   = aws_iam_role.enos_aws_main_role.name
  policy_arns = []
}

resource "aws_iam_role_policies_exclusive" "enos_aws_main_role" {
  role_name    = aws_iam_role.enos_aws_main_role.name
  policy_names = keys(aws_iam_role_policy.enos_aws_main_role)
}

resource "aws_iam_role_policy" "enos_aws_main_role" {
  for_each = {
    iam_user = data.aws_iam_policy_document.enos_aws_main_role_iam_user.json
    assumed_role = data.aws_iam_policy_document.enos_aws_main_role_assumed_role.json
  }
  role     = aws_iam_role.enos_aws_main_role.name
  name     = each.key
  policy   = each.value
}

data "aws_iam_policy_document" "enos_aws_main_role_iam_user" {
  statement {
    actions = [
      "iam:CreateUser",
    ]
    resources = ["${local.user_resource}-*"]
    condition {
      test = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values = [aws_iam_policy.enos_aws_test_role.arn]
    }
  }
  statement {
    actions = [
      "iam:AttachUserPolicy",
      "iam:CreateAccessKey",
      "iam:DeleteAccessKey",
      "iam:DeleteUser",
      "iam:DeleteUserPolicy",
      "iam:DetachUserPolicy",
      "iam:GetAccessKeyLastUsed",
      "iam:GetInstanceProfile",
      "iam:GetRole",
      "iam:GetUser",
      "iam:GetUserPolicy",
      "iam:List*",
      "iam:PutUserPolicy",
      "iam:TagUser",
      "iam:UntagUser",
      "iam:UpdateAccessKey",
    ]
    resources = ["${local.role_test_resource}-*"]
  }
}

data "aws_iam_policy_document" "enos_aws_main_role_assumed_role" {
  statement {
    actions = [
      "sts:AssumeRole",
      "sts:SetSourceIdentity",
      "sts:TagSession",
    ]
    resources = [aws_iam_role.enos_aws_test_role.arn
    ]
  }
}

resource "aws_iam_role" "enos_aws_test_role" {
  name               = local.aws_test_role
  assume_role_policy = data.aws_iam_policy_document.enos_aws_test_role_assume_role.json
  description        = "IAM Role used to test assumed_role mode of AWS Secrets Backend "
}

data "aws_iam_policy_document" "enos_aws_test_role_assume_role" {
  statement {
    actions = [
      "sts:AssumeRole",
      "sts:SetSourceIdentity",
      "sts:TagSession",
    ]
    principals {
      type        = "AWS"
      identifiers = [
        "*"
      ]
    }
    condition {
      test = "StringLike"
      variable = "aws:PrincipalAccount"
      values = [data.aws_caller_identity.aws_identity.account_id]
    }
  }
}

resource "aws_iam_role_policy_attachments_exclusive" "enos_aws_test_role" {
  role_name   = aws_iam_role.enos_aws_test_role.name
  policy_arns = []
}

resource "aws_iam_role_policies_exclusive" "enos_aws_test_role" {
  role_name    = aws_iam_role.enos_aws_test_role.name
  policy_names = keys(aws_iam_role_policy.enos_aws_test_role)
}

resource "aws_iam_role_policy" "enos_aws_test_role" {
  for_each = {
    iam_user = data.aws_iam_policy_document.enos_aws_main_role_iam_user.json
    assumed_role = data.aws_iam_policy_document.enos_aws_main_role_assumed_role.json
  }
  role     = aws_iam_role.enos_aws_test_role.name
  name     = each.key
  policy   = each.value
}

resource "aws_iam_policy" "enos_aws_test_role" {
  name = local.policy_name
  policy = data.aws_iam_policy_document.enos_aws_test_role.json
}

data "aws_iam_policy_document" "enos_aws_test_role" {
  statement {
    actions = ["iam:CreateUser"]
    resources = ["arn:aws:iam::${data.aws_caller_identity.aws_identity.account_id}:user/$${aws:username}*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values = [local.policy_resource]
    }
  }
  statement {
    actions = [
      "iam:AttachUserPolicy",
      "iam:CreateAccessKey",
      "iam:DeleteAccessKey",
      "iam:DeleteUser",
      "iam:DeleteUserPolicy",
      "iam:DetachUserPolicy",
      "iam:GetAccessKeyLastUsed",
      "iam:GetInstanceProfile",
      "iam:GetRole",
      "iam:GetUser",
      "iam:GetUserPolicy",
      "iam:List*",
      "iam:PutUserPolicy",
      "iam:TagUser",
      "iam:UntagUser",
      "iam:UpdateAccessKey",
    ]
    resources = ["arn:aws:iam::${data.aws_caller_identity.aws_identity.account_id}:user/$${aws:username}*"]
  }
  statement {
    actions = [
      "ec2:DescribeRegions",
    ]
    resources = [
      "*",
    ]
  }
  statement {
    actions = [
      "sts:AssumeRole",
      "sts:SetSourceIdentity",
      "sts:TagSession",
    ]
    resources = [
      aws_iam_role.enos_aws_test_role.arn,
    ]
  }
  statement {
    effect = "Deny"
    not_actions = [
      "ec2:DescribeRegions",
      "iam:AttachUserPolicy",
      "iam:CreateAccessKey",
      "iam:CreateUser",
      "iam:DeleteAccessKey",
      "iam:DeleteUser",
      "iam:DeleteUserPolicy",
      "iam:DetachUserPolicy",
      "iam:GetAccessKeyLastUsed",
      "iam:GetInstanceProfile",
      "iam:GetRole",
      "iam:GetUser",
      "iam:GetUserPolicy",
      "iam:List*",
      "iam:PutUserPolicy",
      "iam:TagUser",
      "iam:UntagUser",
      "iam:UpdateAccessKey",
      "sts:AssumeRole",
      "sts:SetSourceIdentity",
      "sts:TagSession",
    ]
    resources = [
      "*",
    ]
  }
}

















# data "aws_iam_policy" "demo_user_permissions_boundary" {
#   name = "DemoUser"
# }
#
# resource "aws_iam_user" "vault_mount_user" {
#   name                 = "demo-enos-iam-${local.my_email}"
#   permissions_boundary = data.aws_iam_policy.demo_user_permissions_boundary.arn
#   force_destroy        = true
# }
#
# resource "aws_iam_user_policy_attachment" "vault_mount_user" {
#   user       = aws_iam_user.vault_mount_user.name
#   policy_arn = data.aws_iam_policy.demo_user_permissions_boundary.arn
# }
#
# resource "aws_iam_access_key" "vault_mount_user" {
#   user = aws_iam_user.vault_mount_user.name
# }
