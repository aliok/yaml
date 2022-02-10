## KafkaChannel

### Install things w/o auth:

```
./100_scripts/01-kn-serving.sh
./100_scripts/02-kn-eventing.sh
./100_scripts/03-strimzi.sh
./100_scripts/04-kn-kafka.sh
```

### Install things with TLS auth:

```
./100_scripts/01-kn-serving.sh
./100_scripts/02-kn-eventing.sh
./100_scripts/03-strimzi_auth.sh
./100_scripts/04-kn-kafka.sh
./100_scripts/05-kn-kafka-auth-tls.sh
```

### KafkaChannel with single subscription

```
# create everything
k apply -f kube/kube-service-knative-event-display.yaml
k apply -f kafka/kafka-channel-v1beta1-blank.yaml
k apply -f kafka/subscription----kafka-channel-v1beta1-blank----kube-service-knative-event-display.yaml

k apply -f eventing/pingsource-v1-to-kafka-channel.yaml

stern -n default .
```

Cleanup:
```
k delete -f eventing/pingsource-v1-to-kafka-channel.yaml
k delete -f kafka/subscription----kafka-channel-v1beta1-blank----kube-service-knative-event-display.yaml
k delete -f kafka/kafka-channel-v1beta1-blank.yaml
k delete -f kube/kube-service-knative-event-display.yaml
```


### Subscription with reply:

```
k apply -f kube/kube-service-knative-event-display.yaml
k apply -f kube/kube-service-knative-appender.yaml

k apply -f kafka/kafka-channel-v1beta1-blank.yaml

k apply -f kafka/subscription----kafka-channel-v1beta1-blank---kube-service-knative-appender----kube-service-knative-event-display.yaml

k apply -f eventing/pingsource-v1-to-kafka-channel.yaml

stern -n default .
# OUTPUT:

appender 2022/01/10 14:22:00 Received a new event:
appender 2022/01/10 14:22:00 [2022-01-10 14:22:00.319616431 +0000 UTC] /apis/v1/namespaces/default/pingsources/test-ping-source dev.knative.sources.ping: &{Sequence:0 Message:Hello world!}
appender 2022/01/10 14:22:00 Transform the event to:
appender 2022/01/10 14:22:00 [2022-01-10 14:22:00.319616431 +0000 UTC] /apis/v1/namespaces/default/pingsources/test-ping-source dev.knative.sources.ping: &{Sequence:0 Message:Hello world! - Handled by 0}

event-display ☁️  cloudevents.Event
event-display Context Attributes,
event-display   specversion: 1.0
event-display   type: dev.knative.sources.ping
event-display   source: /apis/v1/namespaces/default/pingsources/test-ping-source
event-display   id: d10b5a16-9779-4ef0-8ab5-94415e3587dd
event-display   time: 2022-01-10T14:22:00.319616431Z
event-display   datacontenttype: application/json
event-display Data,
event-display   {
event-display     "id": 0,
event-display     "message": "Hello world! - Handled by 0"
event-display   }
```

Cleanup:
```
k delete -f eventing/pingsource-v1-to-kafka-channel.yaml
k delete -f kafka/subscription----kafka-channel-v1beta1-blank---kube-service-knative-appender----kube-service-knative-event-display.yaml
k delete -f kafka/kafka-channel-v1beta1-blank.yaml
k delete -f kube/kube-service-knative-event-display.yaml
k delete -f kube/kube-service-knative-appender.yaml
```

### KafkaChannel with DLS:

```
k apply -f kube/kube-service-knative-event-display.yaml
k apply -f kube/kube-service-failing-sink.yaml
k apply -f kafka/kafka-channel-v1beta1-dls.yaml
k apply -f kafka/subscription----kafka-channel-v1beta1-dls----kube-service-failing-sink.yaml

k apply -f eventing/pingsource-v1-to-kafka-channel.yaml

stern -n default .
```

Cleanup:
```
k delete -f eventing/pingsource-v1-to-kafka-channel.yaml
k delete -f kafka/subscription----kafka-channel-v1beta1-dls----kube-service-failing-sink.yaml
k delete -f kube/kube-service-failing-sink.yaml
k delete -f kafka/kafka-channel-v1beta1-dls.yaml
k delete -f kube/kube-service-knative-event-display.yaml
```

Output:
```
failing-sink =======================
failing-sink Request headers:
failing-sink { 'user-agent': 'Vert.x-WebClient/4.2.3',
failing-sink   'ce-specversion': '1.0',
failing-sink   'ce-id': '26e45ed0-31b7-45c8-a749-ed207223227e',
failing-sink   'ce-source': '/apis/v1/namespaces/default/pingsources/test-ping-source',
failing-sink   'ce-type': 'dev.knative.sources.ping',
failing-sink   'content-type': 'application/json',
failing-sink   'ce-time': '2022-01-13T12:17:00.059642378Z',
failing-sink   'content-length': '27',
failing-sink   host: 'failing-sink.default.svc.cluster.local',
failing-sink   traceparent: '00-142dcf3d243b3546bd8c8709dcb1747f-2d01179ddd49609b-01' }
failing-sink
failing-sink Request body - raw:
failing-sink <Buffer 7b 22 6d 65 73 73 61 67 65 22 3a 20 22 48 65 6c 6c 6f 20 77 6f 72 6c 64 21 22 7d>
failing-sink
failing-sink Request body - to string:
failing-sink {"message": "Hello world!"}
failing-sink =======================
failing-sink
failing-sink SLEEP 0 ms
event-display ☁️  cloudevents.Event
event-display Context Attributes,
event-display   specversion: 1.0
event-display   type: dev.knative.sources.ping
event-display   source: /apis/v1/namespaces/default/pingsources/test-ping-source
event-display   id: 26e45ed0-31b7-45c8-a749-ed207223227e
event-display   time: 2022-01-13T12:17:00.059642378Z
event-display   datacontenttype: application/json
event-display Data,
event-display   {
event-display     "message": "Hello world!"
event-display   }
```

### Subscription with DLS (no DLS on channel):

```
k apply -f kube/kube-service-knative-event-display.yaml
k apply -f kube/kube-service-failing-sink.yaml
k apply -f kafka/kafka-channel-v1beta1-blank.yaml
k apply -f kafka/subscription----kafka-channel-v1beta1-blank----kube-service-failing-sink--kube-service-event-display.yaml

k apply -f eventing/pingsource-v1-to-kafka-channel.yaml

stern -n default .
```

Cleanup:
```
k delete -f eventing/pingsource-v1-to-kafka-channel.yaml
k delete -f kafka/subscription----kafka-channel-v1beta1-blank----kube-service-failing-sink--kube-service-event-display.yaml
k delete -f kube/kube-service-failing-sink.yaml
k delete -f kafka/kafka-channel-v1beta1-blank.yaml
k delete -f kube/kube-service-knative-event-display.yaml
```

### KafkaChannel with Auth - TLS

```
# create secret that is to be referenced in KafkaChannel configmap:
./kafka/kafka-channel-auth-tls.sh

# update KafkaChannel configmap
k apply -f config/kafka-channel-config-auth-tls.yaml

# create everything
k apply -f kube/kube-service-knative-event-display.yaml
k apply -f kafka/kafka-channel-v1beta1-blank.yaml
k apply -f kafka/subscription----kafka-channel-v1beta1-blank----kube-service-knative-event-display.yaml

k apply -f eventing/pingsource-v1-to-kafka-channel.yaml

stern -n default .
```

Cleanup:
```
k delete -f eventing/pingsource-v1-to-kafka-channel.yaml
k delete -f kafka/subscription----kafka-channel-v1beta1-blank----kube-service-knative-event-display.yaml
k delete -f kafka/kafka-channel-v1beta1-blank.yaml
k delete -f kube/kube-service-knative-event-display.yaml

k apply -f config/kafka-channel-config-no-auth.yaml
```

### KafkaChannel with Auth - SASL_SSL

```
# create secret that is to be referenced in KafkaChannel configmap:
./kafka/kafka-channel-auth-sasl-ssl.sh

# update KafkaChannel configmap
k apply -f config/kafka-channel-config-auth-sasl-ssl.yaml

# create everything
k apply -f kube/kube-service-knative-event-display.yaml
k apply -f kafka/kafka-channel-v1beta1-blank.yaml
k apply -f kafka/subscription----kafka-channel-v1beta1-blank----kube-service-knative-event-display.yaml

k apply -f eventing/pingsource-v1-to-kafka-channel.yaml

stern -n default .
```

Cleanup:
```
k delete -f eventing/pingsource-v1-to-kafka-channel.yaml
k delete -f kafka/subscription----kafka-channel-v1beta1-blank----kube-service-knative-event-display.yaml
k delete -f kafka/kafka-channel-v1beta1-blank.yaml
k delete -f kube/kube-service-knative-event-display.yaml

k apply -f config/kafka-channel-config-no-auth.yaml
```

### KafkaChannel with Auth - SASL_PLAIN

```
# create secret that is to be referenced in KafkaChannel configmap:
./kafka/kafka-channel-auth-sasl-plain.sh

# update KafkaChannel configmap
k apply -f config/kafka-channel-config-auth-sasl-plain.yaml

# create everything
k apply -f kube/kube-service-knative-event-display.yaml
k apply -f kafka/kafka-channel-v1beta1-blank.yaml
k apply -f kafka/subscription----kafka-channel-v1beta1-blank----kube-service-knative-event-display.yaml

k apply -f eventing/pingsource-v1-to-kafka-channel.yaml

stern -n default .
```

Cleanup:
```
k delete -f eventing/pingsource-v1-to-kafka-channel.yaml
k delete -f kafka/subscription----kafka-channel-v1beta1-blank----kube-service-knative-event-display.yaml
k delete -f kafka/kafka-channel-v1beta1-blank.yaml
k delete -f kube/kube-service-knative-event-display.yaml

k apply -f config/kafka-channel-config-no-auth.yaml
```

