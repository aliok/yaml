```
                                           ┌────────┐
┌───────────────────────────────────────┐  │        │
│                                       │  │        │
│ payment-event-generator-source        │  │        │
│                                       │  │        │
└───────────┬───────────────────────────┤  │        │
            └───────────────────────────┴──►        │
          com.mycompany.paymentreceived    │        │
                                           │        │
                                           │        │
          com.mycompany.paymentreceived    │        │
                   ┌───────────────────────┤        │
                   │                       │ Broker │
       ┌───────────▼───────────┐           │        │
       │                       │           │        │
       │    payment-processor  │           │        │
       │                       │           │        │
       └───────────┬───────────┘           │        │
                   │                       │        │
                   └───────────────────────►        │
          com.mycompany.paymentprocessed   │        │
                                           │        │
          com.mycompany.paymentprocessed   │        │
                    ┌──────────────────────┤        │
                    │                      │        │
        ┌───────────▼──────────┐           │        │
        │                      │           │        │
        │   fraud-detector     │           │        │
        │                      │           │        │
        └───────────┬──────────┘           │        │
                    │                      │        │
                    └──────────────────────►        │
          com.mycompany.frauddetected      │        │
                                           │        │
          com.mycompany.frauddetected      │        │
                    ┌──────────────────────┤        │
                    │                      │        │
         ┌──────────▼───────────┐          │        │
         │                      │          │        │
         │   fraud-logger       │          │        │
         │                      │          │        │
         └──────────────────────┘          └────────┘
```

Notes:
- [300-manual-event-type.yaml](300-manual-event-type.yaml) creates an EventType manually for 
  `com.mycompany.paymentprocessed` event for seting how the auto-generated ETs behave with the manually created ETs of the same type
