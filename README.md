## KafkaChannel

### Subscription with reply:

```
k apply -f kube/kube-service-knative-event-display.yaml
k apply -f kube/kube-service-knative-appender.yaml

k apply -f kafka/kafka-channel-v1beta1-blank.yaml

k apply -f kafka/subscription----kafka-channel-v1beta1-blank---kube-service-knative-appender----kube-service-knative-event-display.yaml

k apply -f eventing/pingsource-v1-to-kafka-channel.yaml

stern -n default
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

