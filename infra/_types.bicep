@export()
type EnvironmentType = 'dev' | 'test' | 'prod'

@export()
type GlobalInputs = {
  @description('Name of ACR')
  acrName: string
  @description('Cosmos Account Name')
  cosmosAccountName: string
  @description('Name of Key Vault')
  keyVaultName: string

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
  cosmosPrincipalObjectId: string
}
