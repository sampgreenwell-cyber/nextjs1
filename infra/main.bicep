// UI infrastructure: one Static Web App (Next.js, hybrid rendering) plus its own APIM subscription
// to the BFF it calls. The key never leaves Azure: it's read here (listSecrets) and handed to the
// Static Web App as the server-side app setting BFF_SUBSCRIPTION_KEY. Shared CLX resources (APIM and
// the BFF's API on it) are referenced, never created. Environment values live in <env>.bicepparam.
// Deployed by the platform workflow per environment:
//   az deployment group create -g <RESOURCE_GROUP> -f infra/main.bicep -p infra/<env>.bicepparam
//
// infra/modules/ is copied from sampgreenwell-cyber/platform-bicep-modules (see its README);
// update it from there, not by hand.

@description('App name (lowercase alnum or hyphen, max 15 chars)')
@maxLength(15)
param appName string

@description('Environment name, e.g. dev or qa')
param environmentName string

@description('Environment code used in resource names, e.g. d01 or q01')
param environmentCode string

@description('Static Web App region (Static Web Apps run in a few regions only)')
param location string

@description('Static Web App SKU')
@allowed([
  'Free'
  'Standard'
])
param skuName string = 'Standard'

@description('Existing APIM service name in this resource group')
param apimName string

@description('The BFF this UI calls: its APIM API is <bffName><apimApiSuffix>-api on /<bffName><apimApiSuffix>')
param bffName string

@description('Same as the BFF\'s apimApiSuffix. Only for environments that share one APIM (e.g. a lab).')
param apimApiSuffix string = ''

@description('BFF base URL for the server-side proxy. Empty = the APIM gateway path of the BFF; set it to call through Front Door instead.')
param bffBaseUrl string = ''

@description('Extra non-secret app settings for the Next.js server')
param appSettings object = {}

@description('Tags for resources')
param tags object

resource apim 'Microsoft.ApiManagement/service@2024-05-01' existing = {
  name: apimName
}

// Fails the deployment (NotFound) until the BFF is published through APIM in this environment.
resource bffApi 'Microsoft.ApiManagement/service/apis@2024-05-01' existing = {
  parent: apim
  name: '${bffName}${apimApiSuffix}-api'
}

var siteName = 'swa-lab-${appName}-${environmentCode}'

// One subscription per UI and environment, scoped to the BFF's API only: revocable on its own and
// visible per caller in APIM analytics. Rotate by regenerating the key in APIM and redeploying.
resource bffSubscription 'Microsoft.ApiManagement/service/subscriptions@2024-05-01' = {
  parent: apim
  name: siteName
  properties: {
    displayName: '${appName} UI (${environmentName}) -> ${bffName}${apimApiSuffix}'
    scope: bffApi.id
    state: 'active'
    allowTracing: false
  }
}

module site 'modules/static-web-app.bicep' = {
  name: '${appName}-swa'
  params: {
    name: siteName
    location: location
    skuName: skuName
    appSettings: union(appSettings, {
      BFF_BASE_URL: empty(bffBaseUrl) ? '${apim.properties.gatewayUrl}/${bffName}${apimApiSuffix}' : bffBaseUrl
    })
    secretAppSettings: {
      BFF_SUBSCRIPTION_KEY: bffSubscription.listSecrets().primaryKey
    }
    tags: tags
  }
}

output staticWebAppName string = site.outputs.name
output defaultHostname string = site.outputs.defaultHostname
