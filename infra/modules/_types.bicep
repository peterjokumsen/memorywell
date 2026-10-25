import { GlobalInputs } from '../_types.bicep'

@export()
type ResourceGroupInputs = {
  global: GlobalInputs
  @description('Resource group name.')
  resourceGroupName: string
  @description('Tags to include for resources.')
  tags: object
}

@export()
type EventGridFunctions = {
  @secure()
  timerCadence: string? // HTTP trigger for checkin.due
  @secure()
  voiceReceived: string? // HTTP trigger for voice.received
  @secure()
  memoryRecordedBridge: string? // Bridge to SB topic 'memory.recorded'
  @secure()
  memoryFlaggedReview: string? // Owner review queue Function
  @secure()
  aliasRequestedBridge: string? // Bridge to SB topic 'alias.requested'
  @secure()
  aliasUpdatedBridge: string? // Bridge to SB topic 'alias.updated'
}

@export()
type ServiceBusTopics = {
  memoryRecorded: string
  memoryFlagged: string
  aliasRequested: string
  aliasUpdated: string
}
