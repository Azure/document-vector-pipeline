// Resource params
param tags object = {}

// Managed identity params
param managedIdentity_name string

// Storage params
param storage_name string
param storage_containers array = []

// Function app params
param function_app_name string
param function_app_storageSkuName string

param function_app_storageAccountName string = '${function_app_name}store'
param function_app_appInsightsName string = '${function_app_name}insight'
param function_app_logAnalyticsName string = '${function_app_name}log'
param function_app_appServicePlanName string = '${function_app_name}service'

param maxTokensPerChunk string
param overlapTokens string

// CosmosDB params
param cosmosdb_capabilities array
param cosmosdb_databaseName string
param cosmosdb_name string

// Open AI params
param open_ai_deployments array
param open_ai_name string
param open_ai_sku string
param open_ai_kind string
param open_ai_format string
param open_ai_publicNetworkAccess string
param modelDeployment string
param modelDimensions string

// Document intelligence params
param document_intelligence_name string
param document_intelligence_sku object
param document_intelligence_publicNetworkAccess string
param document_intelligence_disableLocalAuth bool

// User managed identity resource
module userManagedIdentity_deployment 'userIdentity.bicep' = {
  name: 'userManagedIdentity_deployment'
  params: {
    managedIdentityName: managedIdentity_name
  }
}

// Storage resource
module storage_deployment 'storage.bicep' = {
  name: 'storage_deployment'
  params: {
    name: storage_name
    containers: storage_containers
    tags: tags
    managedIdentityName: managedIdentity_name
  }
  dependsOn: [
    userManagedIdentity_deployment
  ]
}

// CosmosDB resource
module cosmosdb_deployment 'cosmosdb.bicep' = {
  name: 'cosmosdb_deployment'
  params: {
    managedIdentityName: managedIdentity_name
    capabilities: cosmosdb_capabilities
    databaseName: cosmosdb_databaseName
    name: cosmosdb_name
    tags: tags
  }
  dependsOn: [
    userManagedIdentity_deployment
    storage_deployment
  ]
}

// Document Intelligence resource
module document_intelligence_deployment 'documentintelligence.bicep' = {
  name: 'document_intelligence_deployment'
  params: {
    name: document_intelligence_name
    managedIdentityName: managedIdentity_name
    sku: document_intelligence_sku
    publicNetworkAccess: document_intelligence_publicNetworkAccess
    disableLocalAuth: document_intelligence_disableLocalAuth
    tags: tags
  }
  dependsOn: [
    userManagedIdentity_deployment
    storage_deployment
  ]
}

// OpenAI Resource
module open_ai_deployment 'openai.bicep' = {
  name: 'open_ai_deployment'
  params: {
    deployments: open_ai_deployments
    managedIdentityName: managedIdentity_name
    name: open_ai_name
    format: open_ai_format
    kind: open_ai_kind
    sku: open_ai_sku
    publicNetworkAccess: open_ai_publicNetworkAccess
    tags: tags
  }
  dependsOn: [
    userManagedIdentity_deployment
  ]
}

// Function App Resource
module function_app_deployment 'functionapp.bicep' = {
  name: 'function_app_deployment'
  params: {
    managedIdentityName: managedIdentity_name
    functionAppName: function_app_name
    funcAppStorageSkuName: function_app_storageSkuName
    funcAppStorageAccountName: function_app_storageAccountName
    appInsightsName: function_app_appInsightsName
    appServicePlanName: function_app_appServicePlanName
    logAnalyticsName: function_app_logAnalyticsName
    cosmosdbAccountName: cosmosdb_name
    diAccountName: document_intelligence_name
    openAIAccountName: open_ai_name
    storageAccountName: storage_name
    modelDeployment: modelDeployment
    modelDimensions: modelDimensions
    maxTokensPerChunk: maxTokensPerChunk
    overlapTokens: overlapTokens
  }
  dependsOn: [
    userManagedIdentity_deployment
    storage_deployment
    open_ai_deployment
    document_intelligence_deployment
    cosmosdb_deployment
  ]
}

// Output params
// User Managed Identity and KeyVault Output Params
output AZURE_USER_MANAGED_IDENTITY_NAME string = userManagedIdentity_deployment.outputs.AzureManagedIdentityName
output AZURE_USER_MANAGED_IDENTITY_ID string = userManagedIdentity_deployment.outputs.AzureManagedIdentityId
output AZURE_USER_MANAGED_IDENTITY_CLIENTID string = userManagedIdentity_deployment.outputs.AzureManagedIdentityClientId
output AZURE_USER_MANAGED_IDENTITY_PRINCIPALID string = userManagedIdentity_deployment.outputs.AzureManagedIdentityPrincipalId
output AZURE_USER_MANAGED_IDENTITY_TENANTID string = userManagedIdentity_deployment.outputs.AzureManagedIdentityTenantId

// Storage Params
output AZURE_BLOB_STORE_ACCOUNT_NAME string = storage_deployment.outputs.AzureBlobStorageAccountName
output AZURE_BLOB_STORE_ACCOUNT_ENDPOINT string = storage_deployment.outputs.AzureBlobStorageAccountEndpoint

// CosmosDB Params
output AZURE_COSMOS_DB_ACCOUNT_NAME string = cosmosdb_deployment.outputs.CosmosDBAccountName
output AZURE_COSMOS_DB_ENDPOINT string = cosmosdb_deployment.outputs.CosmosDBEndpoint

// Document Intelligence Params
output AZURE_DOCUMENT_INTELLIGENCE_NAME string = document_intelligence_deployment.outputs.DocumentIntelligenceName
output AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT string = document_intelligence_deployment.outputs.DocumentIntelligenceEndpoint

// OpenAI
output AZURE_OPEN_AI_SERVICE_NAME string = open_ai_deployment.outputs.openAIServiceName
output AZURE_OPEN_AI_SERVICE_ENDPOINT string = open_ai_deployment.outputs.openAIServiceEndpoint
