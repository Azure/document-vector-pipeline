using './azuresql.bicep'

param azuresqldbName  =  'dociingdb'
param managedIdentityName = 'docinguseridentity'
param tags = {}
param azuresqlServerName =  'dociingdb-server'
param userPrincipalId = ''
