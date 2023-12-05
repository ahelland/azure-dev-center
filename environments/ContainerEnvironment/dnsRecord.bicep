param zone string
param recordName string
param ipAddress string

resource dnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: zone
}

resource record 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: dnsZone
  name: recordName
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: ipAddress
      }
    ]
  }
}
