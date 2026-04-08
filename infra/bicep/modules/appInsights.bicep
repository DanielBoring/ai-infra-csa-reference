// ---------------------------------------------------------------------------
// Module: Application Insights
// Uses: avm/res/insights/component
// ---------------------------------------------------------------------------

@description('Name of the Application Insights resource.')
param name string

@description('Azure region.')
param location string

@description('Resource tags.')
param tags object = {}

@description('Resource ID of the Log Analytics workspace.')
param workspaceResourceId string

module component 'br/public:avm/res/insights/component:0.4.0' = {
  name: '${name}-deploy'
  params: {
    name: name
    location: location
    tags: tags
    workspaceResourceId: workspaceResourceId
    kind: 'web'
    applicationType: 'web'
  }
}

output resourceId string = component.outputs.resourceId
output name string = component.outputs.name
output instrumentationKey string = component.outputs.instrumentationKey
output connectionString string = component.outputs.connectionString
