using './main.bicep'

param namePrefix = 'agentrc'
param containerImageTag = 'latest'
param enableSharing = true
param enableAppInsights = true
param containerStartupStrategy = 'keep-warm'
param customDomain = 'agentrc.isainative.dev'
param customDomainCertReady = false // Set to true after DNS CNAME + TXT records are verified
param tags = {
  application: 'agentrc-webapp'
  managedBy: 'bicep'
  environment: 'production'
}
