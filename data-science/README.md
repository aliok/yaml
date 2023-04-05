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
