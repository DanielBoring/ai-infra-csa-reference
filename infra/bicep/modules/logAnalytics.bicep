// ---------------------------------------------------------------------------
// Module: Log Analytics Workspace
// Uses: avm/res/operational-insights/workspace
// ---------------------------------------------------------------------------

@description('Name of the Log Analytics workspace.')
param name string

@description('Azure region.')
param location string

@description('Resource tags.')
param tags object = {}

@description('Data retention in days.')
@minValue(7)
@maxValue(730)
param retentionInDays int = 30

module workspace 'br/public:avm/res/operational-insights/workspace:0.9.0' = {
  name: '${name}-deploy'
  params: {
    name: name
    location: location
    tags: tags
    dataRetention: retentionInDays
    skuName: 'PerGB2018'
  }
}

output resourceId string = workspace.outputs.resourceId
output name string = workspace.outputs.name
