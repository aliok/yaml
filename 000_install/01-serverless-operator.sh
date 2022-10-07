#!/usr/bin/env bash

set -o pipefail
set -eu
source ./00-common.sh

# create openshift-serverless namespace
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-serverless
EOF

# create operatorGroup
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: serverless
  namespace: openshift-serverless
EOF

# create catalogSource for OpenShift Serverless midstream
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ${SERVERLESS_CATALOG_SOURCE_NAME}
  namespace: openshift-marketplace
spec:
  displayName: Serverless Operator
  image: registry.ci.openshift.org/knative/openshift-serverless-v${SERVERLESS_VERSION}:serverless-index
  publisher: Red Hat
  sourceType: grpc
EOF

header_text "Waiting for the serverless operator catalogSource to be available"
oc wait catalogsources -n openshift-marketplace ${SERVERLESS_CATALOG_SOURCE_NAME} --for=jsonpath='{.status.connectionState.lastObservedState}'="READY" --timeout=5m

# Create a subscription to use a `CatalogSource` for a midstream version:
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: serverless-operator
  namespace: openshift-serverless
spec:
  channel: stable
  name: serverless-operator
  source: ${SERVERLESS_CATALOG_SOURCE_NAME}
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
EOF

header_text "Sleeping 30 seconds"
sleep 30

header_text "Waiting for the serverless operator deployments to be available"
# wait until operator deployments are ready
kubectl wait --for=condition=available --timeout=5m deployment/knative-operator          -n openshift-serverless
kubectl wait --for=condition=available --timeout=5m deployment/knative-openshift         -n openshift-serverless
kubectl wait --for=condition=available --timeout=5m deployment/knative-openshift-ingress -n openshift-serverless

# check pods for rollouts
wait_until_pods_running "openshift-serverless"
