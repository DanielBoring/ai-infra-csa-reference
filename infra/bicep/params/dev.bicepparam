using '../main.bicep'

// ---------------------------------------------------------------------------
// Dev Environment Parameters
// ---------------------------------------------------------------------------

param environmentName = 'dev'
param projectName = 'ai-infra-ref'
param costCenter = 'development'
param owner = 'infra-csa-team'
param dataClassification = 'general'

// Networking: public baseline (no VNet/PE)
param enablePrivateNetworking = false

// APIM: Consumption tier for dev (ADR-005)
param apimSkuName = 'Consumption'
param apimPublisherEmail = 'admin@contoso.com'
param apimPublisherName = 'AI Infra CSA Reference'

// Observability: shorter retention for dev
param logRetentionDays = 30

// ACA: scale to zero for dev (ADR-008)
param acaMinReplicas = 0
param acaMaxReplicas = 3

// App: default hello-world image (replaced after app build)
param containerImage = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

// AI Foundry: empty = use stub (ADR-002)
param aiFoundryEndpoint = ''
