@description('Location to deploy the resource. Defaults to the location of the resource group.')
param location string = resourceGroup().location

// Input parameters
param name string
param tags object
param sku object
param publicNetworkAccess string
param disableLocalAuth bool

// Assign user identity permissions to storage account
param managedIdentityName string
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
  name: managedIdentityName
}

// Create document intelligence resource
resource documentIntelligence 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' = {
  name: name
  location: location
  tags: tags
  kind: 'FormRecognizer'
  properties: {
    customSubDomainName: name
    disableLocalAuth: disableLocalAuth
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  sku: sku
}

param storage_account_id_roles array = ['a97b65f3-24c7-4388-baec-2e87135dc908'] //Cognitive service user
resource roleAssignmentDocumentIntelligence 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for id_role in storage_account_id_roles: {
    name: guid(resourceGroup().id, '${documentIntelligence.name}-storagerole', id_role)
    scope: documentIntelligence
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', id_role)
      principalId: managedIdentity.properties.principalId
    }
  }
]

// Output parameters
@description('Name for the deployed Document Intelligence resource.')
output DocumentIntelligenceName string = documentIntelligence.name

@description('Endpoint for the deployed Document Intelligence resource.')
output DocumentIntelligenceEndpoint string = documentIntelligence.properties.endpoint
