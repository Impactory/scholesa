const admin = require('firebase-admin');

let firebaseReady = false;

function initFirebaseAdmin() {
  if (firebaseReady) return true;
  try {
    if (admin.apps.length === 0) {
      admin.initializeApp();
    }
    firebaseReady = true;
    return true;
  } catch {
    firebaseReady = false;
    return false;
  }
}

function parseBearer(authHeader) {
  if (!authHeader || typeof authHeader !== 'string') return null;
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  return match ? match[1] : null;
}

function isInternalServiceRequest(req) {
  const email = req.headers['x-goog-authenticated-user-email'];
  return typeof email === 'string' && email.length > 0;
}

function hasAdminRole(claims) {
  const role = String(claims.role || '').toLowerCase();
  return role === 'admin' || role === 'hq' || role === 'site';
}

async function authorizeRequest(req) {
  if (process.env.COMPLIANCE_ALLOW_UNAUTH === '1') {
    return { mode: 'dev-override', uid: 'local-dev', role: 'admin', siteId: 'unscoped' };
  }

  if (isInternalServiceRequest(req)) {
    return {
      mode: 'cloud-run-iam',
      principal: String(req.headers['x-goog-authenticated-user-email'] || ''),
      role: 'service',
      siteId: String(req.headers['x-scholesa-site-id'] || 'unscoped'),
    };
  }

  const token = parseBearer(req.headers.authorization);
  if (!token) {
    const error = new Error('Unauthorized: bearer token or Cloud Run IAM identity is required.');
    error.statusCode = 401;
    throw error;
  }

  if (!initFirebaseAdmin()) {
    const error = new Error('Unauthorized: Firebase admin initialization failed.');
    error.statusCode = 401;
    throw error;
  }

  let decoded;
  try {
    decoded = await admin.auth().verifyIdToken(token, true);
  } catch {
    const error = new Error('Unauthorized: invalid Firebase Auth token.');
    error.statusCode = 401;
    throw error;
  }

  if (!hasAdminRole(decoded)) {
    const error = new Error('Forbidden: admin role is required.');
    error.statusCode = 403;
    throw error;
  }

  const siteId = String(decoded.siteId || decoded.activeSiteId || req.headers['x-scholesa-site-id'] || '').trim();
  if (!siteId) {
    const error = new Error('Forbidden: siteId claim is required.');
    error.statusCode = 403;
    throw error;
  }

  return {
    mode: 'firebase-auth',
    uid: decoded.uid,
    role: String(decoded.role || '').toLowerCase(),
    siteId,
    token: decoded,
  };
}

module.exports = {
  authorizeRequest,
};
