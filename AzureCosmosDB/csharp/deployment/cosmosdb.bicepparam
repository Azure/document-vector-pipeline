using './cosmosdb.bicep'

param managedIdentityName = 'docinguseridentity'
param name = 'docingcosmosacc'
param databaseName = 'semantic_search_db'

param capabilities = [
  { name: 'EnableServerless' }
  { name: 'EnableNoSQLVectorSearch' }
]
param tags = {}
