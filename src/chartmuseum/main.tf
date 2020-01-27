resource "kubernetes_namespace" "chartmuseum_namespace" {
  metadata {
    name = "chartmuseum"
  }
}

resource "minio_iam_user" "minio_chartmuseum_user" {
  name          = "chartmuseum"
  force_destroy = true

  tags = {
    provider = "k8s"
    service  = "chartmuseum"
  }
}

resource "kubernetes_secret" "chartmuseum_s3_credentials" {
  metadata {
    name      = "chartmuseum-s3"
    namespace = kubernetes_namespace.chartmuseum_namespace.metadata[0].name
  }

  data = {
    "aws-secret-access-key" = minio_iam_user.minio_chartmuseum_user.secret
    "aws-access-key"        = minio_iam_user.minio_chartmuseum_user.name
    "basic-auth-username"   = "chartadmin"
    "basic-auth-password"   = "chartgott"
  }

  type = "Opaque"
}


resource "minio_s3_bucket" "minio_chartmuseum_bucket" {
  bucket = "chartmuseum"
  acl    = "private"
}

resource "minio_iam_policy" "minio_chartmuseum_user_policy" {
  name   = "chartmuseum"
  policy = <<EOF
{
     "Version": "2012-10-17",
     "Statement": [
         {
             "Effect": "Allow",
             "Sid": "AllowObjectsCRUD",
             "Action": [
                "s3:DeleteObject",
                "s3:GetObject",
                "s3:PutObject"
             ],
             "Resource": [
                 "arn:aws:s3:::${minio_s3_bucket.minio_chartmuseum_bucket.bucket}/*"
             ]
         },
         {
             "Effect": "Allow",
             "Sid": "AllowListObjects",
             "Action": [
                 "s3:ListBucket"
             ],
             "Resource": [
                 "arn:aws:s3:::${minio_s3_bucket.minio_chartmuseum_bucket.bucket}"
             ]
         }
     ]
 }
EOF
}

resource "minio_iam_user_policy_attachment" "minio_chartmuseum_user_policy" {
  policy_name = minio_iam_policy.minio_chartmuseum_user_policy.name
  user_name   = minio_iam_user.minio_chartmuseum_user.name
}

data "helm_repository" "stable" {
  name = "stable"
  url  = "https://kubernetes-charts.storage.googleapis.com"
}

resource "helm_release" "chartmuseum" {
  name       = "chartmuseum"
  repository = data.helm_repository.stable.metadata[0].name
  chart      = "chartmuseum"
  namespace  = kubernetes_namespace.chartmuseum_namespace.metadata[0].name
  values = [
    "${file("files/chartmuseum-chart-values.yml")}"
  ]
  set {
    name  = "env.open.STORAGE"
    value = "amazon"
  }
  set {
    name  = "env.open.STORAGE_AMAZON_BUCKET"
    value = minio_s3_bucket.minio_chartmuseum_bucket.bucket
  }
  set {
    name  = "env.existingSecret"
    value = kubernetes_secret.chartmuseum_s3_credentials.metadata[0].name
  }
  set {
    name  = "env.existingSecretMappings.AWS_ACCESS_KEY_ID"
    value = "aws-access-key"
  }
  set {
    name  = "env.existingSecretMappings.AWS_SECRET_ACCESS_KEY"
    value = "aws-secret-access-key"
  }
  set {
    name  = "env.existingSecretMappings.BASIC_AUTH_USER"
    value = "basic-auth-username"
  }
  set {
    name  = "env.existingSecretMappings.BASIC_AUTH_PASS"
    value = "basic-auth-password"
  }

  set {
    name  = "env.open.STORAGE_AMAZON_ENDPOINT"
    value = "http://minio.minio.svc:9000"
  }
  set {
    name  = "env.open.STORAGE_AMAZON_REGION"
    value = "minio"
  }
  set {
    name  = "env.open.DISABLE_API"
    value = "false"
  }
  set {
    name  = "env.open.AUTH_ANONYMOUS_GET"
    value = "true"
  }

}

