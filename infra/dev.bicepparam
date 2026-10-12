using './main.bicep'

// dev: deployed automatically on every push to dev.
param appName = 'nextjs1'
param environmentName = 'dev'
param environmentCode = 'd01'
param location = 'eastus2'
param apimName = 'apim-samgp-lab'
// The BFF this UI calls (published through APIM as <bffName>-api on /<bffName>). The deployment
// creates an APIM subscription for this UI scoped to that API and gives the key to the server.
param bffName = 'store-bff'
// Empty = call the BFF on the APIM gateway. To go through Front Door like VxCommerce.UI, set e.g.
// 'https://<front door host>/<bff path>'.
param bffBaseUrl = ''
param appSettings = {}
// Behind the shared Front Door (WAF, one public address). Without a custom domain the site gets its own
// azurefd.net host name; set customDomainHostName (e.g. 'orders.dev.example.com') and add the
// DNS records the pipeline prints to move it onto the company domain. The WAF is the central security
// policy's: the first run fails until the platform team adds the domain it prints to that policy.
param frontDoorProfileName = 'afd-samgp-lab'
param frontDoorEndpointName = 'afd-samgp-lab-shared'
param customDomainHostName = ''
param tags = {
  ApplicationCode: 'LAB'
  ApplicationName: 'LAB'
  Environment: 'Dev'
  ManagedBy: 'backstage'
  SourceRepository: 'sampgreenwell-cyber/nextjs1'
}
