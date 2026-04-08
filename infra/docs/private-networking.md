# Private Networking Upgrade Guide

This document covers upgrading from the public baseline deployment to private networking with Private Endpoints, Private DNS Zones, and (optionally) Azure DNS Private Resolver for hybrid scenarios.

---

## When You Need Private Networking

| Scenario | Public Baseline OK? | Private Networking Required? |
|----------|---------------------|------------------------------|
| Learning / demo / POC | ✅ Yes | No |
| Dev/test with non-sensitive data | ✅ Yes | Recommended |
| Production with business data | ❌ No | ✅ Yes |
| Regulated industry (healthcare, finance) | ❌ No | ✅ Yes |
| On-premises hybrid connectivity | ❌ No | ✅ Yes (+ DNS Resolver) |

---

## What Changes

| Component | Public Baseline | Private Networking |
|-----------|----------------|-------------------|
| Service endpoints | Public URLs | Private Endpoints in VNet |
| DNS resolution | Azure public DNS | Private DNS Zones linked to VNet |
| ACA | External FQDN | VNet-integrated (internal mode) |
| APIM | External mode | Internal mode (+ App Gateway/Front Door for inbound) |
| Key Vault | Public access | PE + `publicNetworkAccess: disabled` |
| ACR | Public access | PE + `publicNetworkAccess: disabled` |
| AI Foundry | Public access | PE + `publicNetworkAccess: disabled` |
| Monitoring | Public ingest | Azure Monitor Private Link Scope (AMPLS) |

---

## Network Architecture

### VNet Design

```
VNet: 10.0.0.0/16
├── aca-subnet:          10.0.0.0/23   (ACA Environment — minimum /23 required)
├── pe-subnet:           10.0.2.0/24   (Private Endpoints for all PaaS services)
├── apim-subnet:         10.0.3.0/24   (APIM internal mode)
├── dns-inbound-subnet:  10.0.4.0/28   (DNS Resolver inbound endpoint)
└── dns-outbound-subnet: 10.0.4.16/28  (DNS Resolver outbound endpoint)
```

### Subnet Sizing Notes

- **ACA**: Minimum /23 (510 IPs). ACA infrastructure reserves IPs. Undersizing causes deployment failures.
- **PE**: /24 gives 251 usable IPs. One PE per service = ~8 PEs for this architecture. Plenty of room.
- **APIM**: /24 for internal mode. APIM VNet integration requires a dedicated subnet.
- **DNS Resolver**: /28 per endpoint (minimum). Inbound and outbound need separate subnets.

---

## Private DNS Zones

Each PaaS service with a Private Endpoint requires a corresponding Private DNS Zone:

| Service | Private DNS Zone FQDN | Required? |
|---------|-----------------------|-----------|
| Key Vault | `privatelink.vaultcore.azure.net` | Yes |
| APIM | `privatelink.azure-api.net` | Yes (internal mode) |
| ACR | `privatelink.azurecr.io` | Yes |
| Azure OpenAI / AI Foundry | `privatelink.openai.azure.com` | Yes (real endpoint) |
| Cognitive Services | `privatelink.cognitiveservices.azure.com` | Yes (real endpoint) |
| Azure Monitor | `privatelink.monitor.azure.com` | Yes |
| Log Analytics (data ingest) | `privatelink.ods.opinsights.azure.com` | Yes |
| Log Analytics (OMS) | `privatelink.oms.opinsights.azure.com` | Yes |
| Log Analytics (agent) | `privatelink.agentsvc.azure-automation.net` | Yes |

### AVM Pattern Module Shortcut

Instead of creating each zone individually, use:

```bicep
module privateDnsZones 'br/public:avm/ptn/network/private-link-private-dns-zones:0.6.0' = {
  name: 'private-dns-zones'
  params: {
    location: 'global'
    virtualNetworkResourceId: vnet.outputs.resourceId
  }
}
```

This creates ALL common privatelink DNS zones and links them to your VNet in one module call.

---

## DNS Resolution Scenarios

### Scenario 1: Azure-Only (No Hybrid)

```
ACA (VNet) → Azure DNS (168.63.129.16) → Private DNS Zone → Private Endpoint IP
```

- No DNS Resolver needed.
- Private DNS Zones auto-resolve within the linked VNet.
- Simplest configuration.

### Scenario 2: Hub-Spoke (Enterprise Landing Zone)

```
Spoke VNet (app workloads) ──peering──▶ Hub VNet
                                          │
                                    Private DNS Zones
                                    (linked to Hub VNet)
```

- DNS Zones created in hub, linked to hub VNet.
- Spokes peer to hub → DNS resolution flows through peering.
- **Critical**: DNS Zones must be linked to both hub AND spoke VNets, or DNS resolution fails.

### Scenario 3: Hybrid (On-Premises ↔ Azure)

```
On-Premises DNS Server
    │
    │ Conditional Forwarder: *.privatelink.vaultcore.azure.net → DNS Resolver Inbound IP
    │
    ▼
Azure DNS Private Resolver (Inbound Endpoint: 10.0.4.4)
    │
    ▼
Private DNS Zone → Private Endpoint IP
```

- **DNS Resolver inbound endpoint**: On-premises DNS servers forward Azure private DNS queries here.
- **DNS Resolver outbound endpoint**: Azure workloads resolve on-premises DNS names through forwarding rules.
- **Cost**: ~$0.35/hr per endpoint ($252/mo for inbound + outbound).

### Scenario 4: Custom DNS Forwarding

```
Azure DNS Private Resolver (Outbound Endpoint)
    │
    │ Forwarding Ruleset: *.corp.contoso.com → 10.100.0.4 (on-prem DNS)
    │
    ▼
On-Premises DNS Server
```

- Use when Azure workloads need to resolve on-premises Active Directory or custom DNS names.
- Configure via DNS Forwarding Ruleset linked to outbound endpoint.

---

## Deployment Toggle

### Bicep

In `params/dev.private.bicepparam`:
```bicep
param enablePrivateNetworking = true
param vnetAddressPrefix = '10.0.0.0/16'
param acaSubnetPrefix = '10.0.0.0/23'
param peSubnetPrefix = '10.0.2.0/24'
param apimSubnetPrefix = '10.0.3.0/24'
param enableDnsResolver = false  // true only for hybrid
```

### Terraform

In `envs/dev.private.tfvars`:
```hcl
enable_private_networking = true
vnet_address_prefix       = "10.0.0.0/16"
aca_subnet_prefix         = "10.0.0.0/23"
pe_subnet_prefix          = "10.0.2.0/24"
apim_subnet_prefix        = "10.0.3.0/24"
enable_dns_resolver       = false  # true only for hybrid
```

---

## Common DNS Pitfalls

| Problem | Cause | Fix |
|---------|-------|-----|
| `nslookup` returns public IP for a PE-protected service | Private DNS Zone not linked to VNet | Add VNet link to the Private DNS Zone |
| ACA can't reach Key Vault after PE is created | ACA not VNet-integrated | Deploy ACA Environment with VNet integration |
| On-prem can't resolve `*.privatelink.*` FQDNs | No DNS Resolver inbound endpoint, or missing conditional forwarder | Deploy DNS Resolver + configure on-prem conditional forwarder |
| DNS resolution works from VM but not from ACA | ACA uses different DNS source | Verify ACA Environment is in the same VNet as PE subnet |
| Wrong PE DNS zone (e.g., `openai` vs `cognitiveservices`) | Azure AI services have multiple zone types | Use `privatelink.openai.azure.com` for OpenAI-specific, `privatelink.cognitiveservices.azure.com` for general Cognitive Services |
| Stale DNS cache after PE creation | Client cached old (public) DNS response | Restart the container/pod, or wait for TTL expiry |
| Hub-spoke: spoke can't resolve PE FQDNs | Private DNS Zone linked only to hub, not spoke | Link Private DNS Zone to spoke VNet, or ensure DNS flows through hub |

---

## Verification Commands

```bash
# Verify Private DNS Zone exists and is linked
az network private-dns zone list --resource-group <rg-name> -o table
az network private-dns link vnet list --resource-group <rg-name> --zone-name privatelink.vaultcore.azure.net -o table

# Verify PE is created and connected
az network private-endpoint list --resource-group <rg-name> -o table

# Test DNS resolution from within the VNet (e.g., from a test VM or ACA exec)
nslookup <keyvault-name>.vault.azure.net
# Expected: 10.0.2.x (private IP), NOT a public IP

# Verify DNS Resolver (if deployed)
az dns-resolver show --name <resolver-name> --resource-group <rg-name>
az dns-resolver inbound-endpoint list --dns-resolver-name <resolver-name> --resource-group <rg-name> -o table
```

---

## Cost Impact

| Component | Monthly Cost (approx) |
|-----------|----------------------|
| VNet | Free |
| Private Endpoints (~8) | ~$56/mo ($7/PE/mo) |
| Private DNS Zones (~9) | ~$2.25/mo ($0.25/zone/mo) |
| DNS Resolver (inbound + outbound) | ~$504/mo ($0.35/hr × 2 endpoints × 720 hrs) |
| Total (without DNS Resolver) | ~$58/mo |
| Total (with DNS Resolver) | ~$562/mo |

> **Recommendation**: Always deploy PEs + DNS Zones for production. Deploy DNS Resolver only for hybrid scenarios with on-premises connectivity.
