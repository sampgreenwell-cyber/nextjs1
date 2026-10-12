using './main.bicep'

// qa: deployed on every push to qa after approval (promote with a pull request from dev).
param appName = 'nextjs1'
param environmentName = 'qa'
param environmentCode = 'q01'
param location = 'eastus2'
param apimName = 'apim-samgp-lab'
param bffName = 'store-bff'
// Lab: dev and qa share one APIM, so the BFF's qa API is <bffName>-qa-api on /<bffName>-qa.
param apimApiSuffix = '-qa'
param bffBaseUrl = ''
param appSettings = {}
// Behind the shared Front Door (WAF, one public address). Without a custom domain the site gets its own
// azurefd.net host name; set customDomainHostName (e.g. 'orders.qa.example.com') and add the
// DNS records the pipeline prints to move it onto the company domain. The WAF is the central security
// policy's: the first run fails until the platform team adds the domain it prints to that policy.
param frontDoorProfileName = 'afd-samgp-lab'
param frontDoorEndpointName = 'afd-samgp-lab-shared'
param customDomainHostName = ''
param tags = {
  ApplicationCode: 'LAB'
  ApplicationName: 'LAB'
  Environment: 'QA'
  ManagedBy: 'backstage'
  SourceRepository: 'sampgreenwell-cyber/nextjs1'
}
