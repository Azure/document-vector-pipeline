using './main.bicep'

var baseName = 'docing'

// Naming params
param managedIdentity_name = '${baseName}useridentity'
param storage_name = '${baseName}blobacc'
param function_app_name = '${baseName}funcapp'
param cosmosdb_name = '${baseName}cosmosacc'
param document_intelligence_name = '${baseName}docintl'
param open_ai_name = '${baseName}openai'

// Common params
param tags = {}

// Storage params
param storage_containers = [
  {
    name: 'documents'
  }
]

// Function app params
param function_app_storageSkuName = 'Standard_LRS'

param maxTokensPerChunk = '250'
param overlapTokens = '0'

// CosmosDB params
param cosmosdb_databaseName = 'semantic_search_db'
param cosmosdb_capabilities = [
  { name: 'EnableServerless' }
  { name: 'EnableNoSQLVectorSearch' }
]

// Document Intelligence Params
param document_intelligence_sku = {
  name: 'S0'
}
param document_intelligence_publicNetworkAccess = 'Enabled'
param document_intelligence_disableLocalAuth = false

// Open AI params
param modelDeployment = 'text-embedding-3-large'
param modelDimensions = '1536'
param open_ai_deployments = [
  {
    name: modelDeployment
    sku: {
      name: 'Standard'
      capacity: 100
    }
    model: {
      name: modelDeployment
      version: '1'
    }
  }
]
param open_ai_sku = 'S0'
param open_ai_kind = 'OpenAI'
param open_ai_format = 'OpenAI'
param open_ai_publicNetworkAccess = 'Enabled'
