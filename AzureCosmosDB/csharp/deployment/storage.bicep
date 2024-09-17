param location string = resourceGroup().location

// Input parameters
param name string
param tags object
param containers array = []

// Create storage account
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  tags: tags
}

// Create storage containers
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
}

resource blobContainers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = [
  for container in containers: {
    parent: blobService
    name: container.name
  }
]

// Assign user identity permissions to storage account
param managedIdentityName string
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
  name: managedIdentityName
}

param storage_account_id_roles array = ['2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'] // Storage blob data reader
resource roleAssignmentStorageAccount 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for id_role in storage_account_id_roles: {
    name: guid(resourceGroup().id, '${storage.name}-storagerole', id_role)
    scope: blobService
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', id_role)
      principalId: managedIdentity.properties.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

// Output storage account name, connection string and key
output AzureBlobStorageAccountName string = storage.name
output AzureBlobStorageAccountEndpoint string = storage.properties.primaryEndpoints.blob
