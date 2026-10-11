using './main.bicep'
param baseName = readEnvironmentVariable('BASE_NAME', 'memwell')
param environment = readEnvironmentVariable('ENVIRONMENT', 'dev')
param location = readEnvironmentVariable('LOCATION', 'westeurope')
param resourceGroupName = readEnvironmentVariable('RG_NAME', '')
param containerImage = readEnvironmentVariable('IMAGE', 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest')
