param location string = resourceGroup().location

// Input parameters
param deployments array
param name string
param sku string
param tags object
param kind string
param format string
param publicNetworkAccess string

// Create openAI resource
resource openAi 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' = {
  name: name
  location: location
  sku: {
    name: sku
  }
  kind: kind
  properties: {
    customSubDomainName: name
    publicNetworkAccess: publicNetworkAccess
  }
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
}

@batchSize(1)
resource openAiDeployments 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = [
  for deployment in deployments: {
    parent: openAi
    name: deployment.name
    sku: {
      capacity: deployment.sku.capacity
      name: deployment.sku.name
    }
    properties: {
      model: {
        format: format
        name: deployment.model.name
        version: deployment.model.version
      }
    }
  }
]

// Assign user managed identity to openai app.
param managedIdentityName string
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
  name: managedIdentityName
}
param storage_account_id_roles array = [
  'a97b65f3-24c7-4388-baec-2e87135dc908' //Cognitive Services User
]

resource roleAssignmentOpenAIAccount 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for id_role in storage_account_id_roles: {
    name: guid(resourceGroup().id, '${name}-openairole', id_role)
    scope: openAi
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', id_role)
      principalId: managedIdentity.properties.principalId
    }
  }
]

output openAIServiceName string = openAi.name
output openAIServiceEndpoint string = openAi.properties.endpoint
