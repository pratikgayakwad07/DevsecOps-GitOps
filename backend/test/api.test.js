/**
 * Backend API integration tests
 * Runs against a local Express server — no real DB needed
 * (DB connection errors are swallowed so tests focus on routing/schema)
 */
const http = require('http');

// Minimal stub so tests don't need a real MySQL connection
jest.mock('mysql2', () => ({
  createConnection: () => ({
    query: (sql, params, cb) => {
      // typeof params — if it's a function, it's the callback (no params)
      const callback = typeof params === 'function' ? params : cb;
      if (sql.includes('SELECT * FROM posts ORDER BY')) {
        callback(null, [
          { id: 1, title: 'Test', content: 'Body', author: 'CI', created_at: new Date() },
        ]);
      } else if (sql.includes('SELECT * FROM posts WHERE id = ?')) {
        const id = Array.isArray(params) ? params[0] : 1;
        if (String(id) === '999') return callback(null, []);
        callback(null, [
          { id: Number(id), title: 'Test', content: 'Body', author: 'CI', created_at: new Date() },
        ]);
      } else if (sql.includes('INSERT INTO')) {
        callback(null, { insertId: 42 });
      } else if (sql.includes('UPDATE')) {
        callback(null, {});
      } else if (sql.includes('DELETE')) {
        callback(null, {});
      } else {
        callback(null, []);
      }
    },
  }),
}));

const app = require('../server');

describe('Backend API', () => {
  let server;
  let port;

  beforeAll((done) => {
    server = app.listen(0, () => {
      port = server.address().port;
      done();
    });
  });

  afterAll((done) => server.close(done));

  const req = (method, path, body) =>
    new Promise((resolve, reject) => {
      const data = body ? JSON.stringify(body) : null;
      const options = {
        hostname: '127.0.0.1',
        port,
        path,
        method,
        headers: {
          'Content-Type': 'application/json',
          ...(data ? { 'Content-Length': Buffer.byteLength(data) } : {}),
        },
      };
      const r = http.request(options, (res) => {
        let buf = '';
        res.on('data', (c) => (buf += c));
        res.on('end', () => {
          try {
            resolve({ status: res.statusCode, body: JSON.parse(buf) });
          } catch {
            resolve({ status: res.statusCode, body: buf });
          }
        });
      });
      r.on('error', reject);
      if (data) r.write(data);
      r.end();
    });

  test('GET /health returns 200 with status ok', async () => {
    const { status, body } = await req('GET', '/health');
    expect(status).toBe(200);
    expect(body.status).toBe('ok');
  });

  test('GET /api/posts returns array', async () => {
    const { status, body } = await req('GET', '/api/posts');
    expect(status).toBe(200);
    expect(Array.isArray(body)).toBe(true);
  });

  test('GET /api/posts/:id returns a post', async () => {
    const { status, body } = await req('GET', '/api/posts/1');
    expect(status).toBe(200);
    expect(body).toHaveProperty('id');
    expect(body).toHaveProperty('title');
  });

  test('GET /api/posts/:id returns 404 for missing post', async () => {
    const { status } = await req('GET', '/api/posts/999');
    expect(status).toBe(404);
  });

  test('POST /api/posts creates a post', async () => {
    const { status, body } = await req('POST', '/api/posts', {
      title: 'T', content: 'C', author: 'A',
    });
    expect(status).toBe(200);
    expect(body).toHaveProperty('id');
  });

  test('PUT /api/posts/:id updates a post', async () => {
    const { status, body } = await req('PUT', '/api/posts/1', {
      title: 'T2', content: 'C2', author: 'A2',
    });
    expect(status).toBe(200);
    expect(body.message).toBe('Post updated');
  });

  test('DELETE /api/posts/:id deletes a post', async () => {
    const { status, body } = await req('DELETE', '/api/posts/1');
    expect(status).toBe(200);
    expect(body.message).toBe('Post deleted');
  });
});
