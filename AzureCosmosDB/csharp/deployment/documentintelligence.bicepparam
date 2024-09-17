using './documentintelligence.bicep'

param managedIdentityName = 'docinguseridentity'
param name = 'docingdocintl'

param tags = {}
param sku = {
  name: 'S0'
}
param publicNetworkAccess = 'Enabled'
param disableLocalAuth = false
