// ---------------------------------------------------------------------------
// AI Infrastructure CSA Reference — Main Bicep Orchestrator
// ---------------------------------------------------------------------------
// This template deploys the full infrastructure baseline using Azure Verified
// Modules (AVM). Toggle private networking with the enablePrivateNetworking
// parameter.
//
// Usage:
//   az deployment group create \
//     --resource-group <rg-name> \
//     --template-file main.bicep \
//     --parameters params/dev.bicepparam
// ---------------------------------------------------------------------------

targetScope = 'resourceGroup'

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Environment name used for naming and tagging.')
@allowed(['dev', 'staging', 'prod'])
param environmentName string = 'dev'

@description('Project name prefix for resource naming.')
param projectName string = 'ai-infra-ref'

@description('Cost center tag value.')
param costCenter string = ''

@description('Owner tag value.')
param owner string = ''

@description('Data classification for tagging.')
@allowed(['general', 'confidential', 'highly-confidential'])
param dataClassification string = 'general'

@description('Enable private networking (VNet, PEs, Private DNS Zones).')
param enablePrivateNetworking bool = false

@description('APIM SKU name.')
@allowed(['Consumption', 'Developer', 'StandardV2'])
param apimSkuName string = 'Consumption'

@description('APIM publisher email (required).')
param apimPublisherEmail string

@description('APIM publisher name.')
param apimPublisherName string = 'AI Infra CSA Reference'

@description('Log Analytics retention in days.')
@minValue(7)
@maxValue(730)
param logRetentionDays int = 30

@description('ACA minimum replicas (0 = scale to zero).')
@minValue(0)
param acaMinReplicas int = 0

@description('ACA maximum replicas.')
@minValue(1)
param acaMaxReplicas int = 5

@description('Container image for the chatbot app.')
param containerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('VNet address prefix (used when enablePrivateNetworking=true).')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('ACA subnet prefix (used when enablePrivateNetworking=true).')
param acaSubnetPrefix string = '10.0.0.0/23'

@description('Private Endpoint subnet prefix.')
param peSubnetPrefix string = '10.0.2.0/24'

@description('Real Azure AI Foundry endpoint URL. Leave empty to use stub.')
param aiFoundryEndpoint string = ''

@description('Enable zone redundancy for ACA Environment (recommended for production).')
param zoneRedundant bool = false

@description('Optional unique suffix appended to globally-unique resource names (Key Vault, APIM) to prevent soft-delete/purge-protection collisions across repeated runs. Must be lowercase alphanumeric (no hyphens) and at most 8 characters to keep Key Vault names within the 24-character Azure limit. Leave empty to auto-generate a deterministic 8-character hash from the resource group ID.')
@maxLength(8)
param uniqueSuffix string = ''

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------

var nameSuffix = '${projectName}-${environmentName}'
// uniqueString returns a 13-char lowercase alphanumeric hash; we use the first
// 8 characters so the Key Vault name stays within the 24-char limit.
var resolvedUniqueSuffix = empty(uniqueSuffix) ? substring(uniqueString(resourceGroup().id), 0, 8) : uniqueSuffix
var useStub = empty(aiFoundryEndpoint)
var tags = {
  environment: environmentName
  project: projectName
  'cost-center': costCenter
  owner: owner
  'data-classification': dataClassification
  'managed-by': 'bicep'
}

// ---------------------------------------------------------------------------
// Module: User-Assigned Managed Identity
// ---------------------------------------------------------------------------

module managedIdentity 'modules/managedIdentity.bicep' = {
  name: 'managed-identity'
  params: {
    name: 'id-${nameSuffix}'
    location: location
    tags: tags
  }
}

// ---------------------------------------------------------------------------
// Module: Log Analytics Workspace
// ---------------------------------------------------------------------------

module logAnalytics 'modules/logAnalytics.bicep' = {
  name: 'log-analytics'
  params: {
    name: 'law-${nameSuffix}'
    location: location
    tags: tags
    retentionInDays: logRetentionDays
  }
}

// ---------------------------------------------------------------------------
// Module: Application Insights
// ---------------------------------------------------------------------------

module appInsights 'modules/appInsights.bicep' = {
  name: 'app-insights'
  params: {
    name: 'appi-${nameSuffix}'
    location: location
    tags: tags
    workspaceResourceId: logAnalytics.outputs.resourceId
  }
}

// ---------------------------------------------------------------------------
// Module: Key Vault
// ---------------------------------------------------------------------------

module keyVault 'modules/keyVault.bicep' = {
  name: 'key-vault'
  params: {
    name: 'kv-${replace(nameSuffix, '-', '')}${resolvedUniqueSuffix}'
    location: location
    tags: tags
  }
}

// ---------------------------------------------------------------------------
// Module: API Management
// ---------------------------------------------------------------------------

module apim 'modules/apim.bicep' = {
  name: 'api-management'
  params: {
    name: 'apim-${nameSuffix}-${resolvedUniqueSuffix}'
    location: location
    tags: tags
    skuName: apimSkuName
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    managedIdentityId: managedIdentity.outputs.resourceId
    useStub: useStub
    aiFoundryEndpoint: aiFoundryEndpoint
  }
}

// ---------------------------------------------------------------------------
// Module: ACA Environment
// ---------------------------------------------------------------------------

module acaEnvironment 'modules/acaEnvironment.bicep' = {
  name: 'aca-environment'
  params: {
    name: 'acaenv-${nameSuffix}'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.resourceId
    enableVnetIntegration: enablePrivateNetworking
    vnetSubnetId: enablePrivateNetworking ? vnet!.outputs.acaSubnetId : ''
    zoneRedundant: zoneRedundant
  }
}

// ---------------------------------------------------------------------------
// Module: Container App (Chatbot)
// ---------------------------------------------------------------------------

module containerApp 'modules/containerApp.bicep' = {
  name: 'container-app'
  params: {
    name: 'app-${nameSuffix}'
    location: location
    tags: tags
    environmentId: acaEnvironment.outputs.resourceId
    managedIdentityId: managedIdentity.outputs.resourceId
    managedIdentityClientId: managedIdentity.outputs.clientId
    containerImage: containerImage
    minReplicas: acaMinReplicas
    maxReplicas: acaMaxReplicas
    apimGatewayUrl: apim.outputs.gatewayUrl
    appInsightsConnectionString: appInsights.outputs.connectionString
  }
}

// ---------------------------------------------------------------------------
// Module: Role Assignments
// ---------------------------------------------------------------------------

module roleAssignments 'modules/roleAssignments.bicep' = {
  name: 'role-assignments'
  params: {
    managedIdentityPrincipalId: managedIdentity.outputs.principalId
    keyVaultName: keyVault.outputs.name
    apimName: apim.outputs.name
  }
}

// ---------------------------------------------------------------------------
// Module: VNet + Private Networking (conditional)
// ---------------------------------------------------------------------------

module vnet 'modules/vnet.bicep' = if (enablePrivateNetworking) {
  name: 'vnet'
  params: {
    name: 'vnet-${nameSuffix}'
    location: location
    tags: tags
    addressPrefix: vnetAddressPrefix
    acaSubnetPrefix: acaSubnetPrefix
    peSubnetPrefix: peSubnetPrefix
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

output acaFqdn string = containerApp.outputs.fqdn
output apimGatewayUrl string = apim.outputs.gatewayUrl
output appInsightsName string = appInsights.outputs.name
output keyVaultName string = keyVault.outputs.name
output logAnalyticsName string = logAnalytics.outputs.name
output managedIdentityClientId string = managedIdentity.outputs.clientId
output useStub bool = useStub
