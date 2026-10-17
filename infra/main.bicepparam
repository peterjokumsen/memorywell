using './main.bicep'
param baseName = readEnvironmentVariable('BASE_NAME', 'memwell')
param environment = readEnvironmentVariable('ENVIRONMENT', 'dev')
param location = readEnvironmentVariable('LOCATION', 'westeurope')
param resourceGroupName = readEnvironmentVariable('RG_NAME', '')
param containerImage = readEnvironmentVariable('IMAGE', 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest')
param sharedResourceGroupName = readEnvironmentVariable('SHARED_RG_NAME', '')
param acrName = readEnvironmentVariable('SHARED_ACR_NAME', '')
param keyVaultName = readEnvironmentVariable('VAULT_NAME', '')
