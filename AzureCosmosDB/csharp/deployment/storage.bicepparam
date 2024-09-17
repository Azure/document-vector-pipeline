using './storage.bicep'

param name = 'docingblobacc'
param managedIdentityName = 'docinguseridentity'
param containers = [
  {
    name: 'documents'
  }
]

param tags = {}
