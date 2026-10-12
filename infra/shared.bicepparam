using './shared.bicep'
param baseName = readEnvironmentVariable('BASE_NAME', 'memwell')
param location = readEnvironmentVariable('LOCATION', 'westeurope')
param sharedResourceGroupName = readEnvironmentVariable('SHARED_RG_NAME', '')
