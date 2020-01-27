resource "kubernetes_namespace" "git_namespace" {
  metadata {
    name = "gitea"
  }
}

data "helm_repository" "jfelten" {
  name = "jfelten"
  url  = "http://localhost:8080"
}

resource "helm_release" "velero" {
  name       = "gitea"
  repository = data.helm_repository.jfelten.metadata[0].name
  chart      = "gitea"
  namespace  = kubernetes_namespace.git_namespace.metadata[0].name
  values = [
    "${file("files/gitea-chart-values.yml")}"
  ]
}

