#!/usr/bin/env bash

set -o pipefail
set -eu
source ./00-common.sh

header_text "Creating Jaeger operator subscription"
# use oc get PackageManifest jaeger-product -n openshift-marketplace -o yaml
  cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: jaeger-product
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Automatic
  name: jaeger-product
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  startingCSV: jaeger-operator.v${VERSION_JAEGER}
EOF

sleep 20

header_text "Waiting for Jaeger operator to be available"
kubectl wait ClusterServiceVersion --timeout=5m -n openshift-operators "jaeger-operator.v${VERSION_JAEGER}" --for=jsonpath='{.status.phase}'="Succeeded"

header_text "Wait for the Jaeger CRD we need to actually be active"
kubectl wait crd --timeout=5m jaegers.jaegertracing.io --for=condition=Established

header_text "Creating Jaeger installation"
# create tracing installation namespace
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: ${TRACING_NAMESPACE}
EOF

cat <<EOF | oc apply -f -
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: jaeger
  namespace: ${TRACING_NAMESPACE}
spec:
  strategy: allInOne
EOF

header_text "Waiting for Jaeger to be available"
kubectl wait jaeger.jaegertracing.io jaeger --timeout=5m -n "${TRACING_NAMESPACE}" --for=jsonpath='{.status.phase}'="Running"

header_text "Install Distributed Tracing Data Collection Operator"

header_text "Creating Jaeger operator subscription"
# use oc get PackageManifest opentelemetry-product -n openshift-marketplace -o yaml
  cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: opentelemetry-product
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Automatic
  name: opentelemetry-product
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  startingCSV: opentelemetry-operator.v${VERSION_OTEL}
EOF

sleep 20

header_text "Waiting for Jaeger operator to be available"
kubectl wait ClusterServiceVersion --timeout=5m -n openshift-operators "opentelemetry-operator.v${VERSION_OTEL}" --for=jsonpath='{.status.phase}'="Succeeded"

header_text "Wait for the OpenTelemetry CRD we need to actually be active"
kubectl wait crd --timeout=5m opentelemetrycollectors.opentelemetry.io --for=condition=Established

header_text "Creating OpenTelemetry Collector installation"

cat <<EOF | kubectl apply -f -
apiVersion: opentelemetry.io/v1alpha1
kind: OpenTelemetryCollector
metadata:
  name: cluster-collector
  namespace: ${TRACING_NAMESPACE}
spec:
  mode: deployment
  config: |
    receivers:
      zipkin:
    processors:
    exporters:
      jaeger:
        endpoint: jaeger-collector-headless.${TRACING_NAMESPACE}.svc:14250
        tls:
          ca_file: "/var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt"
      logging:
    service:
      pipelines:
        traces:
          receivers: [zipkin]
          processors: []
          exporters: [jaeger, logging]
EOF

header_text "Waiting for OpenTelemetry Collector to be available"
oc wait --for=condition=Available deployment cluster-collector-collector --timeout=300s -n "${TRACING_NAMESPACE}"

header_text "Enabling tracing for KnativeEventing and KnativeKafka"
function enable_tracing {
  crd=${1:?Pass a custom resource to be patched as arg[1]}
  name=${2:?Pass a custom resource to be patched as arg[2]}

  cat <<EOF > /tmp/knative-tracing-patch.yaml
spec:
 config:
   tracing:
     backend: zipkin
     debug: "true"
     enable: "true"
     sample-rate: "1.0"
     zipkin-endpoint: "http://cluster-collector-collector-headless.${TRACING_NAMESPACE}.svc:9411/api/v2/spans"
EOF

  kubectl patch ${crd} -n knative-eventing ${name} --type merge --patch-file=/tmp/knative-tracing-patch.yaml
}

enable_tracing "knativeeventing" "knative-eventing"
enable_tracing "knativekafka" "knative-kafka"

header_text "Jaeger UI is available at https://$(kubectl get routes -n knative-tracing jaeger -o jsonpath="{.status.ingress[].host}")"
