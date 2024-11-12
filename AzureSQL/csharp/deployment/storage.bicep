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
  properties: {
    allowSharedKeyAccess: false // Ensure shared key access is disabled
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

// Assign storage account roles to blobService
// Storage Account Contributor,  Storage Blob Data Owner ,  Storage Queue Data Contributor
param storage_account_id_roles array = [
  '17d1049b-9a84-46fb-8f53-869881c3d3ab', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b', '974c5e8b-45b9-4653-ba55-5f855dd0fb88' 
]
// Assign roles to storage account
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
