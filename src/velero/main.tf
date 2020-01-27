resource "kubernetes_namespace" "backup_namespace" {
  metadata {
    name = "velero"
  }
}

resource "minio_iam_user" "minio_backup_user" {
  name          = "velero"
  force_destroy = true

  tags = {
    provider = "k8s"
    service  = "backup"
  }
}

resource "minio_s3_bucket" "minio_backup_bucket" {
  bucket = "velero-backup"
  acl    = "private"
}

resource "minio_iam_policy" "minio_backup_user_policy" {
  name   = "velero-backups"
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
                 "arn:aws:s3:::${minio_s3_bucket.minio_backup_bucket.bucket}/*"
             ]
         },
         {
             "Effect": "Allow",
             "Action": [
                 "s3:ListBucket"
             ],
             "Resource": [
                 "arn:aws:s3:::${minio_s3_bucket.minio_backup_bucket.bucket}"
             ]
         }
     ]
 }
EOF
}

resource "minio_iam_user_policy_attachment" "minio_backup_user_policy" {
  policy_name = minio_iam_policy.minio_backup_user_policy.name
  user_name   = minio_iam_user.minio_backup_user.name
}

resource "kubernetes_secret" "velero_k8s_credentials" {
  metadata {
    name      = "velero-cfg"
    namespace = kubernetes_namespace.backup_namespace.metadata[0].name
  }

  data = {
    cloud = <<EOF
[default]
aws_access_key_id: ${minio_iam_user.minio_backup_user.name}
aws_secret_access_key: ${minio_iam_user.minio_backup_user.secret}
EOF 
  }

  type = "Opaque"
}

data "helm_repository" "vmware_tanzu" {
  name = "vmware-tanzu"
  url  = "https://vmware-tanzu.github.io/helm-charts"
}

resource "helm_release" "velero" {
  name       = "velero"
  repository = data.helm_repository.vmware_tanzu.metadata[0].name
  chart      = "velero"
  namespace  = kubernetes_namespace.backup_namespace.metadata[0].name
  values = [
    "${file("files/velero-chart-values.yml")}"
  ]

  set {
    name  = "credentials.existingSecret"
    value = kubernetes_secret.velero_k8s_credentials.metadata[0].name
  }
  set {
    name  = "configuration.backupStorageLocation.bucket"
    value = minio_s3_bucket.minio_backup_bucket.bucket
  }
}


output "test" {
  value = "${minio_iam_user.minio_backup_user.id}"
}

output "status" {
  value = "${minio_iam_user.minio_backup_user.status}"
}

output "secret" {
  value = "${minio_iam_user.minio_backup_user.secret}"
}
