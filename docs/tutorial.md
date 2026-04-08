# Tutorial: Your First AI Infrastructure Deployment

Welcome! This tutorial walks you through deploying an AI-ready infrastructure on Azure, step by step. No prior experience with API Management, Container Apps, or AI services is needed — we'll explain everything as we go.

By the end, you'll have a running chatbot that talks to a mock AI backend through a fully governed API gateway. More importantly, you'll understand *why* each piece exists.

---

## Table of Contents

1. [What Is This Project?](#what-is-this-project)
2. [Concepts You'll Need (Just Enough)](#concepts-youll-need-just-enough)
3. [Prerequisites](#prerequisites)
4. [Step-by-Step: Deploy with Bicep](#step-by-step-deploy-with-bicep)
5. [(Alternative) Deploy with Terraform](#alternative-deploy-with-terraform)
6. [What Just Happened?](#what-just-happened)
7. [Experiments to Try](#experiments-to-try)
8. [Common Mistakes & How to Fix Them](#common-mistakes--how-to-fix-them)
9. [What's Next?](#whats-next)
10. [Glossary](#glossary)

---

## What Is This Project?

Imagine you're on a team that wants to build an AI-powered chatbot. Before anyone writes a single line of chatbot code, someone needs to set up the *infrastructure* — the cloud services that the chatbot runs on, the security controls that protect it, and the monitoring that tells you when something breaks.

That's what this project does. It's a **reference implementation** — a working example you can deploy, study, and adapt.

### What you're building

```
You (HTTP request)
  │
  ▼
┌─────────────────┐
│ Container App    │  ← Your chatbot lives here (a simple Node.js web server)
│ (ACA)           │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ API Management   │  ← The "front door" — controls who can call the AI,
│ (APIM)          │     how often, and logs everything
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ AI Backend       │  ← A mock "stub" that pretends to be an AI model
│ (Stub)          │     (so you don't need to set up a real AI service)
└─────────────────┘
```

### Who owns what?

In real projects, there are two types of engineers:

- **Infrastructure CSA** (that's the role this repo teaches): Sets up the cloud resources, networking, security, monitoring, and governance. Thinks about "How do we keep costs down?" and "How do we prevent unauthorized access?"
- **App CSA**: Builds the actual chatbot logic, designs prompts, picks AI models, and handles user experience.

This repo focuses on the Infrastructure CSA side. The app is intentionally minimal — it's here to prove the infrastructure works.

---

## Concepts You'll Need (Just Enough)

Don't worry if these are new. We'll explain just enough to get you going.

### What is Azure API Management (APIM)?

Think of APIM as a **bouncer + cashier + security camera** for your API:

- **Bouncer**: Checks if the caller is allowed in (authentication)
- **Cashier**: Limits how many requests each caller can make (rate limiting) so costs don't explode
- **Security camera**: Logs every request for monitoring and troubleshooting
- **Smart router**: Can swap out the backend without anyone noticing (today it's a stub, tomorrow it's a real AI model)

**Why do AI endpoints need this?** Because AI API calls cost real money (you pay per "token" — roughly per word). Without APIM, a single bug or attacker could run up thousands of dollars in AI charges.

### What is Azure Container Apps (ACA)?

ACA is a way to run your app in a container (a packaged, portable version of your code) without managing servers.

Key features you'll see:
- **Scales to zero**: When nobody is using the chatbot, it shuts down and costs $0. When someone sends a message, it starts up (~10 seconds).
- **Scales up**: If 100 people use it at once, it creates more copies of your app automatically.
- **Managed Identity**: Your app can authenticate to other Azure services without passwords (more on this below).

### What is Managed Identity?

Normally, when Service A needs to talk to Service B, you'd create a password (a "secret") and store it somewhere. This is risky — secrets leak, get committed to Git, expire, etc.

**Managed Identity** eliminates this entirely. Azure gives your service a unique identity (like an employee badge), and other Azure services trust that badge automatically. No passwords needed.

In this project:
- The Container App has a Managed Identity
- That identity is granted specific permissions (like "allowed to read Key Vault secrets")
- No passwords exist anywhere in the code

### What is Infrastructure as Code (IaC)?

Instead of clicking through the Azure portal to create resources (which is manual, error-prone, and not reproducible), you write code that describes what you want. Then you run a command, and Azure creates everything exactly as specified.

This repo provides IaC in **two languages**:
- **Bicep**: Azure's native IaC language. If your org uses Azure-only, this is the natural choice.
- **Terraform**: HashiCorp's multi-cloud IaC tool. If your org uses multiple clouds, this is often preferred.

Both create the exact same resources. Pick the one your team uses.

### What is the Cloud Adoption Framework (CAF)?

Microsoft's playbook for running cloud projects successfully. It has six phases:

1. **Strategy**: Why are we doing this? What's the business goal?
2. **Plan**: What do we need? (Identity, networking, monitoring, etc.)
3. **Ready**: Build the foundation (landing zone, security controls, etc.)
4. **Adopt**: Ship the solution (IaC, CI/CD, app wiring)
5. **Govern**: Keep it compliant (policies, tagging, cost controls)
6. **Manage**: Operate it (monitoring, alerting, incident response)

This repo maps every decision to a CAF phase, so you can explain *why* something exists.

### What is the Well-Architected Framework (WAF)?

Five design lenses you apply to every architecture decision:

1. **Security**: Is it safe from attackers?
2. **Reliability**: Does it keep working when things fail?
3. **Performance Efficiency**: Is it fast enough?
4. **Cost Optimization**: Are we wasting money?
5. **Operational Excellence**: Can we deploy, monitor, and fix it easily?

This repo applies each WAF pillar specifically to AI workloads. For example:
- *Security*: Managed Identity instead of API keys
- *Cost*: APIM caching to reduce duplicate AI calls
- *Reliability*: Retry policies when the AI backend is temporarily unavailable

---

## Prerequisites

### What to install

| Tool | How to install | Verify |
|------|---------------|--------|
| Azure CLI | [Install guide](https://learn.microsoft.com/cli/azure/install-azure-cli) | `az --version` (need ≥ 2.60.0) |
| Bicep CLI | `az bicep install` | `az bicep version` (need ≥ 0.28.0) |
| Node.js | [Download LTS](https://nodejs.org/) | `node -v` (need ≥ 20) |
| Git | [Download](https://git-scm.com/) | `git --version` |

> **Using Terraform instead?** Install Terraform ≥ 1.6.0 from [terraform.io](https://www.terraform.io/downloads) instead of Bicep.

### Azure subscription

You need an Azure subscription where you have **Contributor** and **User Access Administrator** permissions. If you're using a company subscription, check with your admin.

> **No subscription?** Create a [free Azure account](https://azure.microsoft.com/free/). The free tier is sufficient for this tutorial.

### Estimated cost

Running this tutorial costs approximately **$0–2/day** with the Consumption tier defaults:
- APIM Consumption: $0 base + $0.035 per 10,000 calls
- ACA: $0 when scaled to zero, ~$0.01/hr when running
- Log Analytics: ~$2.76/GB ingested
- Key Vault: ~$0.03 per 10,000 operations

**Don't forget to clean up** when you're done (we'll show you how).

### Verify everything works

```bash
# Check Azure CLI
az --version

# Check you're logged in
az account show

# Check Bicep
az bicep version

# Check Node.js
node -v
```

If any command fails, install the missing tool before continuing.

---

## Step-by-Step: Deploy with Bicep

### Step 1: Clone the Repo

```bash
git clone https://github.com/DanielBoring/ai-infra-csa-reference.git
cd ai-infra-csa-reference
```

### Step 2: Review What You're About to Deploy

Before deploying anything, let's understand what we're creating.

Open `infra/bicep/main.bicep` in your editor. You'll see it calls several modules:

| Module | What It Creates | Why |
|--------|----------------|-----|
| `managedIdentity` | A "badge" for your app | So your app can authenticate without passwords |
| `logAnalytics` | A central log database | So you can search and analyze logs |
| `appInsights` | Application performance monitoring | So you can see how fast/slow things are |
| `keyVault` | A secure vault for secrets | Even though we have no secrets yet, it's best practice to set up |
| `apim` | The API gateway | The "front door" for your AI backend |
| `acaEnvironment` | The container hosting environment | Where your app will run |
| `containerApp` | Your actual chatbot app | The Node.js server |
| `roleAssignments` | Permission grants | Gives the Managed Identity access to Key Vault and APIM |

Now open `infra/bicep/params/dev.bicepparam`. This is where you customize the deployment:

```
param environmentName = 'dev'           # Name tag
param apimSkuName = 'Consumption'       # Cheapest tier
param acaMinReplicas = 0                # Scale to zero
param aiFoundryEndpoint = ''            # Empty = use stub
```

### Step 3: Log In and Create the Resource Group

```bash
# Log in to Azure
az login

# Set your subscription (replace with yours)
az account set --subscription "<your-subscription-id>"

# Create a resource group
az group create --name rg-ai-infra-ref-dev --location eastus2
```

**What happened?** You created an empty "folder" in Azure called a resource group. All resources will go inside it.

### Step 4: Validate (Dry Run)

Before actually creating anything, let's make sure the template is valid:

```bash
az deployment group validate \
  --resource-group rg-ai-infra-ref-dev \
  --template-file infra/bicep/main.bicep \
  --parameters infra/bicep/params/dev.bicepparam
```

**Expected output**: `"provisioningState": "Succeeded"` — this means the template is syntactically valid. Nothing was created yet.

### Step 5: Preview Changes (What-If)

```bash
az deployment group what-if \
  --resource-group rg-ai-infra-ref-dev \
  --template-file infra/bicep/main.bicep \
  --parameters infra/bicep/params/dev.bicepparam
```

**Expected output**: A color-coded list showing all resources that **would** be created (green "+"). Review this — you should see ~8 resources being created.

### Step 6: Deploy!

```bash
az deployment group create \
  --resource-group rg-ai-infra-ref-dev \
  --template-file infra/bicep/main.bicep \
  --parameters infra/bicep/params/dev.bicepparam \
  --name tutorial-deploy-001
```

**This will take 5–15 minutes.** APIM is the slowest resource to provision.

**Expected output**: A JSON object showing all outputs, including:
- `acaFqdn` — your chatbot's URL
- `apimGatewayUrl` — the API gateway URL
- `useStub: true` — confirming we're using the stub backend

### Step 7: Verify the Deployment

```bash
# Get the outputs
ACA_FQDN=$(az deployment group show \
  --resource-group rg-ai-infra-ref-dev \
  --name tutorial-deploy-001 \
  --query properties.outputs.acaFqdn.value -o tsv)

APIM_URL=$(az deployment group show \
  --resource-group rg-ai-infra-ref-dev \
  --name tutorial-deploy-001 \
  --query properties.outputs.apimGatewayUrl.value -o tsv)

echo "ACA: https://${ACA_FQDN}"
echo "APIM: ${APIM_URL}"

# Health check (should return {"status":"healthy",...})
curl "https://${ACA_FQDN}/health"
```

### Step 8: Make Your First Chat Request

```bash
curl -X POST "${APIM_URL}/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "Hello from the tutorial!"}]}'
```

**Expected response** (formatted):
```json
{
  "id": "chatcmpl-stub-abc12345",
  "object": "chat.completion",
  "model": "gpt-4o-stub",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "[STUB] This is a mock response from the Foundry API stub. Your message was: Hello from the tutorial!. To get real AI responses, configure a real Azure AI Foundry endpoint."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 10,
    "completion_tokens": 42,
    "total_tokens": 52
  }
}
```

**Congratulations!** You just sent a message through the complete pipeline:
1. Your `curl` → APIM gateway
2. APIM checked auth, applied rate limits, checked cache
3. APIM's stub policy generated a mock response
4. Response flowed back through APIM (cached, logged) → you

### Clean Up (Important!)

When you're done experimenting, delete everything to avoid charges:

```bash
az group delete --name rg-ai-infra-ref-dev --yes --no-wait
```

---

## (Alternative) Deploy with Terraform

If your team uses Terraform instead of Bicep, follow these steps instead.

### Step 1: Clone and Navigate

```bash
git clone https://github.com/DanielBoring/ai-infra-csa-reference.git
cd ai-infra-csa-reference/infra/terraform
```

### Step 2: Create the Resource Group

```bash
az login
az account set --subscription "<your-subscription-id>"
az group create --name rg-ai-infra-ref-dev --location eastus2
```

### Step 3: Initialize Terraform

```bash
terraform init
```

**What happened?** Terraform downloaded the Azure provider plugin. You'll see a `.terraform/` directory.

### Step 4: Plan (Preview)

```bash
terraform plan -var-file=envs/dev.tfvars -out=tfplan
```

**Expected output**: A list of ~8 resources to be created. Review them.

### Step 5: Apply (Deploy)

```bash
terraform apply tfplan
```

**This takes 5–15 minutes.** Same resources as Bicep, just described in a different language.

### Step 6: Verify

```bash
# Get outputs
terraform output

# Test health endpoint
ACA_FQDN=$(terraform output -raw aca_fqdn)
curl "https://${ACA_FQDN}/health"

# Test chat
APIM_URL=$(terraform output -raw apim_gateway_url)
curl -X POST "${APIM_URL}/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "Hello!"}]}'
```

### Clean Up

```bash
terraform destroy -var-file=envs/dev.tfvars
# Then delete the resource group:
az group delete --name rg-ai-infra-ref-dev --yes --no-wait
```

---

## What Just Happened?

Let's trace exactly what happened when you sent that `curl` request.

### The Request Journey

```
1. Your curl command ──────────────────────────────────▶ APIM Gateway
   POST /chat/completions                               (https://apim-xxx.azure-api.net)
   {"messages": [{"role":"user","content":"Hello"}]}

2. APIM receives the request and runs its policy chain:
   a) Global policy: CORS headers, remove internal headers
   b) Chat API policy:
      • Rate limit check → Are you under 60 requests/min? ✅
      • Quota check → Are you under 1000 requests/day? ✅
      • Cache lookup → Has someone asked this exact question before?
        - Cache miss → proceed to backend

3. APIM routes to backend:
   • aiFoundryEndpoint is empty → stub policy activates
   • Stub policy generates a mock response (no external call)

4. Response flows back through APIM:
   • Cache store → saves response for 1 hour
   • Logging → records metadata (NOT the prompt content — privacy!)
   • Response → back to you
```

### Where Did the Logs Go?

- **Application Insights**: Tracks request duration, success/failure, dependency calls
- **Log Analytics**: Stores all diagnostic logs from every resource
- **APIM Diagnostics**: API-specific logs (which API was called, response codes, latency)

You can explore these in the Azure portal after deploying.

---

## Experiments to Try

Now that you have a working deployment, try these experiments to build intuition:

### 1. Hit the Rate Limit

The APIM policy allows 60 requests per minute. Let's exceed it:

```bash
# Send 65 requests quickly (bash)
for i in $(seq 1 65); do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${APIM_URL}/chat/completions" \
    -H "Content-Type: application/json" \
    -d '{"messages": [{"role":"user","content":"test"}]}')
  echo "Request $i: HTTP $CODE"
done
```

You should see HTTP 200 for the first ~60 requests, then HTTP 429 (Too Many Requests).

**Why this matters**: In production, rate limiting prevents a single user or rogue app from running up your AI costs.

### 2. Check the Logs

In the Azure portal:
1. Go to your Application Insights resource
2. Click "Application Map" — you'll see the ACA → APIM → backend topology
3. Click "Transaction search" to find your specific requests

### 3. Break Something on Purpose

Change the APIM backend URL to something invalid and see what happens:
- What error does the app return?
- How quickly does it fail?
- Can you find the error in the logs?

*(Don't forget to fix it after!)*

### 4. Read the APIM Policy

Open `apim/policies/chat-api-policy.xml` and find:
- The rate limit rule (how many requests per minute?)
- The cache rule (how long are responses cached?)
- The `X-No-Cache` header check (how does the app say "don't cache this"?)

---

## Common Mistakes & How to Fix Them

| What You See | What's Wrong | How to Fix |
|-------------|-------------|-----------|
| **401 Unauthorized** from APIM | Managed Identity role assignment hasn't propagated yet | Wait 5 minutes. Azure AD role assignments can take up to 5 min to propagate. |
| **404 Not Found** from APIM | API path mismatch | Check that the APIM API path (`/chat`) matches what you're calling (`/chat/completions`). |
| **429 Too Many Requests** | Rate limit exceeded | Wait 1 minute for the rate limit to reset, or increase the limit in the policy. |
| **ACA shows 0 replicas** | This is normal! | ACA scales to zero when idle. The first request triggers a "cold start" (~10 seconds). |
| **Deploy fails: SkuNotAvailable** | APIM tier not available in your region | Try a different region (e.g., `eastus` instead of `eastus2`) or a different tier. |
| **Deploy takes 30+ minutes** | APIM provisioning is slow | This is normal for APIM, especially on first deployment. Be patient. |
| **Can't resolve private endpoint** | DNS not configured | See the [Private Networking Guide](../infra/docs/private-networking.md). |

---

## What's Next?

You've deployed the basic infrastructure. Here's where to go from here:

1. **Read the full README** (`README.md`) — it explains every decision with CAF and WAF reasoning. Much deeper than this tutorial.

2. **Try the real AI endpoint** — follow the "Upgrade to Real Azure AI Foundry Endpoint" section in the README (§9.4). You'll need an AI Foundry resource and a deployed model.

3. **Explore private networking** — read `infra/docs/private-networking.md` to understand how to add VNets, Private Endpoints, and Private DNS Zones for production security.

4. **Look at the CI pipeline** — `.github/workflows/ci.yml` validates everything on every push. Understanding CI is essential for production workflows.

5. **Customize for your workload** — fork this repo and adapt it. Change the app, add your own APIM policies, adjust the scaling rules.

---

## Glossary

| Acronym | Full Name | One-Line Explanation |
|---------|-----------|---------------------|
| **ACA** | Azure Container Apps | Serverless container hosting that scales to zero |
| **APIM** | Azure API Management | API gateway for auth, rate limiting, caching, logging |
| **AVM** | Azure Verified Modules | Microsoft-maintained IaC modules for Azure resources |
| **CAF** | Cloud Adoption Framework | Microsoft's cloud project playbook (Strategy → Manage) |
| **CI/CD** | Continuous Integration / Continuous Deployment | Automated build, test, and deploy pipelines |
| **CSA** | Cloud Solution Architect | Engineer who designs cloud solutions |
| **IaC** | Infrastructure as Code | Defining cloud resources in version-controlled code |
| **MI** | Managed Identity | Password-free authentication between Azure services |
| **PE** | Private Endpoint | A private IP address for an Azure PaaS service inside your VNet |
| **RBAC** | Role-Based Access Control | Granting specific permissions to specific identities |
| **SKU** | Stock Keeping Unit | The pricing/capability tier of an Azure resource |
| **VNet** | Virtual Network | An isolated network in Azure, like a private data center |
| **WAF** | Well-Architected Framework | Five design lenses: Security, Reliability, Perf, Cost, Ops |
