// Reusable module: one Azure Static Web App (Standard) for a Next.js UI, deployed by a pipeline
// with the app's deployment token rather than linked to a repository. Based on Approach1/SWA/main.bicep
// in the CLX repo, without the repository link: the platform workflow builds and uploads the app,
// so the resource no longer needs repositoryUrl/branch or a stored deploy token.

@description('Static Web App name')
param name string

@description('Azure region. Static Web Apps run in a few regions only: centralus, eastus2, westus2, westeurope, eastasia.')
@allowed([
  'centralus'
  'eastus2'
  'westus2'
  'westeurope'
  'eastasia'
])
param location string = 'centralus'

@description('SKU. Standard is needed for Next.js server routes with app settings at scale and custom domains on Front Door.')
@allowed([
  'Free'
  'Standard'
])
param skuName string = 'Standard'

@description('Non-secret app settings, available to the Next.js server as environment variables')
param appSettings object = {}

@description('Secret app settings (e.g. an APIM subscription key read in the calling template). Merged over appSettings.')
@secure()
param secretAppSettings object = {}

@description('Tags for the Static Web App')
param tags object = {}

resource staticSite 'Microsoft.Web/staticSites@2024-11-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuName
  }
  properties: {
    // No pull-request preview environments: they would get these app settings and be publicly reachable.
    stagingEnvironmentPolicy: 'Disabled'
    allowConfigFileUpdates: true
    enterpriseGradeCdnStatus: 'Disabled'
  }
}

resource staticSiteAppSettings 'Microsoft.Web/staticSites/config@2024-11-01' = {
  name: 'appsettings'
  parent: staticSite
  properties: union(appSettings, secretAppSettings)
}

output id string = staticSite.id
output name string = staticSite.name
output defaultHostname string = staticSite.properties.defaultHostname
