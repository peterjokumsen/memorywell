// Least-privilege Service Bus receive rights for the Function App identity: one
// grant on the transcription queue and one per topic subscription the app
// triggers on.
//
// The scopes are built from explicit topic/subscription pairs on purpose. ARM
// accepts a role assignment on any scope string, including one that names a
// resource that does not exist, so a typo here deploys "successfully" and then
// fails with 401 at runtime. Keeping the names as separate fields makes that
// mistake harder to write.
param identityPrincipalId string
param namespaceName string
param queueName string
param topicSubscriptions { topic: string, sub: string }[]

resource queue 'Microsoft.ServiceBus/namespaces/queues@2024-01-01' existing = {
  name: '${namespaceName}/${queueName}'
}

var serviceBusReceiverRoleId = '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'
var roleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', serviceBusReceiverRoleId)

resource queueReceiver 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: queue
  name: guid(queue.id, identityPrincipalId, serviceBusReceiverRoleId)
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: identityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource subscriptions 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2024-01-01' existing = [
  for entry in topicSubscriptions: {
    name: '${namespaceName}/${entry.topic}/${entry.sub}'
  }
]

resource subReceivers 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for i in range(0, length(topicSubscriptions)): {
    scope: subscriptions[i]
    name: guid(subscriptions[i].id, identityPrincipalId, serviceBusReceiverRoleId)
    properties: {
      roleDefinitionId: roleDefinitionId
      principalId: identityPrincipalId
      principalType: 'ServicePrincipal'
    }
  }
]
