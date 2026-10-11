using './main.bicep'

// dev: deployed automatically on every push to dev.
param appName = 'nextjs1'
param environmentName = 'dev'
param environmentCode = 'd01'
param location = 'eastus2'
param apimName = 'apim-samgp-lab'
// The BFF this UI calls (published through APIM as <bffName>-api on /<bffName>). The deployment
// creates an APIM subscription for this UI scoped to that API and gives the key to the server.
param bffName = 'springboot1'
// Empty = call the BFF on the APIM gateway. To go through Front Door like VxCommerce.UI, set e.g.
// 'https://<front door host>/<bff path>'.
param bffBaseUrl = ''
param appSettings = {}
param tags = {
  ApplicationCode: 'LAB'
  ApplicationName: 'LAB'
  Environment: 'Dev'
  ManagedBy: 'backstage'
  SourceRepository: 'sampgreenwell-cyber/nextjs1'
}
