@export()
type EnvironmentType = 'dev' | 'test' | 'prod'

@export()
type DeploymentMode = 'all' | 'container-apps' | 'databases' | 'skip-redis'

@export()
type SecretKeys = {
  @description('Key used for Postgres connection string')
  postgres: string
  @description('Key used for Redis connection string')
  redis: string
}

@export()
type GlobalInputs = {
  @description('Name of ACR')
  acrName: string
  @description('Cosmos Account Name')
  cosmosAccountName: string
  @description('Name of Key Vault')
  keyVaultName: string

  @description('Mode of deployment, to choose resources deployed')
  mode: DeploymentMode
  @description('The location of the resources.')
  location: string
  @description('The base name for all resources.')
  baseName: string
  @description('Container image to use for the container app.')
  containerImage: string
  @description('The environment name.')
  environment: EnvironmentType
  @description('Client IP for Postgres access.')
  postgresClientIp: string
  @description('Cosmos database name.')
  cosmosDatabase: string
  @description('Object id of a developer principal granted Cosmos data-plane access for local tooling. Pass an empty string to skip the grant.')
  developerPrincipalObjectId: string

  @description('Collection of keys used in Key Vault')
  keys: SecretKeys
}
