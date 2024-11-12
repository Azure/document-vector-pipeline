using './main.bicep'

param baseName = 'docai'

// Mandatory params
param userPrincipalId = ''

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
      capacity: 10
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
