import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import * as jwt from "jsonwebtoken";
import * as jwksRsa from "jwks-rsa";

const TENANT_ID = "96e7dd96-48b5-4991-a67e-1563013dfbe2";
const AUDIENCE = "cf6cfea3-fca3-4e29-94fa-bd7287c144b7"; // Application (client) ID
const ISSUER = `https://login.microsoftonline.com/${TENANT_ID}/v2.0`;
const client = jwksRsa({
  jwksUri: `https://login.microsoftonline.com/${TENANT_ID}/discovery/v2.0/keys`,
});

function getKey(header, callback) {
  client.getSigningKey(header.kid, function (err, key) {
    const signingKey = key?.getPublicKey();
    callback(err, signingKey);
  });
}

async function validateJwt(token: string): Promise<any> {
  return new Promise((resolve, reject) => {
    jwt.verify(
      token,
      getKey,
      {
        audience: AUDIENCE,
        issuer: ISSUER,
        algorithms: ["RS256"],
      },
      (err, decoded) => {
        if (err) return reject(err);
        resolve(decoded);
      }
    );
  });
}

export async function api(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    context.log(`Http function processed request for url "${request.url}"`);

    // Check for Authorization header
    const authHeader = request.headers.get("authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return { status: 401, body: "Unauthorized: No Bearer token provided" };
    }
    const token = authHeader.replace("Bearer ", "");
    try {
      await validateJwt(token);
    } catch (err) {
      context.log("JWT validation failed:", err);
      return { status: 401, body: "Unauthorized: Invalid token" };
    }

    const name = request.query.get('name') || await request.text() || 'world';

    return { body: `Hello, ${name}!` };
};

app.http('api', {
    methods: ['GET', 'POST'],
    authLevel: 'anonymous',
    handler: api
});
