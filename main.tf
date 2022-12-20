terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubectl = {
      source = "gavinbunney/kubectl"
      version = "1.14.0"
    }
  }
}

data "template_file" "your_template" {
  template = "${file("${path.module}/instrumentation.yaml")}"
}

provider "kubectl" {
    host = var.host
    client_certificate     = base64decode(var.client_certificate)
    client_key             = base64decode(var.client_key)
    cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
}

provider "kubernetes" {
    host = var.host
    client_certificate     = base64decode(var.client_certificate)
    client_key             = base64decode(var.client_key)
    cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
}

variable "host" {
  type = string
}

variable "client_certificate" {
  type = string
}

variable "client_key" {
  type = string
}

variable "cluster_ca_certificate" {
  type = string
}

resource "kubernetes_namespace" "appd" {
  metadata {
    name = "appdynamics"
  }
}

resource "kubernetes_annotations" "defns" {
  api_version = "v1"
  kind = "Namespace"
  metadata {
    name = "default"
  }
  annotations = {
    "instrumentation.opentelemetry.io/inject-java": "true" 
  }
}


resource helm_release teaiksfrtfcb {
  name       = "teaiksapp"
  namespace = "default"
  chart = "https://prathjan.github.io/helm-chart/teastore-0.1.0.tgz"
}

resource helm_release appdoperator {
  name       = "appdynamics-operators"
  namespace = "appdynamics"
  chart = "appdynamics-operators"
  repository = "https://appdynamics.jfrog.io/artifactory/appdynamics-cloud-helmcharts"
  timeout = 600
}

resource "null_resource" "instrumentapps" {
  depends_on  = [kubectl_manifest.crds_apply]
   provisioner "local-exec" {
    command = <<EOT
      kubectl delete pod $(kubectl get pods | grep teaiksapp | cut -d ' ' -f 1) 
  EOT
  }
}

data "kubectl_file_documents" "crds" {
  content = file("${path.module}/instrumentation.yaml")
}

resource "kubectl_manifest" "crds_apply" {
  depends_on  = [helm_release.appdoperator]
  for_each  = data.kubectl_file_documents.crds.manifests
  yaml_body = each.value
  wait = true
  server_side_apply = true
}


resource helm_release appdcollector {
  name       = "appdynamics-collectors"
  namespace = "appdynamics"
  chart = "appdynamics-collectors"
  repository = "https://appdynamics.jfrog.io/artifactory/appdynamics-cloud-helmcharts"
  timeout = 600
  values = [
    file("${path.module}/collectors-values.yaml")
  ]
}

resource helm_release jaeger {
  name       = "jaeger-all-in-one"
  namespace = "default"
  chart = "jaeger-all-in-one"
  repository = "https://raw.githubusercontent.com/hansehe/jaeger-all-in-one/master/helm/charts"
  timeout = 600
}

resource helm_release zipkin {
  name       = "openzipkin"
  namespace = "default"
  chart = "zipkin"
  repository = "https://openzipkin.github.io/zipkin"
  timeout = 600
}

provider "helm" {
  kubernetes {
    host = var.host
    client_certificate     = base64decode(var.client_certificate)
    client_key             = base64decode(var.client_key)
    cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  }
}


