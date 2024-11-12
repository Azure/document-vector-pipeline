param location string = resourceGroup().location
 
// PrincipalId to be the SQL Admin
@description('PrincipalId to be the SQL Admin')
param userPrincipalId string
 
param managedIdentityName string
param azuresqldbName string
param tags object
 
param azuresqlServerName string
 
// Get existing managed identity resource
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
  name: managedIdentityName
}
 
 
resource azuresqlserver 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: azuresqlServerName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    primaryUserAssignedIdentityId: managedIdentity.id
    administrators: {
      administratorType: 'ActiveDirectory'
      principalType: 'User'
      login: '${azuresqlServerName}-admin'
      sid: userPrincipalId
      tenantId: subscription().tenantId
      azureADOnlyAuthentication: true
    }
    restrictOutboundNetworkAccess: 'Disabled'
  }
}
resource azuresqldatabase 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  parent: azuresqlserver
  name: azuresqldbName
  location: location
  sku: {
    name: 'GP_S_Gen5'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 1
  }
  properties: {
    maxSizeBytes: 268435456000 // 250 GB
    zoneRedundant: false
    readScale: 'Disabled'
    requestedBackupStorageRedundancy: 'Local'
    minCapacity: json('0.5')
    autoPauseDelay: 60 // Serverless
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    createMode: 'Default'
  }
}
 
resource firewallRule 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = {
  parent: azuresqlserver
  name: '${azuresqlServerName}-AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}
 
output sqlServerName string = azuresqlServerName
output sqlDatabaseName string = azuresqldbName
 
//output sqlServerFullyQualifiedDomainName string = azuresqldbName.properties.fullyQualifiedDomainName
