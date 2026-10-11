import { GlobalInputs, EnvironmentType } from './_types.bicep'
/**
 Create resource group and deploy resources to it
*/
targetScope = 'subscription'

param location string = 'westeurope'
param baseName string = 'memwell'
param environment EnvironmentType = 'dev'

var globalInputs GlobalInputs = {
  location: location
  baseName: baseName
  environment: environment
}

// TODO: create a resource group for the environment. Using basename and environment to create a unique name for the resource group
