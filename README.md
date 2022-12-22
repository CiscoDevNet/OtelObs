## Auto Instrument cloud native applications and fan out OpenTelemetry Trace data to multiple observability backends 

### Contents
        Use Cases
        Pre-requisites, Guidelines
        Deploy Teastore Multi service application
        Auto Instrumentation of TeaStore Application
        Deploy AppDynamics Kubernetes and App Service Monitoring in EKS and AKS
        Deploy Jaeger Observability Backend
        Deploy Zipkin Observability Backend
        Leveraging Terraform to enable APM for K8s Clusters
        AppD Collector Updates - Fanout to Multiple Observability Backends
        Observe Traces in Jaeger and Zipkin
        Observe FSO in AppDynamics Cloud
        De-provisioning

### Use Cases

        * As a Cloud Admin, deploy OpenTelemetry and AppDynamics collectors to collect Metrics, 
        Logs and Traces from AKS and EKS clusters and auto instrumented cloud native services 

        * As a Cloud Admin, provide ability to fan out to one or more observability backends 
        such as AppDynamics Cloud, Jaeger and Zipkin for APM (Application Performance Monitoring)

        * As DevOps, Observe Traces with Jaeger/Zipkin/AppD Cloud and FSO with AppDynamics Cloud

        * As DevOps, Observe Infrastructure Correlation in AppDynamics Cloud

The various subsystems involved are depicted in the following diagram:
        
![alt text](https://github.com/prathjan/images/blob/main/obsplat.png?raw=true)

### Pre-requisites, Guidelines
1. You have set up Cloud Connections to AWS, Azure or both. Please refer to the following for setting up these cloud connections. You will need data collected from cloud infrastructure services for full stack observability in AppD Cloud:
https://developer.cisco.com/codeexchange/github/repo/CiscoDevNet/appdcloudconn

2. Requires access to a AWS EKS and Azure AKS cluster.

3. Requires access to Terraform

4. AppDynamics Cloud requirements (details in reference below):

        * Your account is set up on AppDynamics Cloud. See Account Administration.

        * You are connected to the EKS/AKS cluster that you want to monitor.

        * You have administrator privileges on the monitored cluster to run the Helm chart commands.


### Deploy Teastore Multi service application

This is a use case demonstrating auto instrumentation of cloud native applications that are already deployed and operational. Let's first do a helm deployment of the application:

        helm install teaapp https://prathjan.github.io/helm-chart/teastore-0.1.0.tgz

Check the loadbalancer IP:

        kubectl get svc

![alt text](https://github.com/prathjan/images/blob/main/kubesvc.png?raw=true)


Access the application at : http://<LB_IP>/tools.descartes.teastore.webui/

### Auto Instrumentation of TeaStore Application

AppDynamics Operators auto-instrumentation of the workloads using OpenTelemetry instrumentation libraries in addition to managing the AppDynamics OpenTelemetry Collector that will be deployed in the next step. Let's do a helm deployment of the AppDynamics Operator:

        helm repo add appdynamics-cloud-helmcharts https://appdynamics.jfrog.io/artifactory/appdynamics-cloud-helmcharts/ 

        helm install appdynamics-operators appdynamics-cloud-helmcharts/appdynamics-operators -n appdynamics --wait

### Deploy AppDynamics Kubernetes and App Service Monitoring in EKS and AKS

OpenTelemetry Operator for Kubernetes manages the lifecycle of the following collectors:

        * AppDynamics Collectors - Collector offers a vendor-agnostic implementation on how to receive, process and export telemetry data

        * Cluster Collector — to collect Kubernetes data.

        * Infrastructure Collector — to collect the server and container data, known as Host Monitoring.

        * Log Collector — to collect the logs.

Let's do a helm deployment of the OpenTelemetry Operator for Kubernetes. To download the collectors.yaml file, please provide the details here: https://cisco-devnet.observe.appdynamics.com/ui/configure/kubernetes-and-apm

        helm install appdynamics-collectors appdynamics-cloud-helmcharts/appdynamics-collectors -n appdynamics -f collectors-values.yaml        


### Deploy Jaeger Observability Backend

To demonstrate the fan out capabilities of AppDynamics OpenTelemetry Collector, lets deploy a couple observability backends. Let's deploy Jaeger Tracing Tool:

        helm repo add jaeger-all-in-one https://raw.githubusercontent.com/hansehe/jaeger-all-in-one/master/helm/charts

        helm install jaeger-all-in-one jaeger-all-in-one/jaeger-all-in-one

Do a port-forward:

        kubectl port-forward deployment/jaeger 16686:16686

View Jaeger UI:

![alt text](https://github.com/prathjan/images/blob/main/jaeger.png?raw=true)

### Deploy Zipkin Observability Backend

To demonstrate the fan out capabilities of AppDynamics OpenTelemetry Collector, lets deploy a couple observability backends. Let's deploy Zipkin Tracing Tool:

        helm repo add openzipkin https://openzipkin.github.io/zipkin

        helm install openzipkin openzipkin/zipkin

Do a port-forward:

        kubectl port-forward <openzipkin-pod> 9411:9411

View Zipkin UI:

![alt text](https://github.com/prathjan/images/blob/main/zipkin.png?raw=true)

### Leveraging Terraform to enable APM for K8s Clusters

In here, let's automate all of the above deployments in a single terraform script. Let's first delete all the helm deployments we did manually above and repeat the same with a terraform script. 

        helm delete teaapp

        helm delete jaeger-all-in-one

        helm delete openzipkin

        helm delete appdynamics-operators -n appdynamics

        helm delete appdynamics-collectors -n appdynamics

Git clone from this location: https://github.com/CiscoDevNet/OtelObs

Before running the terraform script (main.tf) , add the following variables to terraform.auto.tfvars.

1. For the EKS/AKS cluster that you are connected to, get the cluster configuration and add the following variables to terraform.auto.tfvars. 

        kubectl config view --minify --flatten --context=name-of-your-cluster

        From the above data, fill in the following in the tfvars file:

                host = <xxxxxxx>

                client_certificate = <xxxxxxxxxx>

                client_key = <xxxxxxxxxx>

                cluster_ca_certificate = <xxxxxxxxx>

2. Provide your EKS/AKS cluster name and retrieve the collectors-values.yaml file generated. The link to do this is here: https://cisco-devnet.observe.appdynamics.com/ui/configure/kubernetes-and-apm


Run the terraform script: 

        terraform apply

This should deploy all of the components we manually deployed in prior steps.

### AppD Collector Updates - Fanout to Multiple Observability Backends

Let's configure the OpenTelemetry collector to send traces to Jaeger and Zipkin in addition to AppDynamics Cloud.

Add the following to collectors-values.yaml file to configure the OpenTelemetry Exporters to Jaeger and Zipkin:

        jaeger:

           endpoint: "jaeger-all-in-one.default.svc.cluster.local:14250"

           tls:

             insecure: true

        zipkin:

          endpoint: "http://openzipkin.default.svc.cluster.local:9411/api/v2/spans"

          format: proto

Add the following  to configure the OpenTelemetry pipelines:

        service:

          pipelines:

            traces:

              exporters:

              - jaeger

              - zipkin  

Run the terraform script to update the collector configuration: 

        terraform apply

This should update the OpenTelemetry exporters in the OpenTelemetry Collector to export the application traces to AppD Cloud, Jaeger and Zipkin. Review the UI of each to ensure that the traces for the Teastore application are being collected.

### Observe Traces in Jaeger and Zipkin

Once autoinstrumented and configured for fanout, the Teastore cloud native application traces are now available in both Jaeger and Zipkin:

![alt text](https://github.com/prathjan/images/blob/main/jaegersvc.png?raw=true)

![alt text](https://github.com/prathjan/images/blob/main/zipkinsvc.png?raw=true)

### Observe FSO in AppDynamics Cloud

While only Traces are available in Jaeger and Zipkin, Full Stack Observability for Teastore application services are available in AppDynanics Cloud. Log into AppDynanics Cloud and view FSO data for each of the cloud native services deployed in EKS and AKS. An example snapshot looks as follows:

![alt text](https://github.com/prathjan/images/blob/main/appdsvc.png?raw=true)

### De-provisioning

* terraform destroy 

### References

https://docs.appdynamics.com/appd-cloud/en/kubernetes-and-app-service-monitoring/install-kubernetes-and-app-service-monitoring

