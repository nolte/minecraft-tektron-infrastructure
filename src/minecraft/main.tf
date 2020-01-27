resource "kubernetes_namespace" "minecraft_namespace" {
  metadata {
    name = "minecraft"
  }
}


data "helm_repository" "stable" {
  name = "stable"
  url  = "https://kubernetes-charts.storage.googleapis.com"
}

resource "helm_release" "minecraft" {
  name       = "minecraft"
  repository = data.helm_repository.stable.metadata[0].name
  chart      = "minecraft"
  namespace  = kubernetes_namespace.minecraft_namespace.metadata[0].name
  values = [
    "${file("files/minecraft-chart-values.yml")}"
  ]
}
