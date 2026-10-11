// Reusable module: one site's slice of an existing Azure Front Door profile. Creates only objects owned
// by this site (endpoint or custom domain, origin group, origin, route, WAF association), never edits
// shared ones, so service repos can't overwrite each other or the central Front Door config. Based on
// the UI pieces of Approach1/FrontDoor/main.bicep in the CLX repo.
//
// Two modes:
//   customDomainHostName empty -> the site gets its own endpoint (<name>-<hash>.z01.azurefd.net).
//     Standard profiles allow 10 endpoints; good for a new site before DNS exists.
//   customDomainHostName set   -> the site joins the shared endpoint (endpointName) on its own domain,
//     with a managed certificate. DNS needs a TXT validation record and a CNAME (see outputs).
//
// Deploy this module into the Front Door profile's resource group.

@description('Existing Front Door profile (Standard or Premium)')
param profileName string

@description('Prefix for this site\'s Front Door objects, e.g. ditac-clx-swa-orders-d01')
param name string

@description('Origin host name, e.g. the Static Web App default host name')
param originHostName string

@description('Health probe path on the origin')
param probePath string = '/'

@description('Custom domain, e.g. orders.dev-clxstore.visionx.solutions. Empty = own azurefd.net endpoint.')
param customDomainHostName string = ''

@description('Existing shared endpoint to attach the custom domain to. Required with customDomainHostName.')
param endpointName string = ''

@description('Existing WAF policy (Microsoft.Network/FrontDoorWebApplicationFirewallPolicies) in this resource group. Empty = no WAF.')
param wafPolicyName string = ''

@description('Tags for the endpoint')
param tags object = {}

var useCustomDomain = !empty(customDomainHostName)

resource profile 'Microsoft.Cdn/profiles@2025-06-01' existing = {
  name: profileName
}

resource sharedEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2025-06-01' existing = if (useCustomDomain) {
  parent: profile
  name: endpointName
}

resource ownEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2025-06-01' = if (!useCustomDomain) {
  parent: profile
  name: name
  location: 'global'
  tags: tags
  properties: {
    enabledState: 'Enabled'
  }
}

resource customDomain 'Microsoft.Cdn/profiles/customDomains@2025-06-01' = if (useCustomDomain) {
  parent: profile
  name: replace(customDomainHostName, '.', '-')
  properties: {
    hostName: customDomainHostName
    tlsSettings: {
      certificateType: 'ManagedCertificate'
      minimumTlsVersion: 'TLS12'
      cipherSuiteSetType: 'TLS12_2023'
    }
  }
}

resource originGroup 'Microsoft.Cdn/profiles/originGroups@2025-06-01' = {
  parent: profile
  name: '${name}-og'
  properties: {
    sessionAffinityState: 'Disabled'
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: probePath
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 120
    }
  }
}

resource origin 'Microsoft.Cdn/profiles/originGroups/origins@2025-06-01' = {
  parent: originGroup
  name: '${name}-origin'
  properties: {
    hostName: originHostName
    originHostHeader: originHostName
    httpPort: 80
    httpsPort: 443
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
    priority: 1
    weight: 1000
  }
}

// Same route settings as the CLX UI route: HTTPS to the origin, HTTP redirected, everything matched.
resource ownRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2025-06-01' = if (!useCustomDomain) {
  parent: ownEndpoint
  name: '${name}-route'
  dependsOn: [
    origin
  ]
  properties: {
    enabledState: 'Enabled'
    forwardingProtocol: 'HttpsOnly'
    httpsRedirect: 'Enabled'
    linkToDefaultDomain: 'Enabled'
    patternsToMatch: [
      '/*'
    ]
    supportedProtocols: [
      'Http'
      'Https'
    ]
    originGroup: {
      id: originGroup.id
    }
  }
}

resource domainRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2025-06-01' = if (useCustomDomain) {
  parent: sharedEndpoint
  name: '${name}-route'
  dependsOn: [
    origin
  ]
  properties: {
    enabledState: 'Enabled'
    forwardingProtocol: 'HttpsOnly'
    httpsRedirect: 'Enabled'
    linkToDefaultDomain: 'Disabled'
    patternsToMatch: [
      '/*'
    ]
    supportedProtocols: [
      'Http'
      'Https'
    ]
    originGroup: {
      id: originGroup.id
    }
    customDomains: [
      {
        id: customDomain.id
      }
    ]
  }
}

resource wafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2022-05-01' existing = if (!empty(wafPolicyName)) {
  name: wafPolicyName
}

// The site's own security policy pointing at the shared WAF policy: a domain belongs to one security
// policy, so adding this site to the central one would mean editing a shared object.
resource securityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2025-06-01' = if (!empty(wafPolicyName)) {
  parent: profile
  name: '${name}-waf'
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
        id: wafPolicy.id
      }
      associations: [
        {
          domains: [
            {
              id: useCustomDomain ? customDomain.id : ownEndpoint.id
            }
          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
    }
  }
}

@description('Public host name: the custom domain, or the site\'s own azurefd.net host name')
output hostName string = useCustomDomain ? customDomainHostName : ownEndpoint!.properties.hostName

@description('This profile\'s Front Door ID: origins accept only requests with X-Azure-FDID set to it')
output frontDoorId string = profile.properties.frontDoorId

@description('With a custom domain: the CNAME target (the shared endpoint) and the TXT validation token for _dnsauth.<domain>')
output dnsCnameTarget string = useCustomDomain ? sharedEndpoint!.properties.hostName : ''
output dnsValidationToken string = useCustomDomain ? customDomain!.properties.validationProperties.validationToken : ''
