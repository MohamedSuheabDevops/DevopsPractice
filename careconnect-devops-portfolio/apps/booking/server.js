// Minimal CareConnect booking service. Built-in http module only, so no dependencies to install.
//   SERVICE_NAME  name shown in responses
//   BACKEND_URL   optional: if set, "/" also calls BACKEND_URL/work (makes a multi-service trace)
const http = require('http');
const os = require('os');

const NAME = process.env.SERVICE_NAME || 'booking';
const BACKEND = process.env.BACKEND_URL || '';

function call(url) {
  return new Promise((resolve, reject) => {
    http.get(url, (res) => {
      let data = '';
      res.on('data', (c) => (data += c));
      res.on('end', () => resolve(data));
    }).on('error', reject);
  });
}

const server = http.createServer(async (req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end('{"status":"UP"}');
  }
  let downstream = null;
  if (BACKEND && req.url === '/') {
    try { downstream = JSON.parse(await call(BACKEND + '/work')); }
    catch (e) { res.writeHead(502); return res.end(JSON.stringify({ service: NAME, error: e.message })); }
  }
  console.log(JSON.stringify({ level: 'info', service: NAME, path: req.url }));
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ service: NAME, container: os.hostname(), downstream }));
});

server.listen(8080, () => console.log(NAME + ' listening on 8080'));

// Node as PID 1 ignores SIGTERM unless we handle it. Without this, "docker stop" waits 10 seconds.
process.on('SIGTERM', () => server.close(() => process.exit(0)));
process.on('SIGINT', () => server.close(() => process.exit(0)));
