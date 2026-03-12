const http = require('http');
const fs = require('fs');
const path = require('path');
const { authorizeRequest } = require('./auth');
const { runComplianceSuite } = require('./checks/runAllChecks');
const { REPO_ROOT } = require('./utils');

const PORT = Number(process.env.PORT || 8080);
const ROOT_REDIRECT_URL = String(process.env.COMPLIANCE_ROOT_REDIRECT_URL || 'https://www.scholesa.com/en').trim();

function sendJson(res, statusCode, payload) {
  res.statusCode = statusCode;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.end(JSON.stringify(payload, null, 2));
}

function sendRedirect(res, location) {
  res.statusCode = 307;
  res.setHeader('Location', location);
  res.end();
}

function shouldRedirectRoot(req) {
  if (!ROOT_REDIRECT_URL) return false;
  const accept = String(req.headers.accept || '').toLowerCase();
  return accept.includes('text/html');
}

function parseBody(req) {
  return new Promise((resolve, reject) => {
    let raw = '';
    req.on('data', (chunk) => {
      raw += chunk;
      if (raw.length > 1024 * 1024) {
        reject(new Error('Request body too large'));
      }
    });
    req.on('end', () => {
      if (!raw) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(raw));
      } catch {
        reject(new Error('Invalid JSON body'));
      }
    });
    req.on('error', reject);
  });
}

function latestStatus() {
  const latestPath = path.join(REPO_ROOT, 'audit-pack', 'reports', 'compliance-latest.json');
  if (!fs.existsSync(latestPath)) return null;
  try {
    return JSON.parse(fs.readFileSync(latestPath, 'utf8'));
  } catch {
    return null;
  }
}

function readReport(reportId) {
  const reportPath = path.join(REPO_ROOT, 'audit-pack', 'reports', `compliance-run-${reportId}.json`);
  if (!fs.existsSync(reportPath)) return null;
  try {
    return JSON.parse(fs.readFileSync(reportPath, 'utf8'));
  } catch {
    return null;
  }
}

async function handleRequest(req, res) {
  try {
    const url = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);

    if (req.method === 'GET' && url.pathname === '/') {
      if (shouldRedirectRoot(req)) {
        sendRedirect(res, ROOT_REDIRECT_URL);
        return;
      }
      sendJson(res, 200, {
        ok: true,
        service: 'scholesa-compliance',
        message: 'Service is running',
        endpoints: [
          'GET /',
          'GET /health',
          'GET /compliance/status',
          'POST /compliance/run',
          'GET /compliance/report/:reportId',
          'POST /compliance/remediate',
        ],
      });
      return;
    }

    if (req.method === 'GET' && (url.pathname === '/health' || url.pathname === '/healthz')) {
      sendJson(res, 200, { ok: true, service: 'scholesa-compliance' });
      return;
    }

    if (req.method === 'GET' && url.pathname === '/compliance/status') {
      await authorizeRequest(req);
      const latest = latestStatus();
      sendJson(res, 200, {
        service: 'scholesa-compliance',
        latest,
      });
      return;
    }

    if (req.method === 'GET' && url.pathname.startsWith('/compliance/report/')) {
      await authorizeRequest(req);
      const reportId = decodeURIComponent(url.pathname.replace('/compliance/report/', ''));
      const report = readReport(reportId);
      if (!report) {
        sendJson(res, 404, { error: 'not_found', message: 'Report not found' });
        return;
      }
      sendJson(res, 200, report);
      return;
    }

    if (req.method === 'POST' && url.pathname === '/compliance/run') {
      const auth = await authorizeRequest(req);
      const body = await parseBody(req);
      const trigger = typeof body.trigger === 'string' ? body.trigger : 'manual-api';
      const result = runComplianceSuite(trigger);
      sendJson(res, result.passed ? 200 : 409, {
        status: result.passed ? 'PASS' : 'FAIL',
        actor: auth,
        reportId: result.reportId,
        reportPath: path.relative(REPO_ROOT, result.reportPath),
        failures: result.failures,
      });
      return;
    }

    if (req.method === 'POST' && url.pathname === '/compliance/remediate') {
      await authorizeRequest(req);
      const body = await parseBody(req);
      const action = String(body.action || '').trim();

      if (action === 'rerun_checks') {
        const result = runComplianceSuite('remediation-rerun');
        sendJson(res, result.passed ? 200 : 409, {
          status: result.passed ? 'PASS' : 'FAIL',
          action,
          reportId: result.reportId,
          failures: result.failures,
        });
        return;
      }

      sendJson(res, 400, {
        error: 'invalid_action',
        allowedActions: ['rerun_checks'],
      });
      return;
    }

    sendJson(res, 404, {
      error: 'not_found',
      message: 'Unknown endpoint',
      endpoints: [
        'GET /',
        'GET /health',
        'GET /compliance/status',
        'POST /compliance/run',
        'GET /compliance/report/:reportId',
        'POST /compliance/remediate',
      ],
    });
  } catch (error) {
    const statusCode = error && typeof error.statusCode === 'number' ? error.statusCode : 500;
    sendJson(res, statusCode, {
      error: 'request_failed',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
}

function startServer() {
  const server = http.createServer((req, res) => {
    void handleRequest(req, res);
  });
  server.listen(PORT, () => {
    console.log(`scholesa-compliance listening on :${PORT}`);
  });
}

if (require.main === module) {
  startServer();
}

module.exports = {
  startServer,
};
