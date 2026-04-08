// ---------------------------------------------------------------------------
// Unit Tests for Chatbot Server
// Tests the Express app with mocked APIM responses.
// ---------------------------------------------------------------------------

const http = require('http');

// Mock fetch globally before requiring the app
const mockFetch = jest.fn();
global.fetch = mockFetch;

const app = require('../../app/server');

// Helper: make HTTP request to the Express app
function request(server, method, path, body) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'localhost',
      port: server.address().port,
      path,
      method,
      headers: { 'Content-Type': 'application/json' },
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        resolve({
          status: res.statusCode,
          body: JSON.parse(data),
        });
      });
    });

    req.on('error', reject);

    if (body) {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
}

describe('Chatbot Server', () => {
  let server;

  beforeAll((done) => {
    server = app.listen(0, done); // Random port
  });

  afterAll((done) => {
    server.close(done);
  });

  afterEach(() => {
    mockFetch.mockReset();
  });

  // ----- Health Endpoint -----

  describe('GET /health', () => {
    it('should return 200 with health status', async () => {
      const res = await request(server, 'GET', '/health');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('healthy');
      expect(res.body).toHaveProperty('timestamp');
      expect(res.body).toHaveProperty('apimConfigured');
    });
  });

  // ----- Chat Endpoint -----

  describe('POST /chat', () => {
    it('should return 400 when messages is missing', async () => {
      const res = await request(server, 'POST', '/chat', {});
      expect(res.status).toBe(400);
      expect(res.body.error.type).toBe('invalid_request_error');
    });

    it('should return 400 when messages is empty array', async () => {
      const res = await request(server, 'POST', '/chat', { messages: [] });
      expect(res.status).toBe(400);
      expect(res.body.error.type).toBe('invalid_request_error');
    });

    it('should return 400 when messages is not an array', async () => {
      const res = await request(server, 'POST', '/chat', { messages: 'hello' });
      expect(res.status).toBe(400);
      expect(res.body.error.type).toBe('invalid_request_error');
    });

    it('should forward request to APIM and return response', async () => {
      const mockResponse = {
        id: 'chatcmpl-test123',
        object: 'chat.completion',
        created: 1712505600,
        model: 'gpt-4o-stub',
        choices: [
          {
            index: 0,
            message: { role: 'assistant', content: 'Hello!' },
            finish_reason: 'stop',
          },
        ],
        usage: { prompt_tokens: 5, completion_tokens: 2, total_tokens: 7 },
      };

      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        json: async () => mockResponse,
      });

      // Only works when APIM_ENDPOINT is set
      const originalEnv = process.env.APIM_ENDPOINT;
      process.env.APIM_ENDPOINT = 'https://mock-apim.azure-api.net';

      const res = await request(server, 'POST', '/chat', {
        messages: [{ role: 'user', content: 'Hello' }],
      });

      process.env.APIM_ENDPOINT = originalEnv;

      expect(res.status).toBe(200);
      expect(res.body.id).toBe('chatcmpl-test123');
      expect(res.body.choices).toHaveLength(1);
      expect(res.body.choices[0].message.content).toBe('Hello!');
      expect(res.body.usage.total_tokens).toBe(7);
    });

    it('should return upstream error when APIM returns non-200', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 429,
        text: async () => 'Rate limit exceeded',
      });

      const originalEnv = process.env.APIM_ENDPOINT;
      process.env.APIM_ENDPOINT = 'https://mock-apim.azure-api.net';

      const res = await request(server, 'POST', '/chat', {
        messages: [{ role: 'user', content: 'Hello' }],
      });

      process.env.APIM_ENDPOINT = originalEnv;

      expect(res.status).toBe(429);
      expect(res.body.error.type).toBe('upstream_error');
    });

    it('should return gateway error when fetch fails', async () => {
      mockFetch.mockRejectedValueOnce(new Error('Connection refused'));

      const originalEnv = process.env.APIM_ENDPOINT;
      process.env.APIM_ENDPOINT = 'https://mock-apim.azure-api.net';

      const res = await request(server, 'POST', '/chat', {
        messages: [{ role: 'user', content: 'Hello' }],
      });

      process.env.APIM_ENDPOINT = originalEnv;

      expect(res.status).toBe(502);
      expect(res.body.error.type).toBe('gateway_error');
    });
  });
});
