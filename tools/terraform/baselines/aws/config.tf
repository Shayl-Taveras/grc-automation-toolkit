# config.tf
# Control Coverage: CM-2 (baseline configuration), CM-6 (configuration settings), CM-8 (component inventory)
# Framework: NIST 800-53 Rev 5 | FedRAMP Moderate
#
# Disabled: this account already has an AWS-managed "default" Config
# recorder (service-linked role AWSServiceRoleForConfig) predating this
# lab. AWS allows only one recorder per region, so ours can never coexist
# with it. The existing recorder stands as the CM-2/CM-6/CM-8 evidence
# instead.

/*
resource "aws_s3_bucket" "config" {
  bucket        = "${var.project_namex.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_server_side_econfig" {
  bucket = aws_s3_bucket.config.id

  rule {
    apply_server_side_encryption_by_d
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access
  bucket                  = aws_s3_bucket.config.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "confi
  statement {
    sid       = "AWSConfigBucketPermi
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.config.arn]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaw
    }
  }

  statement {
    sid       = "AWSConfigBucketDelivery"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources =["${aws_s3_bucket.config.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaw
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "conf
  bucket = aws_s3_bucket.config.id
  policy = data.aws_iam_policy_docume
}

data "aws_iam_policy_document" "config_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "config" {
  name               = "${var.project_name}-config-recorder"
  assume_role_policy = data.aws_iam_pme.json
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.na
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_re
  name     = "${var.project_name}-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = t
  }
}

resource "aws_config_delivery_channel
  name           = "${var.project_name}-delivery-channel"
  s3_bucket_name = aws_s3_bucket.conf
  depends_on     = [aws_config_configuration_recorder.this, aws_s3_bucket_policy.config]
}

resource "aws_config_configuration_re
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.this]
}
*/  