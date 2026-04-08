# Architecture Decision Records (ADRs)

Decisions are tagged with the CAF pillar and WAF pillar(s) that justify them.

---

## ADR-001: APIM as the stable abstraction layer

**Status**: Accepted  
**CAF**: Adopt, Govern | **WAF**: Security, Cost Optimization, Operational Excellence

**Context**: The chatbot app needs to call an AI endpoint. We could have the app call the AI endpoint directly, or route through an API gateway.

**Decision**: All AI traffic routes through APIM. The app never calls the AI endpoint directly.

**Reasoning**:
- Centralized policy enforcement (auth, rate limiting, caching, logging) — WAF Security + OpEx
- Backend abstraction allows swapping stub → real AI endpoint without app changes — WAF OpEx
- Token-level cost telemetry extracted via APIM policy — WAF Cost Optimization
- Consistent governance regardless of backend — CAF Govern
- Single place to apply security controls for AI-specific threats — WAF Security

**Consequences**: APIM adds ~10ms latency per request. Acceptable for AI workloads where model inference is 500ms+.

---

## ADR-002: Stub-first default deployment

**Status**: Accepted  
**CAF**: Adopt | **WAF**: Operational Excellence

**Context**: Deploying a real AI Foundry endpoint requires: a Foundry resource, a model deployment, quota allocation, and region-specific availability. This creates a high barrier to entry for testing the platform.

**Decision**: Default deployment uses an APIM mock-response policy that returns a valid Chat Completions schema. No external AI service required.

**Reasoning**:
- Anyone can deploy and validate wiring without AI prerequisites — CAF Adopt
- Reduces cost for initial exploration — WAF Cost
- The upgrade path is documented and requires only APIM backend config change — WAF OpEx

**Consequences**: Stub responses are static. Testing model-specific behavior requires upgrading to real endpoint.

---

## ADR-003: Managed Identity over API keys

**Status**: Accepted  
**CAF**: Ready, Govern | **WAF**: Security

**Context**: Services need to authenticate to each other. Options: API keys, service principals with secrets, Managed Identity.

**Decision**: Use User-Assigned Managed Identity for all service-to-service auth.

**Reasoning**:
- No secrets to manage, rotate, or leak — WAF Security
- Identity lifecycle managed by Azure — WAF OpEx
- Auditable via Azure AD sign-in logs — CAF Govern
- User-Assigned MI can be pre-created and assigned specific RBAC roles — least privilege

**Consequences**: Local development requires alternative auth (Azure CLI identity or service principal). Documented in app/.env.example.

---

## ADR-004: Public baseline with private networking as toggle

**Status**: Accepted  
**CAF**: Ready, Adopt | **WAF**: Security, Cost Optimization

**Context**: Private networking (VNet, PEs, Private DNS Zones) significantly increases security but also complexity, cost, and deployment prerequisites.

**Decision**: Default deployment uses public endpoints. Private networking is available via `enablePrivateNetworking` parameter in both Bicep and Terraform.

**Reasoning**:
- Public baseline maximizes accessibility for learning/testing — CAF Adopt
- Same IaC codebase for both modes — WAF OpEx
- Private networking adds ~$200-400/mo in VNet/PE/DNS costs — WAF Cost
- Regulated workloads MUST use private networking — documented as clear upgrade path

**Consequences**: Public baseline is NOT suitable for production with sensitive data. README clearly states this.

---

## ADR-005: APIM Consumption tier for dev, Standard v2 for prod

**Status**: Accepted  
**CAF**: Plan | **WAF**: Cost Optimization, Performance Efficiency

**Context**: APIM has multiple tiers with vastly different cost and capability profiles.

**Decision**: Default to Consumption tier. Document Standard v2 as the production recommendation.

**Reasoning**:
- Consumption: $0 base, pay-per-call, 1M calls/mo free — WAF Cost for dev/test
- Consumption limitation: no VNet integration, cold starts up to 10s, limited policy set
- Standard v2: VNet integration, no cold starts, full policy set — WAF Performance + Security for prod
- Tier is a parameter — easy to switch per environment

**Consequences**: Cold starts on Consumption tier may affect latency measurements. Document expected behavior.

---

## ADR-006: Dual IaC (Bicep + Terraform)

**Status**: Accepted  
**CAF**: Adopt | **WAF**: Operational Excellence

**Context**: CSA teams have varying IaC preferences. Some organizations standardize on Bicep, others on Terraform.

**Decision**: Provide both. Same logical resources, same parameters, same outputs.

**Reasoning**:
- Maximum adoption across diverse teams — CAF Adopt
- AVM provides modules for both languages — consistent quality
- Both reference the same architecture doc and decisions

**Consequences**: Double maintenance burden. Mitigated by CI that validates both on every PR.

---

## ADR-007: Key Vault with RBAC (not access policies)

**Status**: Accepted  
**CAF**: Ready, Govern | **WAF**: Security

**Context**: Key Vault supports two authorization models: access policies (legacy) and Azure RBAC (modern).

**Decision**: RBAC mode only. No access policies.

**Reasoning**:
- RBAC integrates with ARM/Entra ID — consistent with all other RBAC assignments
- Fine-grained control (Secret Get vs. Secret List vs. Key Decrypt) — least privilege
- Auditable via Azure AD logs — CAF Govern
- Access policies are legacy and don't support conditional access

**Consequences**: Requires `Key Vault Secrets User` or equivalent role assignment for each consumer.

---

## ADR-008: ACA Consumption plan with scale-to-zero

**Status**: Accepted  
**CAF**: Plan | **WAF**: Cost Optimization, Sustainability

**Context**: ACA supports Consumption (serverless) and Dedicated plans.

**Decision**: Default to Consumption with scale-to-zero.

**Reasoning**:
- Zero cost when idle — WAF Cost + Sustainability
- Automatic scaling based on HTTP concurrency — WAF Performance
- No infrastructure management — WAF OpEx
- Cold start (~10s) documented as expected behavior

**Consequences**: For production workloads requiring consistent low latency, set `minReplicas = 1` (documented in prod params).
