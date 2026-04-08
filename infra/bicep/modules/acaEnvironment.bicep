// ---------------------------------------------------------------------------
// Module: ACA Environment (Managed Environment)
// Uses: avm/res/app/managed-environment
// Decision: Consumption plan with scale-to-zero (ADR-008)
// ---------------------------------------------------------------------------

@description('Name of the ACA Environment.')
param name string

@description('Azure region.')
param location string

@description('Resource tags.')
param tags object = {}

@description('Log Analytics workspace resource ID for log sink.')
param logAnalyticsWorkspaceId string

@description('Enable VNet integration for private networking.')
param enableVnetIntegration bool = false

@description('Subnet resource ID for VNet integration (required when enableVnetIntegration=true).')
param vnetSubnetId string = ''

module environment 'br/public:avm/res/app/managed-environment:0.8.0' = {
  name: '${name}-deploy'
  params: {
    name: name
    location: location
    tags: tags
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceId
    infrastructureSubnetId: enableVnetIntegration ? vnetSubnetId : ''
    internal: enableVnetIntegration
    zoneRedundant: false
  }
}

output resourceId string = environment.outputs.resourceId
output name string = environment.outputs.name
output defaultDomain string = environment.outputs.defaultDomain
