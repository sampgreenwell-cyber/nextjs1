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
param tags = {
  ApplicationCode: 'LAB'
  ApplicationName: 'LAB'
  Environment: 'QA'
  ManagedBy: 'backstage'
  SourceRepository: 'sampgreenwell-cyber/nextjs1'
}
