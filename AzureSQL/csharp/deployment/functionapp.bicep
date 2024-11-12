var location = resourceGroup().location

// Input params
param funcAppStorageAccountName string
param funcAppStorageSkuName string
param appInsightsName string
param appServicePlanName string
param functionAppName string
param logAnalyticsName string
param managedIdentityName string
param azuresqldbName string
param azuresqlserverName string
param diAccountName string
param openAIAccountName string
param storageAccountName string
param modelDeployment string
param modelDimensions string

// Get existing managed identity resource
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
  name: managedIdentityName
}

resource azuresqlserver 'Microsoft.Sql/servers@2023-08-01-preview' existing= {
  name: azuresqlserverName
}

resource azuresqldatabase 'Microsoft.Sql/servers/databases@2022-05-01-preview' existing= {
  name: azuresqldbName
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

var sqlconnectionstringvalue = 'Server=tcp:${azuresqlserver.properties.fullyQualifiedDomainName},1433;Initial Catalog=${azuresqldatabase.name};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Authentication=Active Directory Managed Identity;User Id=${managedIdentity.properties.clientId};'
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
    allowSharedKeyAccess: false // Ensure shared key access is disabled
  }

}
// Assign storage account roles to func_app_storage_account
// Storage Account Contributor,  Storage Blob Data Owner ,  Storage Queue Data Contributor
param storage_account_id_roles array = [
  '17d1049b-9a84-46fb-8f53-869881c3d3ab', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b', '974c5e8b-45b9-4653-ba55-5f855dd0fb88' 
]

resource roleAssignmentFuncStorageAccount 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for id_role in storage_account_id_roles: {
    name: guid(resourceGroup().id, '${func_app_storage_account.name}-webjobsrole', id_role)
    scope: func_app_storage_account
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', id_role)
      principalId: managedIdentity.properties.principalId
      principalType: 'ServicePrincipal'
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
    type: 'UserAssigned'
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
          name: 'AzureWebJobsStorage__accountName'
          value: funcAppStorageAccountName
        }
        {
          name: 'AzureWebJobsStorage__clientId'
          value: managedIdentity.properties.clientId
        }
        {
          name: 'AzureWebJobsStorage__blobServiceUri'
          value: func_app_storage_account.properties.primaryEndpoints.blob
        }
        {
          name: 'AzureWebJobsStorage__queueServiceUri'
          value: func_app_storage_account.properties.primaryEndpoints.queue
        } 
        {
          name: 'AzureBlobStorageAccConnectionString___clientId'
          value: managedIdentity.properties.clientId
        }
        {
          name: 'AzureBlobStorageAccConnectionString__blobServiceUri'
          value: storageAccount.properties.primaryEndpoints.blob
        }
        {
          name: 'AzureBlobStorageAccConnectionString__queueServiceUri'
          value: storageAccount.properties.primaryEndpoints.queue
        }
        {
          name: 'AzureBlobStorageAccConnectionString__credential'
          value: 'managedIdentity'
        }
        {
          name: 'AzureBlobStorageAccConnectionString__managedIdentityResourceId'
          value: managedIdentity.id
        }
        {
          name: 'AzureManagedIdentityClientId'
          value: managedIdentity.properties.clientId        
        }
        {
          name: 'SqlConnectionString'
          value: sqlconnectionstringvalue       
        }
        {
          name: 'AzureDocumentIntelligenceConnectionString'
          value: documentIntelligence.properties.endpoint
        }
        {
          name: 'AzureDocumentIntelligenceKey'
          value: documentIntelligence.listKeys().key1       
        }
        {
          name: 'AzureOpenAIConnectionString'
          value: openAi.properties.endpoint
        }
        {
          name: 'AzureOpenAIKey'
          value: openAi.listKeys().key1
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
          name: 'AzureFunctionsJobHost__functionTimeout'
          value: '00:10:00'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE_BLOB_MI_RESOURCE_ID'
          value: managedIdentity.id
        }
        {
          name: 'WEBSITE_USE_PLACEHOLDER_DOTNETISOLATED'
          value: '1'
        }
        {
          name: 'APPINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        } 
      ]
    }
  }
}      

