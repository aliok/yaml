### Sandbox test - PingSource to Kube Service

```shell
k apply -f sandbox/kube-service-knative-event-display.yaml
k apply -f sandbox/pingsource-v1-to-kube-service-knative-event-display.yaml

stern -n aliok-dev .
```

Cleanup:
```shell
k delete -f sandbox/pingsource-v1-to-kube-service-knative-event-display.yaml
k delete -f sandbox/kube-service-knative-event-display.yaml
```


### Sandbox test - KafkaBroker

There is no operator that provides Kafka on Sandbox. As written in this tutorial, you need to bring your own Kafka, such as from RHOSAK.
See https://developers.redhat.com/products/red-hat-openshift-streams-for-apache-kafka/overview

1. Get a Kafka cluster from RHOSAK: https://console.redhat.com/application-services/streams/overview
2. Create a Kafka topic named `knative-demo-topic` with 1 partition and 1 replica.
3. Create a Service Account named `knative-demo-sa` and copy `Client Id` and `Client Secret`
4. Go to "Access" tab in Kafka instance and click "Manage Access" to give permissions to the Service Account.


```shell
# create secret:
BOOTSTRAP_SERVER="xxxxxxxxxxxxxxxxxxxxxxxx.com:443"
CLIENT_ID="00000000-0000-0000-0000-000000000000"
CLIENT_SECRET="00000000000000000000000000000000"
TOPIC="knative-demo-topic"

cat <<EOF | k apply -f -
kind: Secret
apiVersion: v1
metadata:
  name: kafka-broker-secret
  namespace: aliok-dev
stringData:
  bootstrap.servers: "${BOOTSTRAP_SERVER}"
  password: "${CLIENT_SECRET}"
  protocol: SASL_SSL
  sasl.mechanism: PLAIN
  topic.name: "${TOPIC}"
  user: "${CLIENT_ID}"
type: Opaque
EOF

# create configmap
cat <<EOF | k apply -f -
kind: ConfigMap
apiVersion: v1
metadata:
  name: kafka-broker-config
  namespace: aliok-dev
data:
  auth.secret.ref.name: kafka-broker-secret
  bootstrap.servers: "${BOOTSTRAP_SERVER}"
  default.topic.partitions: '1'
  default.topic.replication.factor: '1'
  topic.name: "${TOPIC}"
EOF

# create Broker
cat <<EOF | k apply -f -
apiVersion: eventing.knative.dev/v1
kind: Broker
metadata:
  annotations:
    eventing.knative.dev/broker.class: Kafka
    kafka.eventing.knative.dev/external.topic: "${TOPIC}"
  name: default
  namespace: aliok-dev
spec:
  config:
    apiVersion: v1
    kind: ConfigMap
    name: kafka-broker-config
    namespace: aliok-dev
EOF
```

Clean up:
```shell
k delete broker default -n aliok-dev
k delete configmap kafka-broker-config -n aliok-dev
k delete secret kafka-broker-secret -n aliok-dev
```

### Sandbox test - existing broker - event flow with trigger and pingSource

```
# create everything
k apply -f sandbox/kube-service-knative-event-display.yaml
k apply -f sandbox/trigger-v1----kafka-broker----kube-service-knative-event-display.yaml

k apply -f sandbox/pingsource-v1-to-kafka-broker.yaml

stern -n aliok-dev .
```

Cleanup:
```
k delete -f sandbox/pingsource-v1-to-kafka-broker-namespaced.yaml

k delete -f sandbox/trigger-v1----kafka-broker----kube-service-knative-event-display.yaml
k delete -f sandbox/kube-service-knative-event-display.yaml
```

### Sandbox test - Knative Service

```shell
k apply -f sandbox/knative-service-prime-generator.yaml

SVC_URL=$(k get ksvc prime-generator -n aliok-dev -o jsonpath='{.status.url}')

hey -c 50 -z 10s "$SVC_URL/?sleep=3&upto=10000&memload=100"
```

Cleanup:
```shell
k delete -f sandbox/knative-service-prime-generator.yaml
```
