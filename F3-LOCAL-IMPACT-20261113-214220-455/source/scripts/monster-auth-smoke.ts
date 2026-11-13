import assert from "node:assert/strict";
import { randomBytes, scryptSync } from "node:crypto";

async function main() {
  const password = "Monster-Test-Password-2026!";
  const salt = randomBytes(32);
  const hash = scryptSync(password, salt, 64, {
    N: 16_384,
    r: 8,
    p: 1,
    maxmem: 64 * 1024 * 1024,
  });

  process.env.MONSTER_AUTH_SECRET = randomBytes(48).toString("hex");
  process.env.MONSTER_ADMIN_PASSWORD_HASH = `scrypt$${salt.toString("hex")}$${hash.toString("hex")}`;
  process.env.MONSTER_COOKIE_SECURE = "false";

  const auth = await import("@/lib/security/auth");
  let passed = 0;
  const test = (name: string, fn: () => void) => {
    fn();
    passed++;
    console.log(`PASS ${passed}: ${name}`);
  };

  test("authentication configuration is detected", () => {
    assert.equal(auth.isAuthConfigured(), true);
  });
  test("valid administrator password is accepted", () => {
    assert.equal(auth.verifyAdminPassword(password), true);
  });
  test("incorrect administrator password is rejected", () => {
    assert.equal(auth.verifyAdminPassword("incorrect-password"), false);
  });

  const now = Math.floor(Date.now() / 1_000);
  const token = auth.createSessionToken(now);
  test("new session token verifies", () => {
    assert.equal(auth.verifySessionToken(token, now)?.sub, "admin");
  });
  test("tampered session token is rejected", () => {
    const tampered = `${token.slice(0, -1)}${token.endsWith("a") ? "b" : "a"}`;
    assert.equal(auth.verifySessionToken(tampered, now), null);
  });
  test("expired session token is rejected", () => {
    assert.equal(auth.verifySessionToken(token, now + auth.SESSION_TTL_SECONDS + 1), null);
  });
  test("malformed session token is rejected", () => {
    assert.equal(auth.verifySessionToken("not-a-session"), null);
  });

  const sameOrigin = new Request("http://127.0.0.1:3000/api/auth/login", {
    method: "POST",
    headers: { origin: "http://127.0.0.1:3000" },
  });
  const crossOrigin = new Request("http://127.0.0.1:3000/api/auth/login", {
    method: "POST",
    headers: { origin: "http://evil.example" },
  });
  const noOrigin = new Request("http://127.0.0.1:3000/api/auth/login", { method: "POST" });

  test("same-origin browser request is accepted", () => {
    assert.equal(auth.isSameOriginRequest(sameOrigin), true);
  });
  test("cross-origin request is rejected", () => {
    assert.equal(auth.isSameOriginRequest(crossOrigin), false);
  });
  test("request without Origin is rejected", () => {
    assert.equal(auth.isSameOriginRequest(noOrigin), false);
  });

  const cookie = auth.sessionCookieOptions();
  test("session cookie is HttpOnly and SameSite Strict", () => {
    assert.equal(cookie.httpOnly, true);
    assert.equal(cookie.sameSite, "strict");
    assert.equal(cookie.secure, false);
  });

  console.log(`\nMONSTER AUTH SMOKE: ${passed}/11 PASS`);
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
