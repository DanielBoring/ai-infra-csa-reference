using '../main.bicep'

// ---------------------------------------------------------------------------
// Production Environment Parameters
// ---------------------------------------------------------------------------

param environmentName = 'prod'
param projectName = 'ai-infra-ref'
param costCenter = 'production'
param owner = 'infra-csa-team'
param dataClassification = 'confidential'

// Networking: enable private networking for production
param enablePrivateNetworking = true
param vnetAddressPrefix = '10.0.0.0/16'
param acaSubnetPrefix = '10.0.0.0/23'
param peSubnetPrefix = '10.0.2.0/24'

// APIM: Standard v2 for production (VNet support, no cold starts)
param apimSkuName = 'StandardV2'
param apimPublisherEmail = 'admin@contoso.com'
param apimPublisherName = 'AI Infra CSA Reference'

// Observability: longer retention for production
param logRetentionDays = 90

// ACA: minimum 1 replica for production (no cold starts)
param acaMinReplicas = 1
param acaMaxReplicas = 10

// App: replace with your ACR image
param containerImage = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

// AI Foundry: set real endpoint for production
// param aiFoundryEndpoint = 'https://<your-foundry>.openai.azure.com/openai/deployments/<deployment>'
param aiFoundryEndpoint = ''
