# Architecture Notes

## Overview

This reference deploys a minimal AI-capable platform on Azure:

```
User → ACA (chatbot) → APIM (gateway) → Backend (stub or AI Foundry)
```

All observability flows to Log Analytics + App Insights.  
All secrets (if any) stored in Key Vault with RBAC.  
All service-to-service auth uses Managed Identity.

## Key Design Decisions

See [decisions.md](decisions.md) for the full ADR log.

## Network Topology

### Public Baseline (Default)

- All services use public endpoints
- APIM in external mode (public gateway URL)
- ACA externally accessible (FQDN assigned by Azure)
- No VNet, no Private Endpoints, no DNS Zones

### Private Networking (Toggle)

See [private-networking.md](private-networking.md) for the full upgrade path.
