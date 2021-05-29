variable "prometheus_version" {
  default = "latest"
}

resource "kubernetes_namespace" "prometheus" {
  metadata {
    annotations = {
      name = "prometheus" 
    }
    labels = {
      "name" = "prometheus"
    }  
    name = "prometheus"
  }
}

resource "kubernetes_cluster_role" "prometheus" {
  metadata {
    name = "prometheus"
  }
  rule {
    api_groups = [""]
    resources = ["nodes", "services", "endpoints", "pods"]
    verbs = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["extensions"]
    resources = ["ingresses"]
    verbs = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "prometheus" {
  metadata {
    name = "prometheus"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = kubernetes_cluster_role.prometheus.metadata[0].name
  }
  subject {
    kind = "ServiceAccount"
    name = "prometheus"
    namespace = kubernetes_namespace.prometheus.metadata[0].name
  }
}

resource "kubernetes_service_account" "prometheus" {
  metadata {
    name = "prometheus"
    namespace = kubernetes_namespace.prometheus.metadata[0].name
  }
}

resource "kubernetes_config_map" "prometheus" {
  metadata {
    name = "prometheus"
    namespace = kubernetes_namespace.prometheus.metadata[0].name
  }
  data = {
    "prometheus.yml" = "${file("${path.module}/files/prometheus.yml")}"
  }
}

resource "kubernetes_deployment" "prometheus" {  
  metadata {
    name = "prometheus"
    labels = {
      app = "prometheus"
    }
    namespace = kubernetes_namespace.prometheus.metadata[0].name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "prometheus"
      }
    }
    template {
      metadata {
        labels = {
          app = "prometheus"
        }
      }
      spec {
        container {
          image = "prom/prometheus:${var.prometheus_version}"
          name = "prometheus"
          port {
            container_port = 9090
          }
          volume_mount {
            name = "config"
            mount_path = "/etc/prometheus"
            read_only = true
          }
        }
        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.prometheus.metadata[0].name
            items {
              key = "prometheus.yml"
              path = "prometheus.yml"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "prometheus" {
  metadata {
    name = "prometheus"
    namespace = kubernetes_namespace.prometheus.metadata[0].name
  }
  spec {
    selector = {
      app = kubernetes_deployment.prometheus.metadata.0.labels.app
    }
    port {
      name = "prometheus"
      protocol = "TCP"
      port = 9090
      target_port = 9090
    }
    type = "LoadBalancer"
  }
}