terraform {
  required_version = ">= 1.5.0"
  backend "local" {
    path = "/var/lib/jenkins/mini-cicd.tfstate"
  }
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

variable "image" {
  type = string
}

provider "kubernetes" {
  config_path    = pathexpand("~/.kube/config")
  config_context = "kind-mini-cicd"
}

resource "kubernetes_namespace_v1" "app" {
  metadata { name = "mini-cicd" }
}

resource "kubernetes_deployment_v1" "app" {
  metadata {
    name      = "mini-release-app"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "mini-release-app" } }
    template {
      metadata { labels = { app = "mini-release-app" } }
      spec {
        container {
          name              = "app"
          image             = var.image
          image_pull_policy = "Never"
          port { container_port = 5000 }
          readiness_probe {
            http_get {
              path = "/health"
              port = 5000
            }
            initial_delay_seconds = 2
            period_seconds        = 3
          }
          liveness_probe {
            http_get {
              path = "/health"
              port = 5000
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "app" {
  metadata {
    name      = "mini-release-app"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }
  spec {
    selector = { app = "mini-release-app" }
    port {
      port        = 80
      target_port = 5000
    }
    type = "ClusterIP"
  }
}
