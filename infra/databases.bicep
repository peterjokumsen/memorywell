import { GlobalInputs, EnvironmentType } from './_types.bicep'
import { ResourceGroupInputs } from './modules/_types.bicep'

targetScope = 'subscription'

param location string
param baseName string
param environment EnvironmentType
param resourceGroupName string
param keyVaultName string
param cosmosAccountName string
param cosmosDatabase string
param postgresKeyName string
param postgresClientIp string
param postgresAdministratorPassword string
@secure()
param developerPrincipalObjectId string = ''

var globalInputs GlobalInputs = {
  acrName: ''
  cosmosAccountName: cosmosAccountName
  cosmosDatabase: cosmosDatabase
  keyVaultName: keyVaultName
  mode: 'all'
  location: location
  baseName: baseName
  environment: environment
  containerImage: ''
  postgresClientIp: postgresClientIp
  developerPrincipalObjectId: environment != 'dev' ? '' : developerPrincipalObjectId
  keys: { postgres: postgresKeyName }
}

var tags = { Environment: environment, BaseName: baseName }
var inputs ResourceGroupInputs = { global: globalInputs, resourceGroupName: resourceGroupName, tags: tags }

resource rg 'Microsoft.Resources/resourceGroups@2025-04-01' existing = { name: resourceGroupName }

param identityPrincipalIds array

module keyVault './modules/key-vault.bicep' = {
  name: '${deployment().name}-keyvault'
  scope: rg
  params: { inputs: inputs, identityPrincipalIds: identityPrincipalIds }
}

module cosmos './modules/cosmos.bicep' = {
  name: '${deployment().name}-cosmos'
  scope: rg
  params: { inputs: inputs, identityPrincipalIds: identityPrincipalIds }
}

module postgres './modules/postgres.bicep' = {
  name: '${deployment().name}-postgres'
  scope: rg
  params: { inputs: inputs, administratorPassword: postgresAdministratorPassword, administratorLogin: 'memwelladmin' }
}

module postgresConn './modules/secret.bicep' = {
  name: '${deployment().name}-postgres-conn'
  scope: rg
  params: { inputs: inputs, secretName: postgresKeyName, secretValue: postgres.outputs.connectionString }
}

output keyVaultUri string = keyVault.outputs.keyVaultUri
output cosmosAccountEndpoint string = cosmos.outputs.accountEndpoint
output cosmosDatabaseName string = cosmos.outputs.databaseName
output postgresServerName string = postgres.outputs.serverName
