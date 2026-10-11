import { GlobalInputs } from '../_types.bicep'

@export()
type ResourceGroupInputs = {
  global: GlobalInputs
  @description('Resource group name.')
  resourceGroupName: string
}
