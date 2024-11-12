param managedIdentityName string
param location string = resourceGroup().location

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: managedIdentityName
  location: location
}

output AzureManagedIdentityId string = managedIdentity.id
output AzureManagedIdentityName string = managedIdentity.name
output AzureManagedIdentityClientId string = managedIdentity.properties.clientId
output AzureManagedIdentityPrincipalId string = managedIdentity.properties.principalId
output AzureManagedIdentityTenantId string = managedIdentity.properties.tenantId
