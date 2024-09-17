using './openai.bicep'

param managedIdentityName = 'docinguseridentity'
param name = 'docingopenaiacc'

param deployments = [
  {
    name: 'text-embedding-3-large'
    sku: {
      name: 'Standard'
      capacity: 40
    }
    model: {
      name: 'text-embedding-3-large'
      version: '1'
    }
  }
]
param sku = 'S0'
param kind = 'OpenAI'
param format = 'OpenAI'
param publicNetworkAccess = 'Enabled'
param tags = {}
