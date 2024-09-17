param location string = resourceGroup().location
param capabilities array = [
  { name: 'EnableServerless' }
  { name: 'EnableNoSQLVectorSearch' /*TODO: This doesn't seem to work on account creation.*/ }
]

// Input parameters
param databaseName string
param name string
param tags object

// Create cosmosdb account
resource cosmosDB 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: name
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        failoverPriority: 0
        isZoneRedundant: false
        locationName: location
      }
    ]
    capabilities: capabilities
  }
  tags: tags
}

// Assign user identity permissions to storage account
param managedIdentityName string
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
  name: managedIdentityName
}

// Create database
resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  parent: cosmosDB
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
  }
  tags: tags
}

param id_role string = '00000000-0000-0000-0000-000000000002' // Built-in data contributor
resource roleAssignmentSqlCosmosDB 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2021-10-15' = {
  name: guid(resourceGroup().id, '${name}-datacontributorrole', id_role)
  parent: cosmosDB
  properties: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionId: resourceId('Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions', name, id_role)
    scope: cosmosDB.id
  }
}

output CosmosDBAccountName string = cosmosDB.name
output CosmosDBEndpoint string = cosmosDB.properties.documentEndpoint
