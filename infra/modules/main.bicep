import { ResourceGroupInputs } from './_types.bicep'

targetScope = 'resourceGroup'

param inputs ResourceGroupInputs

module acr 'acr.bicep' = {
  name: '${deployment().name}-acr'
  params: {
    inputs: inputs
  }
}
