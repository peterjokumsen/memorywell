import { EventGridFunctions, ResourceGroupInputs } from './_types.bicep'

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
param functionEndpoints EventGridFunctions = {
  timerCadence: '' // HTTP trigger for checkin.due
  voiceReceived: '' // HTTP trigger for voice.received
  memoryRecordedBridge: '' // Bridge to SB topic 'memory.recorded'
  memoryFlaggedReview: '' // Owner review queue Function
  aliasRequestedBridge: '' // Bridge to SB topic 'alias.requested'
  aliasUpdatedBridge: '' // Bridge to SB topic 'alias.updated'
}

// Dead-letter storage (expect platform.bicep to output these)
param deadLetterStorage object = {
  storageAccountId: ''
  containerName: 'eventgrid-dlq'
}

var defaultRetryPolicy resourceInput<'Microsoft.EventGrid/domains/eventSubscriptions@2025-02-15'>.properties.retryPolicy = {
  maxDeliveryAttempts: 30
  eventTimeToLiveInMinutes: 1440 // 24h
  //  retryPolicyType: 'ExponentialBackoff'
  //  minRetryIntervalInMinutes: 5
  //  maxRetryIntervalInMinutes: 60
}

// =====================================================================
// Event subscriptions (one per event type, with filters + DLQ)
// =====================================================================

type subDetails = {
  name: string
  isEnabled: bool
  destination: resourceInput<'Microsoft.EventGrid/domains/eventSubscriptions@2025-02-15'>.properties.destination
  filter: resourceInput<'Microsoft.EventGrid/domains/eventSubscriptions@2025-02-15'>.properties.filter
  retryPolicy: resourceInput<'Microsoft.EventGrid/domains/eventSubscriptions@2025-02-15'>.properties.retryPolicy?
}

var subs subDetails[] = [
  // checkin.due -> Prompter (direct)
  {
    name: 'checkin-due-prompter'
    isEnabled: !empty(functionEndpoints.?timerCadence)
    destination: {
      endpointType: 'WebHook'
      properties: { endpointUrl: functionEndpoints.?timerCadence }
    }
    filter: { includedEventTypes: ['checkin.due'] }
  }
  // voice.received -> transcription queue (direct)
  {
    name: 'voice-received-transcription'
    isEnabled: !empty(functionEndpoints.?voiceReceived)
    destination: {
      endpointType: 'WebHook'
      properties: { endpointUrl: functionEndpoints.?voiceReceived }
    }
    filter: { includedEventTypes: ['voice.received'] }
  }
  // memory.recorded -> Service Bus bridge (fan-out via SB)
  {
    name: 'memory-recorded-to-sb'
    isEnabled: !empty(functionEndpoints.?memoryRecordedBridge)
    destination: {
      endpointType: 'WebHook'
      properties: { endpointUrl: functionEndpoints.?memoryRecordedBridge }
    }
    filter: { includedEventTypes: ['memory.recorded'] }
  }
  // memory.flagged -> Owner review queue (direct)
  {
    name: 'memory-flagged-to-review'
    isEnabled: !empty(functionEndpoints.?memoryFlaggedReview)
    destination: {
      endpointType: 'WebHook'
      properties: { endpointUrl: functionEndpoints.?memoryFlaggedReview }
    }
    filter: { includedEventTypes: ['memory.flagged'] }
  }
  // alias.requested -> Service Bus bridge (Guardian validation)
  {
    name: 'alias-requested-to-sb'
    isEnabled: !empty(functionEndpoints.?aliasRequestedBridge)
    destination: {
      endpointType: 'WebHook'
      properties: { endpointUrl: functionEndpoints.?aliasRequestedBridge }
    }
    filter: { includedEventTypes: ['alias.requested'] }
  }
  // alias.updated -> Service Bus bridge (cache invalidation + Prompter confirm)
  {
    name: 'alias-updated-to-sb'
    isEnabled: !empty(functionEndpoints.?aliasUpdatedBridge)
    destination: {
      endpointType: 'WebHook'
      properties: { endpointUrl: functionEndpoints.?aliasUpdatedBridge }
    }
    filter: { includedEventTypes: ['alias.updated'] }
  }
]

var enabledSubs = filter(subs, s => s.isEnabled)

resource eventSubs 'Microsoft.EventGrid/domains/eventSubscriptions@2025-02-15' = [
  for sub in enabledSubs: {
    parent: domain
    name: sub.name
    properties: {
      destination: sub.destination
      filter: sub.filter
      retryPolicy: sub.?retryPolicy ?? defaultRetryPolicy
      deadLetterDestination: !empty(deadLetterStorage.storageAccountId)
        ? {
            endpointType: 'StorageBlob'
            properties: {
              resourceId: deadLetterStorage.storageAccountId
              blobContainerName: deadLetterStorage.containerName
            }
          }
        : {}
    }
  }
]

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
