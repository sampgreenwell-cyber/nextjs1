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

@description('Existing Front Door profile to publish through. Empty = no Front Door (the site is public on its azurestaticapps.net name).')
param frontDoorProfileName string = ''

@description('Resource group of the Front Door profile')
param frontDoorResourceGroup string = resourceGroup().name

@description('Custom domain for this site (DNS records are printed by the pipeline). Empty = its own azurefd.net host name.')
param customDomainHostName string = ''

@description('Existing shared Front Door endpoint that custom domains attach to')
param frontDoorEndpointName string = ''

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

// The site's slice of the shared Front Door: its own endpoint (or custom domain), origin and route. The
// pipeline then locks the Static Web App to this Front Door (staticwebapp.config.json). The WAF comes from
// the central security policy: the platform team adds wafDomainId to it once, and until then the
// pipeline fails.
module frontDoor 'modules/front-door-site.bicep' = if (!empty(frontDoorProfileName)) {
  name: '${appName}-frontdoor'
  scope: resourceGroup(frontDoorResourceGroup)
  params: {
    profileName: frontDoorProfileName
    name: siteName
    originHostName: site.outputs.defaultHostname
    probePath: '/api/health'
    customDomainHostName: customDomainHostName
    endpointName: frontDoorEndpointName
    tags: tags
  }
}

output staticWebAppName string = site.outputs.name
output defaultHostname string = site.outputs.defaultHostname
@description('Where users reach the site: the Front Door host name, or the Static Web App\'s own')
output publicHostname string = empty(frontDoorProfileName) ? site.outputs.defaultHostname : frontDoor!.outputs.hostName
@description('Front Door ID the Static Web App must require (X-Azure-FDID). Empty = not behind Front Door.')
output frontDoorId string = empty(frontDoorProfileName) ? '' : frontDoor!.outputs.frontDoorId
output dnsCnameTarget string = empty(frontDoorProfileName) ? '' : frontDoor!.outputs.dnsCnameTarget
output dnsValidationToken string = empty(frontDoorProfileName) ? '' : frontDoor!.outputs.dnsValidationToken
@description('Domain the platform team adds to the central Front Door security policy (WAF). Empty = not behind Front Door.')
output wafDomainId string = empty(frontDoorProfileName) ? '' : frontDoor!.outputs.wafDomainId
