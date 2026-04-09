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
app.use(express.json({ limit: '100kb' }));

// ---------------------------------------------------------------------------
// Security headers middleware
// ---------------------------------------------------------------------------
app.use((_req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '0');
  res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  res.setHeader('Cache-Control', 'no-store');
  res.removeHeader('X-Powered-By');
  next();
});

const PORT = process.env.PORT || 3000;

// ---------------------------------------------------------------------------
// GET /health — Health check endpoint for ACA probes
// ---------------------------------------------------------------------------
app.get('/health', (_req, res) => {
  const apimEndpoint = process.env.APIM_ENDPOINT || '';
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    apimConfigured: !!apimEndpoint,
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
  const apimEndpoint = process.env.APIM_ENDPOINT || '';

  // Validate messages exists, is array, non-empty
  if (!messages || !Array.isArray(messages) || messages.length === 0) {
    return res.status(400).json({
      error: {
        message: 'Request body must include a non-empty "messages" array.',
        type: 'invalid_request_error',
      },
    });
  }

  // Validate messages array size (prevent abuse)
  if (messages.length > 100) {
    return res.status(400).json({
      error: {
        message: 'Too many messages. Maximum is 100.',
        type: 'invalid_request_error',
      },
    });
  }

  // Validate each message has required fields with correct types
  for (const msg of messages) {
    if (
      typeof msg !== 'object' ||
      msg === null ||
      typeof msg.role !== 'string' ||
      typeof msg.content !== 'string'
    ) {
      return res.status(400).json({
        error: {
          message: 'Each message must have a "role" (string) and "content" (string).',
          type: 'invalid_request_error',
        },
      });
    }
    if (!['system', 'user', 'assistant'].includes(msg.role)) {
      return res.status(400).json({
        error: {
          message: 'Message role must be one of: system, user, assistant.',
          type: 'invalid_request_error',
        },
      });
    }
  }

  if (!apimEndpoint) {
    return res.status(503).json({
      error: {
        message: 'Backend is not configured.',
        type: 'configuration_error',
      },
    });
  }

  try {
    const apimUrl = `${apimEndpoint}/chat/completions`;

    const headers = {
      'Content-Type': 'application/json',
    };

    // Include subscription key if configured
    if (process.env.APIM_SUBSCRIPTION_KEY) {
      headers['Ocp-Apim-Subscription-Key'] = process.env.APIM_SUBSCRIPTION_KEY;
    }

    const response = await fetch(apimUrl, {
      method: 'POST',
      headers,
      body: JSON.stringify({ messages }),
    });

    if (!response.ok) {
      return res.status(response.status >= 500 ? 502 : response.status).json({
        error: {
          message: 'The request could not be completed.',
          type: 'upstream_error',
        },
      });
    }

    const data = await response.json();
    return res.json(data);
  } catch (_err) {
    return res.status(502).json({
      error: {
        message: 'Unable to reach the backend service.',
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
    if (process.env.NODE_ENV !== 'production') {
      console.log(`APIM endpoint: ${process.env.APIM_ENDPOINT || '(not configured)'}`);
    }
  });
}

module.exports = app;
