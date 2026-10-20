import { ResourceGroupInputs } from './_types.bicep'

param inputs ResourceGroupInputs

// =====================================================================
// Event Grid custom domain for app-level events
// =====================================================================
resource domain 'Microsoft.EventGrid/domains@2025-02-15' = {
  name: 'evg-${inputs.global.baseName}-${inputs.global.environment}'
  location: inputs.global.location
  tags: inputs.tags
  properties: {
    autoCreateTopicWithFirstSubscription: false
    autoDeleteTopicWithLastSubscription: false
    inboundIpRules: [
      {
        ipMask: '0.0.0.0/0'
        action: 'Allow'
      }
    ]
    publicNetworkAccess: 'Enabled'
  }
}

// =====================================================================
// Parameters for handler endpoints (populated from Function App outputs or App Config)
// =====================================================================
param functionEndpoints object = {
  timerCadence: '' // HTTP trigger for checkin.due
  voiceReceived: '' // HTTP trigger for voice.received
  memoryRecordedBridge: '' // Bridge to SB topic 'memory.recorded'
  memoryFlaggedReview: '' // Owner review queue Function
  aliasRequestedBridge: '' // Bridge to SB topic 'alias.requested'
  aliasUpdatedBridge: '' // Bridge to SB topic 'alias.updated'
}

param serviceBusTopics object = {
  memoryRecorded: 'memory.recorded'
  memoryFlagged: 'memory.flagged'
  aliasRequested: 'alias.requested'
  aliasUpdated: 'alias.updated'
}

// Dead-letter storage (expect platform.bicep to output these)
param deadLetterStorage object = {
  storageAccountId: ''
  containerName: 'eventgrid-dlq'
}

var defaultRetryPolicy = {
  maxDeliveryAttempts: 30
  eventTimeToLiveInMinutes: 1440 // 24h
  retryPolicyType: 'ExponentialBackoff'
  minRetryIntervalInMinutes: 5
  maxRetryIntervalInMinutes: 60
}

// =====================================================================
// Event subscriptions (one per event type, with filters + DLQ)
// =====================================================================

// checkin.due -> Prompter (direct)
resource subCheckinDue 'Microsoft.EventGrid/domains/eventSubscriptions@2025-02-15' = if (!empty(functionEndpoints.timerCadence)) {
  parent: domain
  name: 'sub-checkin-due-prompter'
  properties: {
    destination: { endpointType: 'WebHook', properties: { endpointUrl: functionEndpoints.timerCadence } }
    filter: {
      includedEventTypes: ['checkin.due']
      subjectBeginsWith: ''
      subjectEndsWith: ''
      isSubjectCaseSensitive: false
    }
    retryPolicy: defaultRetryPolicy
    deadLetterDestination: !empty(deadLetterStorage.storageAccountId)
      ? {
          endpointType: 'StorageBlob'
          properties: {
            resourceId: deadLetterStorage.storageAccountId
            blobContainerName: deadLetterStorage.containerName
          }
        }
      : {}
    eventDeliverySchema: 'EventGridSchema'
  }
}

// voice.received -> transcription queue (direct)
resource subVoiceReceived 'Microsoft.EventGrid/domains/eventSubscriptions@2025-02-15' = if (!empty(functionEndpoints.voiceReceived)) {
  parent: domain
  name: 'sub-voice-received-transcription'
  properties: {
    destination: { endpointType: 'WebHook', properties: { endpointUrl: functionEndpoints.voiceReceived } }
    filter: {
      includedEventTypes: ['voice.received']
      subjectBeginsWith: ''
      subjectEndsWith: ''
      isSubjectCaseSensitive: false
    }
    retryPolicy: defaultRetryPolicy
    deadLetterDestination: !empty(deadLetterStorage.storageAccountId)
      ? {
          endpointType: 'StorageBlob'
          properties: {
            resourceId: deadLetterStorage.storageAccountId
            blobContainerName: deadLetterStorage.containerName
          }
        }
      : {}
    eventDeliverySchema: 'EventGridSchema'
  }
}

// memory.recorded -> Service Bus bridge (fan-out via SB)
resource subMemoryRecordedBridge 'Microsoft.EventGrid/domains/eventSubscriptions@2025-02-15' = if !empty(functionEndpoints.memoryRecordedBridge) {
  parent: domain
  name: 'sub-memory-recorded-to-sb'
  properties: {
    destination: { endpointType: 'Webhook', properties: { endpointUrl: functionEndpoints.memoryRecordedBridge } }
    filter: { includedEventTypes: ['memory.recorded'], subjectBeginsWith: '', subjectEndsWith: '', isSubjectCaseSensitive: false }
    retryPolicy: defaultRetryPolicy
    deadLetterDestination: !empty(deadLetterStorage.storageAccountId) ? { endpointType: 'StorageBlob', properties: { resourceId: deadLetterStorage.storageAccountId, blobContainerName: deadLetterStorage.containerName } } : {}
    eventDeliverySchema: 'EventGridSchema'
  }
}

// memory.flagged -> Owner review queue (direct)
resource subMemoryFlaggedReview 'Microsoft.EventGrid/domains/eventSubscriptions@2025-02-15' = if !empty(functionEndpoints.memoryFlaggedReview) {
  parent: domain
  name: 'sub-memory-flagged-to-review'
  properties: {
    destination: { endpointType: 'Webhook', properties: { endpointUrl: functionEndpoints.memoryFlaggedReview } }
    filter: { includedEventTypes: ['memory.flagged'], subjectBeginsWith: '', subjectEndsWith: '', isSubjectCaseSensitive: false }
    retryPolicy: defaultRetryPolicy
    deadLetterDestination: !empty(deadLetterStorage.storageAccountId) ? { endpointType: 'StorageBlob', properties: { resourceId: deadLetterStorage.storageAccountId, blobContainerName: deadLetterStorage.containerName } } : {}
    eventDeliverySchema: 'EventGridSchema'
  }
}

// alias.requested -> Service Bus bridge (Guardian validation)
resource subAliasRequestedBridge 'Microsoft.EventGrid/domains/eventSubscriptions@2025-02-15' = if !empty(functionEndpoints.aliasRequestedBridge) {
  parent: domain
  name: 'sub-alias-requested-to-sb'
  properties: {
    destination: { endpointType: 'Webhook', properties: { endpointUrl: functionEndpoints.aliasRequestedBridge } }
    filter: { includedEventTypes: ['alias.requested'], subjectBeginsWith: '', subjectEndsWith: '', isSubjectCaseSensitive: false }
    retryPolicy: defaultRetryPolicy
    deadLetterDestination: !empty(deadLetterStorage.storageAccountId) ? { endpointType: 'StorageBlob', properties: { resourceId: deadLetterStorage.storageAccountId, blobContainerName: deadLetterStorage.containerName } } : {}
    eventDeliverySchema: 'EventGridSchema'
  }
}

// alias.updated -> Service Bus bridge (cache invalidation + Prompter confirm)
resource subAliasUpdatedBridge 'Microsoft.EventGrid/domains/eventSubscriptions@2025-02-15' = if !empty(functionEndpoints.aliasUpdatedBridge) {
  parent: domain
  name: 'sub-alias-updated-to-sb'
  properties: {
    destination: { endpointType: 'Webhook', properties: { endpointUrl: functionEndpoints.aliasUpdatedBridge } }
    filter: { includedEventTypes: ['alias.updated'], subjectBeginsWith: '', subjectEndsWith: '', isSubjectCaseSensitive: false }
    retryPolicy: defaultRetryPolicy
    deadLetterDestination: !empty(deadLetterStorage.storageAccountId) ? { endpointType: 'StorageBlob', properties: { resourceId: deadLetterStorage.storageAccountId, blobContainerName: deadLetterStorage.containerName } } : {}
    eventDeliverySchema: 'EventGridSchema'
  }
}

// memory.archived -> TBD (placeholder, enable when flow is defined)
// resource subMemoryArchived 'Microsoft.EventGrid/domains/eventSubscriptions@2025-02-15' = if false { ... }

output domainName string = domain.name
output domainEndpoint string = domain.properties.endpoint
output topicNames array = [
  'checkin.due'
  'voice.received'
  'memory.archived'
  'memory.recorded'
  'memory.flagged'
  'alias.requested'
  'alias.updated'
]
