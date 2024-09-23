var location = resourceGroup().location

// Input params
param funcAppStorageAccountName string
param funcAppStorageSkuName string
param appInsightsName string
param appServicePlanName string
param functionAppName string
param logAnalyticsName string
param managedIdentityName string
param cosmosdbAccountName string
param diAccountName string
param openAIAccountName string
param storageAccountName string
param modelDeployment string
param modelDimensions string
param maxTokensPerChunk string
param overlapTokens string

// Get existing managed identity resource
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
  name: managedIdentityName
}

resource cosmosDB 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' existing = {
  name: cosmosdbAccountName
}

resource documentIntelligence 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' existing = {
  name: diAccountName
}

resource openAi 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' existing = {
  name: openAIAccountName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}
var storageConnectionStringValue = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'

// Create webapps storage account to hold webapps related resources
resource func_app_storage_account 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: funcAppStorageAccountName
  location: location
  sku: {
    name: funcAppStorageSkuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
  resource blobService 'blobServices' = {
    name: 'default'
  }
}
var funcAppStorageConnectionStringValue = 'DefaultEndpointsProtocol=https;AccountName=${func_app_storage_account.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${func_app_storage_account.listKeys().keys[0].value}'

// Assign storage account contributor role to func_app_storage_account
param storage_account_id_roles array = ['ba92f5b4-2d11-453d-a403-e96b0029c9fe'] // Storage blob data contributor
resource roleAssignmentFuncStorageAccount 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = [
  for id_role in storage_account_id_roles: {
    name: guid(resourceGroup().id, '${func_app_storage_account.name}-webjobsrole', id_role)
    scope: func_app_storage_account
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', id_role)
      principalId: managedIdentity.properties.principalId
    }
  }
]

// Create a new Log Analytics workspace to back the Azure Application Insights instance
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: 1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Application Insights instance
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    WorkspaceResourceId: logAnalytics.id
  }
}

// Web server farm
resource appservice_plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  kind: 'functionapp'
  sku: {
    name: 'Y1'
  }
  properties: {}
}

// Deploy the Azure Function app with application
resource funcApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    httpsOnly: true
    serverFarmId: appservice_plan.id
    keyVaultReferenceIdentity: managedIdentity.id
    enabled: true
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: funcAppStorageConnectionStringValue
        }
        // TODO(amisi) - directly hookup managed identity with blob trigger
        // {
        //   name: 'AzureWebJobsStorage__accountName'
        //   value: funcAppStorageAccountName
        // }
        // {
        //   name: 'AzureWebJobsStorage__credential'
        //   value: 'managedIdentity'
        // }
        // {
        //   name: 'AzureWebJobsStorage__clientId'
        //   value: managedIdentity.properties.clientId
        // }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: funcAppStorageConnectionStringValue
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'netFrameworkVersion'
          value: 'v8.0'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'AzureBlobStorageAccConnectionString'
          value: storageConnectionStringValue
        }
        // TODO(amisi) - directly hookup managed identity with blob trigger
        // {
        //   name: 'AzureBlobStorageAccConnectionString__serviceUri'
        //   value: storageAccount.properties.primaryEndpoints.blob
        // }
        // {
        //   name: 'AzureBlobStorageAccConnectionString__credential'
        //   value: 'managedIdentity'
        // }
        // {
        //   name: 'AzureBlobStorageAccConnectionString__clientId'
        //   value: managedIdentity.properties.clientId
        // }
        {
          name: 'AzureManagedIdentityClientId'
          value: managedIdentity.properties.clientId
        }
        {
          name: 'AzureCosmosDBConnectionString'
          value: cosmosDB.properties.documentEndpoint
        }
        {
          name: 'AzureDocumentIntelligenceConnectionString'
          value: documentIntelligence.properties.endpoint
        }
        {
          name: 'AzureOpenAIConnectionString'
          value: openAi.properties.endpoint
        }
        {
          name: 'AzureOpenAIModelDeployment'
          value: modelDeployment
        }
        {
          name: 'AzureOpenAIModelDimensions'
          value: modelDimensions
        }
        {
          name: 'MaxTokensPerChunk'
          value: maxTokensPerChunk
        }
        {
          name: 'OverlapTokens'
          value: overlapTokens
        }
        {
          name: 'AzureFunctionsJobHost__functionTimeout'
          value: '00:10:00'
        }
      ]
    }
  }
}

// Assign storage account contributor role to azure function app
param id_roles_arr array = ['b24988ac-6180-42a0-ab88-20f7382dd24c'] // Contributor (priviledged access)
resource roleAssignmentFunctionApp 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for id_role in id_roles_arr: {
    name: guid(resourceGroup().id, '${func_app_storage_account.name}-funcrole', id_role)
    scope: funcApp
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', id_role)
      principalId: managedIdentity.properties.principalId
    }
  }
]
