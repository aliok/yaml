## Install KServe and Knative Eventing upstream
```shell
# Install KServe
curl -s "https://raw.githubusercontent.com/kserve/kserve/release-0.10/hack/quick_install.sh" | bash

# Install Knative Eventing, IMC and MTChannelBroker:
kubectl apply -f https://github.com/knative/eventing/releases/download/knative-v1.9.7/eventing-crds.yaml
kubectl apply -f https://github.com/knative/eventing/releases/download/knative-v1.9.7/eventing-core.yaml
kubectl apply -f https://github.com/knative/eventing/releases/download/knative-v1.9.7/in-memory-channel.yaml
kubectl apply -f https://github.com/knative/eventing/releases/download/knative-v1.9.7/mt-channel-broker.yaml
```

## Port forwarding setup
```shell
INGRESS_GATEWAY_SERVICE=$(kubectl get svc --namespace istio-system --selector="app=istio-ingressgateway" --output jsonpath='{.items[0].metadata.name}')
kubectl port-forward --namespace istio-system svc/${INGRESS_GATEWAY_SERVICE} 8080:80
```

## Inference logging

```shell

# Setup some variables
export INGRESS_HOST=localhost
export INGRESS_PORT=8080

# Create message dumper
k apply -f data-science/ksvc-message-dumper.yaml
# Create MTChannelBroker with IMC
k apply -f data-science/mt-channel-broker-with-imc.yaml
# Create trigger
k apply -f data-science/trigger-to-ksvc-message-dumper.yaml
# Create inference service
k apply -f data-science/inference-service-with-logging-to-default-broker.yaml
```

```shell
# Start watching the logs of the message dumper
stern message-dumper
```

```shell
# Submit an inference request
MODEL_NAME=sklearn-iris
# INPUT_PATH=@./iris-input.json
INPUT="{\"instances\": [[6.8,  2.8,  4.8,  1.4],[6.0,  3.4,  4.5,  1.6]]}"
SERVICE_HOSTNAME=$(kubectl get inferenceservice sklearn-iris -o jsonpath='{.status.url}' | cut -d "/" -f 3)
curl -v -H "Host: ${SERVICE_HOSTNAME}" "http://${INGRESS_HOST}:${INGRESS_PORT}/v1/models/$MODEL_NAME:predict" -d $INPUT
```

```shell
The output of message dumper should be:

☁️  cloudevents.Event
Validation: valid
Context Attributes,
  specversion: 1.0
  type: org.kubeflow.serving.inference.response
  source: http://localhost:9081/
  id: 689b15e7-84a1-4e89-9805-20809efc216d
  time: 2023-04-05T07:39:53.505997782Z
  datacontenttype: application/json
Extensions,
  component: predictor
  endpoint:
  inferenceservicename: sklearn-iris
  knativearrivaltime: 2023-04-05T07:39:53.507202247Z
  namespace: default
  traceparent: 00-7cebb2ae49d33626845711ad585c850c-78b57bf5baf7151f-00
Data,
  {
    "predictions": [
      1,
      1
    ]
  }


☁️  cloudevents.Event
Validation: valid
Context Attributes,
  specversion: 1.0
  type: org.kubeflow.serving.inference.request
  source: http://localhost:9081/
  id: 689b15e7-84a1-4e89-9805-20809efc216d
  time: 2023-04-05T07:39:53.501752983Z
  datacontenttype: application/x-www-form-urlencoded
Extensions,
  component: predictor
  endpoint:
  inferenceservicename: sklearn-iris
  knativearrivaltime: 2023-04-05T07:39:53.504099918Z
  namespace: default
  traceparent: 00-25ba82c3ab23869bad83fd1b9c92da4a-b2f41360fa5eeebb-00
Data,
  {"instances": [[6.8,  2.8,  4.8,  1.4],[6.0,  3.4,  4.5,  1.6]]}
```

## Drift detection
See https://github.com/kserve/kserve/blob/master/docs/samples/drift-detection/alibi-detect/cifar10/cifar10_drift.ipynb

Create namespace, broker, trigger, etc:
```shell
kubectl create namespace cifar10

cat <<EOF | k apply -f -
apiVersion: eventing.knative.dev/v1
kind: broker
metadata:
 name: default
 namespace: cifar10
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-display
  namespace: cifar10
spec:
  replicas: 1
  selector:
    matchLabels: &labels
      app: hello-display
  template:
    metadata:
      labels: *labels
    spec:
      containers:
        - name: event-display
          image: gcr.io/knative-releases/knative.dev/eventing-contrib/cmd/event_display
---
kind: Service
apiVersion: v1
metadata:
  name: hello-display
  namespace: cifar10
spec:
  selector:
    app: hello-display
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
EOF
```

Create Inference service
```shell
cat <<EOF | k apply -f -
apiVersion: "serving.kserve.io/v1beta1"
kind: "InferenceService"
metadata:
  name: "tfserving-cifar10"
  namespace: cifar10
spec:
  predictor:
    tensorflow:
      storageUri: "gs://seldon-models/tfserving/cifar10/resnet32"
    logger:
      mode: all
      url: http://broker-ingress.knative-eventing.svc.cluster.local/cifar10/default
EOF
```

Create drift detector service:
```shell
cat <<EOF | k apply -f -
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: drift-detector
  namespace: cifar10
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/minScale: "1"
    spec:
      containers:
      - image: seldonio/alibi-detect-server:0.0.2
        imagePullPolicy: IfNotPresent
        args:
        - --model_name
        - cifar10cd
        - --http_port
        - '8080'
        - --protocol
        - tensorflow.http
        - --storage_uri
        - gs://seldon-models/alibi-detect/cd/ks/cifar10
        - --reply_url
        - http://hello-display.cifar10
        - --event_type
        - org.kubeflow.serving.inference.outlier
        - --event_source
        - org.kubeflow.serving.cifar10cd
        - DriftDetector
        - --drift_batch_size
        - '5000'
EOF
```

Create drift detector service:
```shell
cat <<EOF | k apply -f -
apiVersion: eventing.knative.dev/v1
kind: Trigger
metadata:
  name: drift-trigger
  namespace: cifar10
spec:
  broker: default
  filter:
    attributes:
      type: org.kubeflow.serving.inference.request
  subscriber:
    ref:
      apiVersion: serving.knative.dev/v1
      kind: Service
      name: drift-detector
      namespace: cifar10
EOF
```

Now, do the port forwarding, as written above.

Install Python dependencies:
```shell
python3 -m venv data-science/drift-detection
source data-science/drift-detection/bin/activate
# https://github.com/SeldonIO/alibi-detect/issues/375 and 387
python3 -m pip install "alibi-detect>=0.4.0" "matplotlib>=3.1.1" "tqdm>=4.45.0" "notebook" "httplib2>=0.20.2" "tensorflow>=2.2.0, !=2.6.0, !=2.6.1, <2.13.0" "ipywidgets" 
```

```shell
# start jupyter notebook
jupyter notebook data-science/cifar10_drift.ipynb
# jupyter notebook data-science/cifar10_drift.ipynb --no-browser --NotebookApp.token='' --NotebookApp.password=''
```


## Drift Detection on OpenShift

Go and do the things from the https://github.com/ReToCode/knative-kserve:
- Installation with Istio + Mesh
- Prerequisites of Testing KServe installation
- Prerequisites of Testing KServe with Knative Eventing

Then install Python dependencies:
```shell
python3 -m venv data-science/drift-detection
source data-science/drift-detection/bin/activate
# https://github.com/SeldonIO/alibi-detect/issues/375 and 387
python3 -m pip install "alibi-detect>=0.4.0" "matplotlib>=3.1.1" "tqdm>=4.45.0" "notebook" "httplib2>=0.20.2" "tensorflow>=2.2.0, !=2.6.0, !=2.6.1, <2.13.0" "ipywidgets" 
```

```shell
# start jupyter notebook
jupyter notebook data-science/cifar10_drift_openshift.ipynb
# jupyter notebook data-science/cifar10_drift_openshift.ipynb --no-browser --NotebookApp.token='' --NotebookApp.password=''
```

Rest is on the notebook.

## End to end inference service example with Minio and Kafka - upstream

Install KServe
```shell
curl -s "https://raw.githubusercontent.com/kserve/kserve/release-0.10/hack/quick_install.sh" | bash
```

Install Strimzi, Knative Serving, Eventing and Knative Kafka components:
```shell
# ./100_scripts/01-kn-serving.sh # serving comes within KServe above
./100_scripts/02-kn-eventing.sh
./100_scripts/03-strimzi.sh
./100_scripts/04-kn-kafka-broker.sh
```

Install InferenceService addressable cluster role for Knative Kafka control plane, so that KafkaSource can resolve
the address of an InferenceService:
```shell
cat <<EOF | k apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: inferenceservice-addressable-resolver
  labels:
    contrib.eventing.knative.dev/release: devel
    duck.knative.dev/addressable: "true"
# Do not use this role directly. These rules will be added to the "addressable-resolver" role.
rules:
  - apiGroups:
      - serving.kserve.io
    resources:
      - inferenceservices
      - inferenceservices/status
    verbs:
      - get
      - list
      - watch
EOF
````

Install Minio
```shell
cat <<EOF | k apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: minio
  name: minio
spec:
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: minio
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
        - args:
            - server
            - /data
          env:
            - name: MINIO_ACCESS_KEY
              value: minio
            - name: MINIO_SECRET_KEY
              value: minio123
          image: minio/minio:RELEASE.2020-10-18T21-54-12Z
          imagePullPolicy: IfNotPresent
          name: minio
          ports:
            - containerPort: 9000
              protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: minio
  name: minio-service
spec:
  ports:
    - port: 9000
      protocol: TCP
      targetPort: 9000
  selector:
    app: minio
  type: ClusterIP
EOF
```

Install Minio client
```shell
brew install minio/stable/mc
```

Run port forwarding command in a different terminal
```shell
kubectl port-forward $(kubectl get pod --selector="app=minio" --output jsonpath='{.items[0].metadata.name}') 9000:9000
mc config host add myminio http://127.0.0.1:9000 minio minio123
```

Create buckets mnist for uploading images and digit-[0-9] for classification.
```shell
mc mb myminio/mnist
mc mb myminio/digit-0
mc mb myminio/digit-1
mc mb myminio/digit-2
mc mb myminio/digit-3
mc mb myminio/digit-4
mc mb myminio/digit-5
mc mb myminio/digit-6
mc mb myminio/digit-7
mc mb myminio/digit-8
mc mb myminio/digit-9
```

Setup event notification to publish events to kafka.


Setup bucket event notification with kafka
```shell
mc admin config set myminio notify_kafka:1 tls_skip_verify="off"  queue_dir="" queue_limit="0" sasl="off" sasl_password="" sasl_username="" tls_client_auth="0" tls="off" client_tls_cert="" client_tls_key="" brokers="my-cluster-kafka-bootstrap.kafka:9092" topic="mnist" version=""
# Restart minio
# Note: this kills port forwarding done above, so, you need to run it again
mc admin service restart myminio
# Setup event notification when putting images to the bucket
mc event add myminio/mnist arn:minio:sqs::1:kafka -p --event put --suffix .png
```

Upload the mnist model to Minio¶
```shell
mkdir -p /tmp/mnist_model
gsutil cp -r gs://kfserving-examples/models/tensorflow/mnist /tmp/mnist_model
mc cp -r /tmp/mnist_model/mnist myminio/
```

Create S3 Secret for Minio and attach to Service Account¶
```shell
cat <<EOF | k apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
  annotations:
    serving.kserve.io/s3-endpoint: minio-service:9000 # replace with your s3 endpoint
    serving.kserve.io/s3-usehttps: "0" # by default 1, for testing with minio you need to set to 0
type: Opaque
data:
  AWS_ACCESS_KEY_ID: bWluaW8=
  AWS_SECRET_ACCESS_KEY: bWluaW8xMjM=
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
secrets:
  - name: mysecret
EOF
```

Create the InferenceService
```shell
cat <<EOF | k apply -f -
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: mnist
spec:
  predictor:
    minReplicas: 1
    model:
      modelFormat:
        name: tensorflow
      resources:
        limits:
          cpu: 100m
          memory: 1Gi
        requests:
          cpu: 100m
          memory: 1Gi
      runtimeVersion: 1.14.0
      storageUri: s3://mnist
  transformer:
    minReplicas: 1
    containers:
      - image: aliok/mnist-transformer:latest
        name: kserve-container
        resources:
          limits:
            cpu: 100m
            memory: 1Gi
          requests:
            cpu: 100m
            memory: 1Gi
EOF
```

Watch inference service pods:
```shell
kubectl get pods -l serving.kserve.io/inferenceservice=mnist
```

Create KafkaSource:
```shell
cat <<EOF | k apply -f -
apiVersion: sources.knative.dev/v1beta1
kind: KafkaSource
metadata:
  name: kafka-source
spec:
  consumerGroup: knative-group
  bootstrapServers:
    - my-cluster-kafka-bootstrap.kafka:9092
  topics:
    - mnist
  sink:
    ref:
      apiVersion: serving.kserve.io/v1beta1
      kind: InferenceService
      name: mnist
    uri: /v1/models/mnist:predict
EOF
```

Upload a digit image to Minio mnist bucket
```shell
mc cp test_0.png myminio/mnist
```
