resource "kubernetes_namespace" "storage_namespace" {
  metadata {
    name = "minio"
  }
}

resource "kubernetes_secret" "minio_admin_credentials" {
  metadata {
    name      = "minio-admin-credentials"
    namespace = kubernetes_namespace.storage_namespace.metadata[0].name
  }

  data = {
    "accesskey" = "AKIAIOSFODNN7EXAMPLE"
    "secretkey" = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
  }
  type = "Opaque"
}


data "helm_repository" "stable" {
  name = "stable"
  url  = "https://kubernetes-charts.storage.googleapis.com"
}

resource "helm_release" "minio" {
  name       = "minio"
  repository = data.helm_repository.stable.metadata[0].name
  chart      = "minio"
  namespace  = kubernetes_namespace.storage_namespace.metadata[0].name
  values = [
    "${file("files/minio-chart-values.yml")}"
  ]

  set {
    name  = "existingSecret"
    value = kubernetes_secret.minio_admin_credentials.metadata[0].name
  }

}

resource "minio_iam_user" "minio_tf_cicd_user" {
  depends_on = [helm_release.minio]

  name          = "james"
  force_destroy = true

  tags = {
    provider = "k8s"
    service  = "ci/cd"
  }
}

resource "minio_s3_bucket" "minio_tf_state_bucket" {
  depends_on = [helm_release.minio]
  bucket     = "tf-state-files"
  acl        = "private"
}

resource "minio_iam_policy" "minio_tf_state_cicd_user_policy" {
  name   = "tf-cicd"
  policy = <<EOF
{
     "Version": "2012-10-17",
     "Statement": [
         {
             "Effect": "Allow",
             "Action": [
                 "s3:GetObject",
                 "s3:DeleteObject",
                 "s3:PutObject",
                 "s3:AbortMultipartUpload",
                 "s3:ListMultipartUploadParts"
             ],
             "Resource": [
                 "arn:aws:s3:::${minio_s3_bucket.minio_tf_state_bucket.bucket}/*"
             ]
         },
         {
             "Effect": "Allow",
             "Action": [
                 "s3:ListBucket"
             ],
             "Resource": [
                 "arn:aws:s3:::${minio_s3_bucket.minio_tf_state_bucket.bucket}"
             ]
         }
     ]
 }
EOF
}

resource "minio_iam_user_policy_attachment" "minio_tf_state_cicd_user_policy" {
  policy_name = minio_iam_policy.minio_tf_state_cicd_user_policy.name
  user_name   = minio_iam_user.minio_tf_cicd_user.name
}


resource "kubernetes_secret" "velero_k8s_credentials" {
  metadata {
    name      = "cicd-terraform-state"
    namespace = "tekton-pipelines"
  }

  data = {
    "AWS_ACCESS_KEY_ID"     = minio_iam_user.minio_tf_cicd_user.name
    "AWS_SECRET_ACCESS_KEY" = minio_iam_user.minio_tf_cicd_user.secret
  }
  type = "Opaque"
}
