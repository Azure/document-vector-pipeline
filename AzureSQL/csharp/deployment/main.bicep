// Resource params
param tags object = {}

@description('Base name for all resources')
param baseName string

// Resource names
var managedIdentity_name = '${baseName}useridentity'
var storage_name = '${baseName}blobacc'
var function_app_name = '${baseName}funcapp'
var document_intelligence_name = '${baseName}docintl'
var open_ai_name = '${baseName}openai'
var azuresqldb_name = '${baseName}db'
var azuresqlServerName = '${baseName}server'
var function_app_storageAccountName = '${function_app_name}store'
var function_app_appInsightsName = '${function_app_name}insight'
var function_app_logAnalyticsName = '${function_app_name}log'
var function_app_appServicePlanName = '${function_app_name}service'

// PrincipalId to be the SQL Admin
@description('PrincipalId to be the SQL Admin')
param userPrincipalId string

// Storage params
param storage_containers array = []

// Function app params
param function_app_storageSkuName string

// Open AI params
param open_ai_deployments array
param open_ai_sku string
param open_ai_kind string
param open_ai_format string
param open_ai_publicNetworkAccess string
param modelDeployment string
param modelDimensions string

// Document intelligence params
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

// Azure SQL Database resource
module azuresql_deployment 'azuresql.bicep' = {
  name: 'azuresql_deployment'
  params: {
    managedIdentityName: managedIdentity_name
    azuresqldbName: azuresqldb_name
    azuresqlServerName: azuresqlServerName
    userPrincipalId: userPrincipalId
    tags: tags
  }
  dependsOn: [
    userManagedIdentity_deployment
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
    diAccountName: document_intelligence_name
    openAIAccountName: open_ai_name
    storageAccountName: storage_name
    modelDeployment: modelDeployment
    modelDimensions: modelDimensions
    azuresqldbName: azuresqldb_name
    azuresqlserverName: azuresqlServerName
  }
  dependsOn: [
    userManagedIdentity_deployment
    storage_deployment
    open_ai_deployment
    document_intelligence_deployment
    azuresql_deployment
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


// Document Intelligence Params
output AZURE_DOCUMENT_INTELLIGENCE_NAME string = document_intelligence_deployment.outputs.DocumentIntelligenceName
output AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT string = document_intelligence_deployment.outputs.DocumentIntelligenceEndpoint

// OpenAI
output AZURE_OPEN_AI_SERVICE_NAME string = open_ai_deployment.outputs.openAIServiceName
output AZURE_OPEN_AI_SERVICE_ENDPOINT string = open_ai_deployment.outputs.openAIServiceEndpoint

// SQL Query
output SQL_QUERY string = 'CREATE USER [${managedIdentity_name}] FROM EXTERNAL PROVIDER;ALTER ROLE db_datareader ADD MEMBER [${managedIdentity_name}];ALTER ROLE db_datawriter ADD MEMBER [${managedIdentity_name}];ALTER ROLE db_owner ADD MEMBER [${managedIdentity_name}];'
