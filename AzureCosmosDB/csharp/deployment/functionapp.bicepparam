using './functionapp.bicep'

param managedIdentityName = 'docinguseridentity'
param functionAppName = 'docingfunc'
param cosmosdbAccountName = 'docingcosmosacc'
param diAccountName = 'docingdocintl'
param openAIAccountName = 'docingopenaiacc'
param storageAccountName = 'docingblobacc'

param funcAppStorageSkuName = 'Standard_LRS'
param funcAppStorageAccountName = '${functionAppName}store'
param appInsightsName = '${functionAppName}insight'
param appServicePlanName = '${functionAppName}service'
param logAnalyticsName = '${functionAppName}log'

param modelDeployment = 'text-embedding-3-large'
param modelDimensions = '1536'
