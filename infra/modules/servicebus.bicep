import { ResourceGroupInputs } from './_types.bicep'

param inputs ResourceGroupInputs

resource ns 'Microsoft.ServiceBus/namespaces@2024-01-01' = {
  name: 'sb-${inputs.global.baseName}-${inputs.global.environment}'
  location: inputs.global.location
  tags: inputs.tags
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {}
}

resource queue 'Microsoft.ServiceBus/namespaces/queues@2024-01-01' = {
  parent: ns
  name: 'transcription'
  properties: {
    deadLetteringOnMessageExpiration: true
    maxDeliveryCount: 10
    lockDuration: 'PT30S'
  }
}

var embeddingSub = 'memory-writer'
var digestSub = 'memory-digest'
var guardianSub = 'guardian-review'
var topicConfigs array = [
  { name: 'memory.recorded', subs: [embeddingSub, digestSub, guardianSub] }
  { name: 'memory.flagged', subs: [] }
  { name: 'alias.requested', subs: [guardianSub] }
  { name: 'alias.updated', subs: [guardianSub] }
]

resource topics 'Microsoft.ServiceBus/namespaces/topics@2024-01-01' = [
  for topic in topicConfigs: {
    parent: ns
    name: topic.name
    properties: {}
  }
]

module subs 'servicebus-subs.bicep' = [
  for topic in topicConfigs: {
    name: '${deployment().name}-${topic.name}-subs'
    params: {
      namespaceName: ns.name
      topicName: topic.name
      subNames: topic.subs
    }
    dependsOn: topics
  }
]

output namespaceName string = ns.name
output queueName string = queue.name
output topicNames array = [for t in topicConfigs: t.name]
