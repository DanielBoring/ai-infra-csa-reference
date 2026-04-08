// ---------------------------------------------------------------------------
// AI Infrastructure CSA Reference — Minimal Chatbot API
// ---------------------------------------------------------------------------
// This Express server exposes:
//   GET  /health            — liveness + readiness probe
//   POST /chat              — forwards to APIM, returns AI completion
//
// Configuration (environment variables):
//   APIM_ENDPOINT           — APIM gateway URL (e.g., https://apim-xxx.azure-api.net)
//   PORT                    — HTTP port (default: 3000)
//   AZURE_CLIENT_ID         — Managed Identity client ID (for token acquisition)
// ---------------------------------------------------------------------------

const express = require('express');

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3000;
const getApimEndpoint = () => process.env.APIM_ENDPOINT || '';

// ---------------------------------------------------------------------------
// GET /health — Health check endpoint for ACA probes
// ---------------------------------------------------------------------------
app.get('/health', (_req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    apimConfigured: !!getApimEndpoint(),
  });
});

// ---------------------------------------------------------------------------
// POST /chat — Chat completions proxy
// ---------------------------------------------------------------------------
// Accepts: { "messages": [{ "role": "user", "content": "Hello" }] }
// Returns: Azure OpenAI Chat Completions compatible response
// ---------------------------------------------------------------------------
app.post('/chat', async (req, res) => {
  const { messages } = req.body;

  if (!messages || !Array.isArray(messages) || messages.length === 0) {
    return res.status(400).json({
      error: {
        message: 'Request body must include a non-empty "messages" array.',
        type: 'invalid_request_error',
      },
    });
  }

  const apimEndpoint = getApimEndpoint();
  if (!apimEndpoint) {
    return res.status(503).json({
      error: {
        message: 'APIM_ENDPOINT is not configured. Set it in environment variables.',
        type: 'configuration_error',
      },
    });
  }

  try {
    const apimUrl = `${apimEndpoint}/chat/completions`;

    const response = await fetch(apimUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ messages }),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      return res.status(response.status).json({
        error: {
          message: `APIM returned ${response.status}: ${errorBody}`,
          type: 'upstream_error',
        },
      });
    }

    const data = await response.json();
    return res.json(data);
  } catch (err) {
    return res.status(502).json({
      error: {
        message: `Failed to reach APIM: ${err.message}`,
        type: 'gateway_error',
      },
    });
  }
});

// ---------------------------------------------------------------------------
// Start server
// ---------------------------------------------------------------------------
if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Chatbot server listening on port ${PORT}`);
    console.log(`APIM endpoint: ${getApimEndpoint() || '(not configured)'}`);
  });
}

module.exports = app;
