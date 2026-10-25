param namespaceName string
param topicName string
param subNames array

resource ns 'Microsoft.ServiceBus/namespaces@2024-01-01' existing = {
  name: namespaceName
}

resource topic 'Microsoft.ServiceBus/namespaces/topics@2024-01-01' existing = {
  parent: ns
  name: topicName
}

resource sub 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2024-01-01' = [
  for subName in subNames: {
    parent: topic
    name: subName
    properties: {
      deadLetteringOnMessageExpiration: true
      maxDeliveryCount: 10
      lockDuration: 'PT30S'
    }
  }
]
