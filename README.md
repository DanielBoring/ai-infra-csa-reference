# AI Infrastructure CSA Reference — Runbook & Deployable Baseline

> An opinionated reference repository for Infrastructure Cloud Solution Architects (CSAs) enabling AI workloads on Azure. Runbook-first guidance mapped to the Cloud Adoption Framework (CAF) and Well-Architected Framework (WAF), backed by a deployable infrastructure baseline using Azure Verified Modules (AVM) in **both Bicep and Terraform**.

**New to this?** Start with the [Tutorial](docs/tutorial.md) for a guided, step-by-step walkthrough.

---

## Table of Contents

1. [Purpose & Audience](#1-purpose--audience)
2. [Responsibility Matrix: Infra CSA vs App CSA](#2-responsibility-matrix-infra-csa-vs-app-csa)
3. [AI Workload Discovery Checklist](#3-ai-workload-discovery-checklist)
4. [Reference Architecture](#4-reference-architecture)
5. [CAF Pillar Mapping for AI](#5-caf-pillar-mapping-for-ai)
6. [WAF Pillar Mapping for AI](#6-waf-pillar-mapping-for-ai)
7. [Infrastructure Baseline](#7-infrastructure-baseline)
8. [Deployment Guide](#8-deployment-guide)
9. [Foundry Stub Default & Upgrade to Real Endpoint](#9-foundry-stub-default--upgrade-to-real-endpoint)
10. [APIM Policies Deep Dive](#10-apim-policies-deep-dive)
11. [Cost Optimization](#11-cost-optimization)
12. [Verification & Troubleshooting](#12-verification--troubleshooting)
13. [Tests & CI](#13-tests--ci)
14. [Repo Structure](#14-repo-structure)
15. [Contributing & License](#15-contributing--license)

---

## 1. Purpose & Audience

### What This Repo Is

This repository is a **runbook + deployable baseline** designed for Infrastructure CSAs who partner with App CSAs to deliver AI workloads on Azure. It provides:

- A **README-first runbook** that distills AI workload infrastructure needs through the lens of CAF and WAF.
- A **deployable infrastructure baseline** using Azure Verified Modules (AVM) in both Bicep and Terraform.
- An **end-to-end working example**: Azure Container Apps (ACA) running a minimal Node.js chatbot → API Management (APIM) → Foundry API Stub (default), with a documented upgrade path to a real Azure AI Foundry endpoint.

### Who This Is For

| Audience | How to Use This Repo |
|----------|---------------------|
| **Infrastructure CSA** | Use as a runbook for discovery, architecture decisions, and platform delivery. Deploy the baseline, then onboard your app team. |
| **App CSA** | Understand what the platform provides and where your responsibilities begin. Focus on the app, not the plumbing. |
| **Junior Engineer** | Start with the [Tutorial](docs/tutorial.md). It explains every concept before asking you to do anything. |
| **Platform Engineering Team** | Fork and customize. The IaC is modular and parameterized for your landing zone. |

### Design Principles

- **Stub-first**: Default deployment uses a Foundry API stub — no AI Foundry prerequisites needed. Anyone can deploy and get an end-to-end working system.
- **APIM as the stable abstraction**: The app always calls APIM. Only the APIM backend changes when swapping stub → real endpoint.
- **Secure by default**: Managed Identity, no secrets in repo, Key Vault references where needed.
- **Public baseline, private upgrade**: Public endpoints by default for accessibility. Private networking (VNet, Private Endpoints, Private DNS Zones, DNS Resolver) documented as a toggleable upgrade.
- **Dual IaC**: Both Bicep and Terraform, same resources, same parameterization. Use whichever your team prefers.

---

## 2. Responsibility Matrix: Infra CSA vs App CSA

Clear ownership boundaries prevent gaps and duplication. This matrix defines the split for AI workloads.

| Concern | Infra CSA (Platform) | App CSA (Application) | Shared |
|---------|---------------------|-----------------------|--------|
| **Identity & RBAC** | Managed Identity provisioning, RBAC role assignments, workload identity federation | App-level auth flows, user identity claims | Service principal scoping |
| **Networking** | VNet/subnet design, NSGs, Private Endpoints, DNS zones, egress controls, APIM placement | App ingress requirements, connection strings, SDK config | Endpoint exposure decisions |
| **Observability** | Log Analytics, App Insights provisioning, diagnostic settings, dashboard templates | Custom app telemetry, prompt/response logging decisions, business metrics | Alert threshold definitions |
| **Security** | Key Vault provisioning, TLS, network segmentation, DDoS protection, policy guardrails | Prompt injection defenses, data exfiltration controls, input validation | Threat model review |
| **Cost** | SKU/tier selection, autoscaling rules, budget alerts, reservation recommendations | Token optimization, caching strategy decisions, prompt engineering efficiency | Usage forecasting |
| **Governance** | Azure Policy, tagging standards, approved SKUs/regions, resource locks | Data handling classification, compliance attestation for app data | Change control process |
| **Deployment** | IaC modules, CI/CD pipeline, environment promotion | App build/test, container image, feature flags | Release gating criteria |
| **AI-Specific** | Model endpoint networking, APIM policies for AI, GPU/capacity planning | Model selection, fine-tuning, prompt design, RAG pipeline | Responsible AI review |

### Handoff Protocol

1. Infra CSA deploys baseline (this repo) and validates connectivity.
2. Infra CSA provides App CSA with: APIM endpoint URL, Managed Identity client ID, App Insights connection string, Key Vault URI.
3. App CSA configures app to call APIM endpoint (not the AI backend directly).
4. Both CSAs review threat model and cost forecasts together.

---

## 3. AI Workload Discovery Checklist

Use this checklist during initial engagement with the app team. Each section maps to CAF/WAF pillars.

### 3.1 Identity & Access

*CAF: Ready, Govern | WAF: Security*

- [ ] What identities need access to the AI endpoint? (Users, services, pipelines)
- [ ] Is Managed Identity available for all calling services? (ACA ✓, App Service ✓, VMs require config)
- [ ] Are there separation-of-duty requirements? (Deployer ≠ operator ≠ data reader)
- [ ] Does the AI model need access to customer data stores? (Cosmos DB, Storage, SQL)
- [ ] Is workload identity federation needed? (GitHub Actions OIDC, external identity providers)
- [ ] What RBAC roles are needed? (`Cognitive Services OpenAI User` for inference, `Contributor` for management)

### 3.2 Networking

*CAF: Ready, Govern | WAF: Security, Reliability*

- [ ] Public or private endpoints for the AI service? (Public = simpler; Private = required for regulated workloads)
- [ ] Which services need Private Endpoints? (Key Vault, APIM, AI Foundry, ACR, Monitor)
- [ ] DNS resolution strategy? (Azure-only with Private DNS Zones, or hybrid with DNS Resolver?)
- [ ] Is there a hub VNet with centralized Private DNS Zones? (Enterprise landing zone pattern)
- [ ] Will on-premises workloads need to resolve Azure Private Endpoint FQDNs? (Requires DNS Resolver inbound endpoint)
- [ ] Does ACA need VNet integration? (Required if ACA must reach PE-protected services)
- [ ] APIM deployment mode? (External = public inbound; Internal = private inbound, requires App Gateway/Front Door)
- [ ] Egress control requirements? (NAT Gateway for stable outbound IP, Azure Firewall for FQDN filtering, NSG-only for basic)
- [ ] Cross-region or multi-region requirements? (Traffic Manager, Front Door, or regional APIM)

### 3.3 Data Protection

*CAF: Govern | WAF: Security*

- [ ] Data classification of prompts and responses? (Public, Confidential, Highly Confidential)
- [ ] Encryption requirements beyond platform defaults? (CMK via Key Vault for data at rest)
- [ ] Are prompts/responses logged? If so, where and for how long? (Privacy-aware logging — see §10.3)
- [ ] PII/PHI in prompts? (Impacts caching policy — never cache PII. See §10.4)
- [ ] Data residency requirements? (Restricted regions for AI Foundry deployment)
- [ ] Audit trail requirements? (Key Vault audit logs, APIM diagnostic logs, AI Foundry usage logs)

### 3.4 Threat Model

*CAF: Govern | WAF: Security*

- [ ] Prompt injection risks? (App-layer defense; APIM can add input validation policies)
- [ ] Data leakage via model responses? (Grounding data exposure, training data extraction)
- [ ] Model endpoint abuse? (Rate limiting via APIM, subscription keys, IP filtering)
- [ ] Supply chain risks? (Container image provenance, dependency scanning, model provenance)
- [ ] DDoS/volumetric attack surface? (APIM rate limiting, Azure DDoS Protection on VNet)
- [ ] Who can deploy or change AI model configurations? (RBAC + resource locks)

### 3.5 Observability

*CAF: Manage | WAF: Operational Excellence, Cost Optimization*

- [ ] What metrics matter? (Token usage, latency P50/P95/P99, error rates, cache hit ratio)
- [ ] Dashboard requirements? (Azure Monitor workbooks, Grafana, Power BI)
- [ ] Alerting thresholds? (Token spend per day, error rate spikes, latency degradation)
- [ ] Log retention period? (30 days interactive, 90 days archive, 365+ for compliance — cost tradeoff)
- [ ] Privacy-aware logging posture? (Log metadata but redact prompt content? Log everything? Log nothing?)
- [ ] Distributed tracing needs? (Correlation IDs across ACA → APIM → AI endpoint)

### 3.6 Governance

*CAF: Govern | WAF: Operational Excellence*

- [ ] Tagging strategy? (At minimum: environment, project, cost-center, owner, data-classification)
- [ ] Approved SKUs and regions for AI services? (Azure Policy to enforce)
- [ ] Budget and spending limits? (Consumption budget alerts at 50%, 80%, 100%)
- [ ] Resource locks on production resources? (CanNotDelete on Key Vault, AI endpoint)
- [ ] Change control process? (IaC-only changes via PR, no portal drift)
- [ ] Responsible AI review completed? (Microsoft RAI checklist, transparency notes)

---

## 4. Reference Architecture

### Public Baseline (Default)

```
┌─────────────────────────────────────────────────────────────┐
│                        Azure                                │
│                                                             │
│  ┌─────────┐    ┌──────────────┐    ┌───────────────────┐   │
│  │ ACA     │───▶│ APIM         │───▶│ Foundry Stub      │   │
│  │ (chatbot│    │ • Auth       │    │ (mock-response     │   │
│  │  app)   │    │ • Rate limit │    │  policy in APIM)   │   │
│  └─────────┘    │ • Cache      │    └───────────────────┘   │
│       │         │ • Logging    │              │              │
│       │         └──────────────┘     ┌───────────────────┐  │
│       │                │             │ OR: Real Azure AI  │  │
│       ▼                ▼             │ Foundry Endpoint   │  │
│  ┌─────────┐    ┌──────────────┐    └───────────────────┘  │
│  │ Managed │    │ App Insights │                            │
│  │ Identity│    │ + Log        │    ┌───────────────────┐   │
│  └─────────┘    │   Analytics  │    │ Key Vault         │   │
│                 └──────────────┘    │ (RBAC, no secrets) │  │
│                                     └───────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**Data flow**: User → ACA chatbot app (`POST /chat`) → APIM (policy chain: auth → rate-limit → cache-lookup → logging) → backend (stub or real) → response back through APIM (cache-store → log) → ACA → User.

### Private Networking Variant

```
┌──────────────────────────────────────────────────────────────────────┐
│  Azure VNet (10.0.0.0/16)                                           │
│                                                                      │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────────────┐  │
│  │ ACA Subnet     │  │ PE Subnet      │  │ DNS Resolver Subnet    │  │
│  │ 10.0.0.0/23    │  │ 10.0.2.0/24    │  │ 10.0.3.0/28 (inbound) │  │
│  │                │  │                │  │ 10.0.3.16/28 (outbound)│  │
│  │ ┌────────────┐ │  │ PE: Key Vault  │  │                        │  │
│  │ │ ACA        │─┼──│ PE: APIM       │  │ ┌────────────────────┐ │  │
│  │ │ (chatbot)  │ │  │ PE: ACR        │  │ │ DNS Private        │ │  │
│  │ └────────────┘ │  │ PE: AI Foundry │  │ │ Resolver           │ │  │
│  └────────────────┘  │ PE: Monitor    │  │ │ (hybrid only)      │ │  │
│                      └────────────────┘  │ └────────────────────┘ │  │
│                                          └────────────────────────┘  │
│  Private DNS Zones (linked to VNet):                                 │
│  • privatelink.vaultcore.azure.net        • privatelink.azure-api.net│
│  • privatelink.azurecr.io                 • privatelink.openai.azure.│
│  • privatelink.cognitiveservices.azure.com • privatelink.monitor.azure│
│  • privatelink.ods.opinsights.azure.com   • privatelink.oms.opinsight│
│  • privatelink.agentsvc.azure-automation.net                         │
│                                                                      │
│  ┌──────────────────────────────────────┐                            │
│  │ On-Premises (via ExpressRoute/VPN)   │                            │
│  │ DNS conditional forwarder ──────────▶│ DNS Resolver inbound EP    │
│  └──────────────────────────────────────┘                            │
└──────────────────────────────────────────────────────────────────────┘
```

### Component Roles

| Component | Role | Why |
|-----------|------|-----|
| **ACA** | Runs the chatbot container | Serverless, scales to zero, Managed Identity, VNet integration capable |
| **APIM** | API gateway / front door | Centralized auth, rate limiting, caching, logging, backend abstraction |
| **Key Vault** | Stores non-MI secrets (if any) | RBAC model, audit logging, CMK support, no secrets in code |
| **Log Analytics** | Central log sink | KQL queries, retention policies, cross-resource correlation |
| **App Insights** | APM for the chatbot + APIM | Distributed tracing, latency metrics, error tracking |
| **Managed Identity** | Secretless auth | ACA → APIM, APIM → AI Foundry, ACA → Key Vault |
| **Foundry Stub** | Mock AI backend | Zero-dependency deployment; validates wiring without AI prerequisites |

---

## 5. CAF Pillar Mapping for AI

Each CAF pillar is distilled to its AI workload essentials and mapped to what this repo delivers.

### 5.1 Strategy

*Define AI scenarios, scope boundaries, success metrics, and risk appetite.*

- **Scenario scoping**: This repo assumes a conversational AI scenario (chatbot). The pattern generalizes to any request/response AI workload (search, summarization, classification).
- **Risk appetite**: Default posture is "public but hardened" (APIM rate limits, Managed Identity, Key Vault). Upgrade to private networking for regulated workloads.
- **Success metrics**: First successful end-to-end call (stub), then swap to real endpoint, then measure latency/cost/errors.

### 5.2 Plan

*Translate AI scenario into requirements and rollout plan.*

- **Requirements captured**: The Discovery Checklist (§3) maps directly to Plan — identity, network, observability, cost, environments.
- **Rollout plan**: Stub deploy → validate wiring → upgrade to real endpoint → add private networking → production hardening.
- **Environment strategy**: Dev/Prod parameter files provided. Extend to staging as needed.

### 5.3 Ready

*Implement landing zone foundations.*

- **Identity/RBAC**: Managed Identity + role assignments provisioned via IaC. Least-privilege roles (`Cognitive Services OpenAI User`, not `Contributor`).
- **Policy guardrails**: Documented Azure Policy recommendations (approved SKUs, regions, tagging). Not deployed by default to keep the sample portable.
- **Network segmentation**: Public baseline deployed; private networking documented with VNet, subnets, PEs, DNS Zones.
- **Logging**: Log Analytics + App Insights provisioned and wired to all resources via diagnostic settings.
- **Key management**: Key Vault with RBAC access model. No access policies.

### 5.4 Adopt

*Deliver platform + reference implementation and enable app team onboarding.*

- **Platform delivery**: This repo IS the reference implementation. Deploy, validate, hand off.
- **IaC**: Bicep and Terraform, AVM-based, parameterized per environment.
- **CI/CD**: GitHub Actions validates IaC and runs tests on every push.
- **App wiring**: The chatbot shows exactly how an app consumes the platform (APIM endpoint, MI auth, environment variables).

### 5.5 Govern

*Enforce compliance, tagging, cost controls, data handling, change control.*

- **Compliance**: Policy-as-code recommendations documented. Resource locks on production Key Vault.
- **Tagging**: Standard tags applied to all resources (environment, project, cost-center, owner).
- **Cost controls**: Consumption budget with alerts. Token usage telemetry via APIM policies.
- **Data handling**: Privacy-aware logging guidance. Caching policy skips PII-flagged requests.
- **Change control**: All changes via IaC/PR. No portal modifications.

### 5.6 Manage

*Operate with SLOs, monitoring, incident response, patching, optimization.*

- **Monitoring**: App Insights dashboards, Log Analytics queries for token usage, error rates, latency.
- **Alerting**: Action groups for budget breaches, error spikes, latency degradation.
- **Incident response**: Troubleshooting guide (§12) covers common failure modes.
- **Optimization**: Cost optimization section (§11) covers caching, right-sizing, retention.

---

## 6. WAF Pillar Mapping for AI

### 6.1 Security

*Identity boundaries, secretless auth, data protection, AI-specific threats.*

| Control | Implementation | Notes |
|---------|---------------|-------|
| Secretless auth | Managed Identity for ACA → APIM → AI Foundry | No API keys, no connection strings in code |
| Key management | Key Vault with RBAC (not access policies) | Soft delete + purge protection in prod |
| Network segmentation | NSGs, optional PEs + Private DNS Zones | Public baseline; private networking toggle |
| API abuse prevention | APIM rate limiting (60 req/min default) | Adjustable per subscription tier |
| Prompt injection defense | App-layer responsibility; APIM can validate input | Document in threat model section |
| Data exfiltration control | APIM logging with PII redaction guidance | Never log full prompt/response by default |
| TLS | Enforced on all endpoints | APIM, ACA, Key Vault default to TLS 1.2+ |
| DDoS | APIM rate limiting + optional Azure DDoS Plan | Network-level + application-level |

### 6.2 Reliability

*Retries, timeouts, circuit breakers, dependency isolation, fallbacks.*

| Control | Implementation | Notes |
|---------|---------------|-------|
| APIM retry policy | Configurable retry with exponential backoff | Default: 3 retries, 1s/2s/4s |
| APIM timeout | 30s default, adjustable per operation | AI endpoints can be slow; tune for model |
| Circuit breaker | APIM built-in circuit breaker policy | Opens after N consecutive failures |
| ACA health probes | `/health` endpoint with liveness + readiness | Automatic restart on failure |
| Scale-to-zero recovery | ACA cold start ~10s | Document expected latency |
| Dependency isolation | APIM sits between app and AI backend | Backend failure doesn't crash the app |

### 6.3 Performance Efficiency

*Latency optimization, caching, autoscaling.*

| Control | Implementation | Notes |
|---------|---------------|-------|
| Response caching | APIM cache-lookup/cache-store policies | **Only for non-PII, non-personalized prompts** |
| Cache key design | Hash of prompt text (sanitized) | Exclude user-identifying fields |
| Autoscaling | ACA KEDA-based HTTP scaling | Scale 0→N based on concurrent requests |
| Cold start mitigation | Min replicas = 1 for prod | Cost tradeoff: $0 at zero vs. ~$X/mo for 1 |
| Backend latency tracking | APIM emit-metric policy | Custom metric for AI response time |

### 6.4 Cost Optimization

*Token reduction, rate limits, usage telemetry, right-sizing.*

| Control | Implementation | Notes |
|---------|---------------|-------|
| Response caching | Reduces duplicate AI calls by 20-50%+ | Only for cacheable, non-PII prompts |
| Rate limits | 60 req/min default; prevents runaway costs | Tune per environment |
| Token telemetry | APIM extracts token counts from AI responses | Dashboard for cost attribution |
| Right-sizing | ACA Consumption plan (pay-per-use) | No idle compute cost at zero scale |
| APIM tier | Consumption (sample) → Standard v2 (prod) | Document cost/feature tradeoffs |
| Log retention | 30 days interactive (default) | Extend only if compliance requires; archive tier |
| Budget alerts | Consumption budget at 50%, 80%, 100% | Action group notifies team |

### 6.5 Operational Excellence

*IaC, CI/CD, runbooks, observability, repeatable deployments.*

| Control | Implementation | Notes |
|---------|---------------|-------|
| IaC | Bicep + Terraform (AVM-based) | Version-controlled, PR-reviewed changes |
| CI/CD | GitHub Actions: validate → test → (plan) | No auto-apply; manual approval for prod |
| Observability | App Insights + Log Analytics + APIM diagnostics | Correlated with request trace IDs |
| Runbooks | This README + Tutorial + Troubleshooting guide | Operational knowledge captured in code |
| Testing | Unit tests + smoke tests + IaC validation | Every push validates the whole stack |
| Environments | Dev/Prod param files | Same IaC, different parameters |

### 6.6 Sustainability

*Efficient scaling, avoid overprovisioning, appropriate retention.*

- **Scale to zero**: ACA Consumption plan means zero compute when idle.
- **Caching**: Fewer AI calls = less compute on the AI backend.
- **Log retention**: Don't retain logs longer than needed. Archive tier for long-term.
- **Right-sized APIM**: Consumption tier for dev/test; upgrade only when needed.

---

## 7. Infrastructure Baseline

### Resources Provisioned

| Resource | AVM Module (Bicep) | Purpose | Default Tier |
|----------|-------------------|---------|-------------|
| Resource Group | — (CLI/deployment scope) | Logical container | — |
| Log Analytics Workspace | `avm/res/operational-insights/workspace` | Central logging | PerGB2018 (pay-as-you-go) |
| Application Insights | `avm/res/insights/component` | APM + distributed tracing | — (consumption) |
| Key Vault | `avm/res/key-vault/vault` | Secret/key management (RBAC) | Standard |
| User-Assigned Managed Identity | `avm/res/managed-identity/user-assigned-identity` | Secretless auth | — |
| API Management | `avm/res/api-management/service` | API gateway | Consumption (dev) / Standard v2 (prod) |
| ACA Environment | `avm/res/app/managed-environment` | Container hosting environment | Consumption (serverless) |
| Container App | `avm/res/app/container-app` | Chatbot application | — (consumption) |
| Role Assignments | `avm/ptn/authorization/resource-role-assignment` | RBAC bindings | — |

### Private Networking Add-Ons (Toggle: `enablePrivateNetworking`)

| Resource | AVM Module (Bicep) | Purpose |
|----------|-------------------|---------|
| Virtual Network | `avm/res/network/virtual-network` | Network boundary + subnets |
| NSGs | `avm/res/network/network-security-group` | Subnet-level access control |
| Private Endpoints | `avm/res/network/private-endpoint` | PE per PaaS service |
| Private DNS Zones | `avm/res/network/private-dns-zone` | FQDN resolution for PEs |
| DNS Resolver | `avm/res/network/dns-resolver` | Hybrid DNS (optional) |
| DNS Forwarding Ruleset | `avm/res/network/dns-forwarding-ruleset` | Custom DNS forwarding |

### Tier Choices & Tradeoffs

| Resource | Dev/Sample | Production | Tradeoff |
|----------|-----------|------------|----------|
| **APIM** | Consumption ($0 base, per-call) | Standard v2 (~$0.67/hr) | Consumption: cold starts, no VNet. Standard v2: VNet integration, no cold starts, higher cost. |
| **ACA** | Consumption (scale to zero) | Consumption or Dedicated | Dedicated gives reserved capacity + SLA. Consumption gives cost savings. |
| **Key Vault** | Standard | Standard or Premium (HSM) | Premium only needed for HSM-backed keys. Standard covers most scenarios. |
| **Log Analytics** | PerGB2018 (30 day retention) | PerGB2018 (90+ day retention) | Longer retention = higher cost. Use archive tier for compliance. |

### Tagging Strategy

All resources are tagged with:

```json
{
  "environment": "dev|staging|prod",
  "project": "ai-infra-reference",
  "cost-center": "<your-cost-center>",
  "owner": "<team-or-individual>",
  "data-classification": "general|confidential|highly-confidential",
  "managed-by": "bicep|terraform"
}
```

---

## 8. Deployment Guide

### 8.1 Prerequisites

- **Azure CLI** ≥ 2.60.0 (`az --version`)
- **Bicep CLI** ≥ 0.28.0 (`az bicep version`) — if deploying with Bicep
- **Terraform** ≥ 1.6.0 (`terraform -version`) — if deploying with Terraform
- **Node.js** ≥ 20 LTS (`node -v`) — for running tests
- **Azure subscription** with permissions to create resources (Contributor + User Access Administrator at subscription or resource group scope)
- **No secrets needed**: All auth uses Managed Identity. No API keys to configure.

### 8.2 Deploy with Bicep

```bash
# 1. Login and set subscription
az login
az account set --subscription "<your-subscription-id>"

# 2. Create resource group (or let the template create it)
az group create --name rg-ai-infra-ref-dev --location eastus2

# 3. Validate the deployment (dry run)
az deployment group validate \
  --resource-group rg-ai-infra-ref-dev \
  --template-file infra/bicep/main.bicep \
  --parameters infra/bicep/params/dev.bicepparam

# 4. Preview changes (what-if)
az deployment group what-if \
  --resource-group rg-ai-infra-ref-dev \
  --template-file infra/bicep/main.bicep \
  --parameters infra/bicep/params/dev.bicepparam

# 5. Deploy
az deployment group create \
  --resource-group rg-ai-infra-ref-dev \
  --template-file infra/bicep/main.bicep \
  --parameters infra/bicep/params/dev.bicepparam \
  --name ai-infra-ref-$(date +%Y%m%d%H%M%S)
```

### 8.3 Deploy with Terraform

```bash
# 1. Login
az login
az account set --subscription "<your-subscription-id>"

# 2. Initialize
cd infra/terraform
terraform init

# 3. Plan (review changes)
terraform plan -var-file=envs/dev.tfvars -out=tfplan

# 4. Apply
terraform apply tfplan
```

### 8.4 Post-Deployment Verification

```bash
# Get outputs
ACA_FQDN=$(az deployment group show --resource-group rg-ai-infra-ref-dev --name <deployment-name> --query properties.outputs.acaFqdn.value -o tsv)
APIM_URL=$(az deployment group show --resource-group rg-ai-infra-ref-dev --name <deployment-name> --query properties.outputs.apimGatewayUrl.value -o tsv)

# Health check
curl https://${ACA_FQDN}/health

# Chat test (via APIM)
curl -X POST "${APIM_URL}/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "Hello"}]}'
```

---

## 9. Foundry Stub Default & Upgrade to Real Endpoint

### 9.1 What the Stub Does

The stub is an **APIM mock-response policy** that returns a valid Azure OpenAI-compatible response without requiring any AI backend. This means:

- Anyone can deploy and test the full wiring (ACA → APIM → response) without provisioning an AI Foundry resource.
- The response format matches the real Azure OpenAI Chat Completions API schema.
- Zero additional cost — the stub runs entirely within APIM.

### 9.2 How the App Uses APIM (Stable Abstraction)

The app is configured with a single environment variable: `APIM_ENDPOINT`. It never knows or cares whether the backend is a stub or a real AI endpoint.

```
App → APIM (always) → Backend (stub OR real — APIM decides)
```

This design means swapping backends is a **platform operation**, not an application change.

### 9.3 Why APIM in Front of AI Endpoints

| Benefit | Detail |
|---------|--------|
| **Centralized policy** | Auth, rate limiting, caching, logging applied once, not per-app |
| **Governance** | Policy-as-code, version-controlled, auditable |
| **Throttling** | Prevent cost explosions from runaway AI calls |
| **Versioning** | Multiple API versions behind one gateway |
| **Consistent auth** | MI from app → APIM; MI from APIM → AI backend |
| **Caching** | Reduce duplicate AI calls, save tokens and money |
| **Observability** | Structured logs with token counts, latency, error codes |
| **Backend abstraction** | Swap AI providers without changing any application code |

### 9.4 Upgrade to Real Azure AI Foundry Endpoint

#### Prerequisites

1. Azure AI Foundry resource deployed in a supported region.
2. Model deployed (e.g., GPT-4o) with a deployment name.
3. Managed Identity assigned `Cognitive Services OpenAI User` role on the AI Foundry resource.

#### Auth Options

| Option | How | When to Use |
|--------|-----|-------------|
| **Managed Identity (recommended)** | APIM policy uses `authentication-managed-identity` to get AAD token for `https://cognitiveservices.azure.com` | Production. Secretless, auditable. |
| **API Key via Key Vault** | Key stored in Key Vault; APIM retrieves via `send-request` to Key Vault | Legacy scenarios, third-party AI providers |

#### APIM Backend Configuration Change

Replace the stub backend with the real endpoint in APIM:

```xml
<!-- Before: Stub (mock-response policy) -->
<backend>
  <return-response />  <!-- mock-response handles it -->
</backend>

<!-- After: Real endpoint -->
<backend>
  <set-backend-service base-url="https://<your-ai-foundry>.openai.azure.com/openai/deployments/<deployment-name>" />
</backend>
```

In IaC, set the `aiFoundryEndpoint` parameter instead of using the stub.

#### Policy Adjustments

- **Caching**: Review cache policy. Disable caching for personalized/PII prompts.
- **Retry**: Enable retry policy for 429 (rate-limited) and 503 (service unavailable) from AI backend.
- **Token logging**: Enable APIM policy to extract `usage.total_tokens` from response and emit as custom metric.
- **Timeout**: Increase from 30s default if model responses are slow (large context windows).

#### Cost Implications

- AI Foundry charges per 1,000 tokens (model-dependent pricing).
- APIM caching can reduce token costs by 20–50%+ for repetitive queries.
- Set budget alerts before enabling real endpoint.
- Monitor token usage via App Insights custom metrics.

#### Security Implications

- Real prompts contain user data — review data classification.
- Enable threat protection policies in APIM (input size limits, content validation).
- Review data residency — AI Foundry region must match data sovereignty requirements.
- Enable audit logging on AI Foundry resource.

---

## 10. APIM Policies Deep Dive

### 10.1 Authentication & Authorization

APIM validates inbound requests and authenticates to the backend.

**Inbound (app → APIM)**:
- Subscription key validation (dev/test) or JWT validation (production)
- Managed Identity from ACA validated via `validate-azure-ad-token`

**Outbound (APIM → backend)**:
- Managed Identity token acquisition for `https://cognitiveservices.azure.com`
- Set via `authentication-managed-identity` policy

### 10.2 Rate Limiting & Quotas

```xml
<rate-limit calls="60" renewal-period="60" />  <!-- 60 calls/min per subscription -->
<quota calls="1000" renewal-period="86400" />   <!-- 1000 calls/day per subscription -->
```

Tradeoffs:
- Too restrictive → blocks legitimate users in burst scenarios.
- Too permissive → runaway costs on AI backend.
- **Recommendation**: Start restrictive, monitor, adjust based on actual usage patterns.

### 10.3 Logging & Observability (Privacy-Aware)

```xml
<diagnostics>
  <!-- Log request/response metadata but NOT body (prompt content) by default -->
  <log-to-eventhub logger-id="ai-logger" />
</diagnostics>
```

**Privacy decision matrix**:

| Data | Log? | Why |
|------|------|-----|
| Request URL + method | Yes | Operational visibility |
| Response status code | Yes | Error tracking |
| Latency | Yes | Performance monitoring |
| Token usage (from response header/body) | Yes | Cost tracking |
| Subscription key / caller identity | Yes (hashed) | Abuse detection |
| Prompt content | **No** (default) | PII risk, compliance |
| Response content | **No** (default) | PII risk, IP risk |

Override the default only with explicit data classification approval and appropriate retention/access controls.

### 10.4 Response Caching

```xml
<cache-lookup vary-by-developer="false" vary-by-developer-groups="false">
  <vary-by-header>X-No-Cache</vary-by-header>
</cache-lookup>
<cache-store duration="3600" /> <!-- 1 hour -->
```

**When caching is SAFE**:
- Static, non-personalized prompts (e.g., "Summarize this public document")
- System prompts with deterministic outputs
- FAQ-style queries

**When caching is UNSAFE**:
- Prompts containing PII (names, account numbers, health data)
- Personalized prompts using user context
- Prompts with `temperature > 0` where varied outputs are desired
- Any prompt where response freshness matters (real-time data)

**Implementation**: The app sets `X-No-Cache: true` header for uncacheable requests. APIM policy checks this header and skips cache.

---

## 11. Cost Optimization

### Token Cost Reduction

| Strategy | Savings | Complexity | Trade-off |
|----------|---------|------------|-----------|
| APIM response caching | 20–50%+ for repetitive queries | Low | Stale responses for dynamic content |
| Prompt engineering (shorter prompts) | 10–30% | Medium | App team responsibility |
| Model selection (GPT-4o-mini vs GPT-4o) | 50–90% per token | Low | Quality vs. cost |
| Max token limits in APIM policy | Prevents runaway costs | Low | Truncated responses |

### Infrastructure Cost Controls

| Control | Implementation |
|---------|---------------|
| ACA scale-to-zero | Default in Consumption plan |
| APIM Consumption tier | $0 base cost + per-call pricing |
| Log retention 30 days | Reduce to 7 for dev; extend only for compliance |
| Budget alerts | 50%, 80%, 100% thresholds |
| Resource cleanup | Dedicated teardown script for dev environments |

### Usage Telemetry Dashboard

APIM policies extract token usage from AI responses and emit custom metrics:
- Total tokens per hour/day/week
- Cost estimate (tokens × price per 1K tokens)
- Cache hit ratio
- Top callers by token consumption

---

## 12. Verification & Troubleshooting

### 12.1 Smoke Tests

```bash
# Run the smoke test suite
bash tests/integration/smoke.sh
```

The smoke test validates:
1. ACA container is running and `/health` returns 200.
2. APIM gateway is reachable.
3. `POST /chat/completions` via APIM returns expected response schema.
4. Response includes required fields: `id`, `choices`, `usage`.

### 12.2 Common Issues & Fixes

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| 401 from APIM | MI role assignment not propagated | Wait 5 minutes; verify role assignment with `az role assignment list` |
| 404 from APIM | API path mismatch | Check APIM API definition matches app route (`/chat/completions`) |
| 429 from APIM | Rate limit exceeded | Increase `rate-limit` in policy or reduce test load |
| ACA shows 0 replicas | Normal scale-to-zero | First request triggers cold start (~10s) |
| `SkuNotAvailable` on deploy | APIM tier unavailable in region | Change region or tier in params |
| DNS resolution fails to PE | Private DNS Zone not linked to VNet | Add VNet link to Private DNS Zone |
| ACA can't reach PE-protected service | ACA not VNet-integrated | Enable VNet integration in ACA Environment |
| `nslookup` returns public IP for PE | DNS resolution going to public DNS | Verify Private DNS Zone exists and is linked |

### 12.3 Monitoring Dashboards

After deployment:
1. **App Insights** → Application Map shows ACA → APIM → backend topology.
2. **Log Analytics** → Run included KQL queries for token usage, error rates.
3. **APIM Analytics** → Built-in dashboard for API call volume, latency, errors.

---

## 13. Tests & CI

### 13.1 Test Suite

| Test Type | Location | What It Validates |
|-----------|----------|-------------------|
| Unit tests | `tests/unit/` | Chatbot app logic with mocked APIM responses |
| Smoke tests | `tests/integration/smoke.sh` | Live endpoint reachability and response schema |
| IaC validation | CI workflow | Bicep build + Terraform validate |

### 13.2 GitHub Actions Workflow

The CI pipeline (`.github/workflows/ci.yml`) runs on every push and PR:

```yaml
jobs:
  bicep-validate:    # az bicep build + validate
  terraform-validate: # terraform fmt -check + validate + plan
  app-test:          # npm test (Jest unit tests)
```

No deployment happens in CI by default. Deployment is triggered manually or via a separate CD workflow.

---

## 14. Repo Structure

```
ai-infra-csa-reference/
├── README.md                              # This file — the runbook
├── .gitignore
├── docs/
│   └── tutorial.md                        # Junior engineer guided walkthrough
├── infra/
│   ├── bicep/
│   │   ├── main.bicep                     # Orchestrator — references all modules
│   │   ├── modules/
│   │   │   ├── logAnalytics.bicep
│   │   │   ├── appInsights.bicep
│   │   │   ├── keyVault.bicep
│   │   │   ├── managedIdentity.bicep
│   │   │   ├── apim.bicep
│   │   │   ├── acaEnvironment.bicep
│   │   │   ├── containerApp.bicep
│   │   │   └── roleAssignments.bicep
│   │   └── params/
│   │       ├── dev.bicepparam
│   │       └── prod.bicepparam
│   ├── terraform/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   ├── modules/
│   │   │   ├── log_analytics/
│   │   │   ├── app_insights/
│   │   │   ├── key_vault/
│   │   │   ├── managed_identity/
│   │   │   ├── apim/
│   │   │   ├── aca_environment/
│   │   │   ├── container_app/
│   │   │   └── role_assignments/
│   │   └── envs/
│   │       ├── dev.tfvars
│   │       └── prod.tfvars
│   └── docs/
│       ├── architecture.md
│       ├── decisions.md
│       └── private-networking.md
├── app/
│   ├── package.json
│   ├── server.js
│   ├── Dockerfile
│   └── .env.example
├── apim/
│   ├── policies/
│   │   ├── global-policy.xml
│   │   ├── chat-api-policy.xml
│   │   └── stub-backend-policy.xml
│   └── api-definition/
│       └── chat-api.openapi.yaml
├── tests/
│   ├── unit/
│   │   ├── server.test.js
│   │   └── package.json
│   └── integration/
│       └── smoke.sh
└── .github/
    └── workflows/
        └── ci.yml
```

---

## 15. Contributing & License

### Contributing

1. Fork the repo and create a feature branch.
2. Follow the existing patterns (AVM modules, parameterized, tagged).
3. Update tests and documentation for any changes.
4. Submit a PR — CI must pass before merge.

### License

[MIT License](LICENSE)

---

> **Feedback?** Open an issue. This is a living reference — it improves with real-world usage.
