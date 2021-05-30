########################################################################################################################
# Grafana
# ==========
# Configure and deploy Grafana to the k8s cluster.
#----------------------------------------------------------------------------------------------------------------------#

variable "grafana_version" {
  type    = string
  default = "latest"
}

#----------------------------------------------------------------------------------------------------------------------#
# Store the grafana configuration as a ConfigMap
resource "kubernetes_config_map" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.prometheus.metadata[0].name
  }
  data = {
    "datasource.yml" = "${file("${path.module}/files/grafana/datasource.yml")}"
    "dashboard.yml"  = "${file("${path.module}/files/grafana/dashboard.yml")}"

    "connect-overview.json"         = "${file("${path.module}/files/grafana/dashboards/kafka/connect-overview.json")}"
    "consumer.json"                 = "${file("${path.module}/files/grafana/dashboards/kafka/consumer.json")}"
    "kafka-lag-exporter.json"       = "${file("${path.module}/files/grafana/dashboards/kafka/kafka-lag-exporter.json")}"
    "kafka-overview.json"           = "${file("${path.module}/files/grafana/dashboards/kafka/kafka-overview.json")}"
    "kafka-topics.json"             = "${file("${path.module}/files/grafana/dashboards/kafka/kafka-topics.json")}"
    "ksqldb-overview.json"          = "${file("${path.module}/files/grafana/dashboards/kafka/ksqldb-overview.json")}"
    "producer.json"                 = "${file("${path.module}/files/grafana/dashboards/kafka/producer.json")}"
    "schema-registry-overview.json" = "${file("${path.module}/files/grafana/dashboards/kafka/schema-registry-overview.json")}"
    "zookeeper-overview.json"       = "${file("${path.module}/files/grafana/dashboards/kafka/zookeeper-overview.json")}"

    "kubernetes-cluster-monitoring.json" = "${file("${path.module}/files/grafana/dashboards/kubernetes/kubernetes-cluster-monitoring.json")}"
  }
}

#----------------------------------------------------------------------------------------------------------------------#
# Request a deployment of the grafana container
resource "kubernetes_deployment" "grafana" {
  depends_on = [
    kubernetes_deployment.prometheus
  ]
  metadata {
    name = "grafana"
    labels = {
      app = "grafana"
    }
    namespace = kubernetes_namespace.prometheus.metadata[0].name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "grafana"
      }
    }
    template {
      metadata {
        labels = {
          app = "grafana"
        }
      }
      spec {
        container {
          image = "grafana/grafana:${var.grafana_version}"
          name  = "grafana"
          port {
            container_port = 3000
          }
          volume_mount {
            name       = "config"
            mount_path = "/etc/grafana/provisioning/"
            read_only  = true
          }
        }
        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.grafana.metadata[0].name
            items {
              key  = "datasource.yml"
              path = "datasources/datasource.yml"
            }
            items {
              key  = "dashboard.yml"
              path = "dashboards/dashboard.yml"
            }
            items {
              key  = "connect-overview.json"
              path = "dashboards/kafka/connect-overview.json"
            }
            items {
              key  = "consumer.json"
              path = "dashboards/kafka/consumer.json"
            }
            items {
              key  = "kafka-lag-exporter.json"
              path = "dashboards/kafka/kafka-lag-exporter.json"
            }
            items {
              key  = "kafka-overview.json"
              path = "dashboards/kafka/kafka-overview.json"
            }
            items {
              key  = "kafka-topics.json"
              path = "dashboards/kafka/kafka-topics.json"
            }
            items {
              key  = "ksqldb-overview.json"
              path = "dashboards/kafka/ksqldb-overview.json"
            }
            items {
              key  = "producer.json"
              path = "dashboards/kafka/producer.json"
            }
            items {
              key  = "schema-registry-overview.json"
              path = "dashboards/kafka/schema-registry-overview.json"
            }
            items {
              key  = "zookeeper-overview.json"
              path = "dashboards/kafka/zookeeper-overview.json"
            }
            items {
              key  = "kubernetes-cluster-monitoring.json"
              path = "dashboards/kubernetes/kubernetes-cluster-monitoring.json"
            }            
          }
        }
      }
    }
  }
}

#----------------------------------------------------------------------------------------------------------------------#
# Service to expose the Grafana UI outside of the cluster
resource "kubernetes_service" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.prometheus.metadata[0].name
  }
  spec {
    selector = {
      app = kubernetes_deployment.grafana.metadata.0.labels.app
    }
    port {
      name        = "grafana"
      protocol    = "TCP"
      port        = 3000
      target_port = 3000
    }
    type = "LoadBalancer"
  }
}
