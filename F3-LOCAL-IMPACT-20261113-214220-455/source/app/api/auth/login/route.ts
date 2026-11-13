import { NextRequest, NextResponse } from "next/server";
import {
  createSessionToken,
  isAuthConfigured,
  isSameOriginRequest,
  sessionCookieOptions,
  SESSION_COOKIE_NAME,
  verifyAdminPassword,
} from "@/lib/security/auth";
import { enforceRateLimit } from "@/lib/security/rate-limit";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  if (!isSameOriginRequest(request)) {
    return NextResponse.json(
      { ok: false, error: "Cross-origin request rejected." },
      { status: 403, headers: { "Cache-Control": "no-store, max-age=0" } },
    );
  }

  if (!isAuthConfigured()) {
    return NextResponse.json(
      { ok: false, error: "Authentication is not configured. Run the setup script first." },
      { status: 503, headers: { "Cache-Control": "no-store, max-age=0" } },
    );
  }

  try {
    const limit = await enforceRateLimit(request, "login", 5, 30, 15 * 60);
    if (!limit.allowed) {
      return NextResponse.json(
        { ok: false, error: "Too many login attempts. Try again later." },
        {
          status: 429,
          headers: {
            "Retry-After": String(limit.retryAfterSeconds),
            "Cache-Control": "no-store, max-age=0",
          },
        },
      );
    }
  } catch (error) {
    console.error(
      "Login rate limiter unavailable:",
      error instanceof Error ? error.message : "Unknown database error",
    );
    return NextResponse.json(
      { ok: false, error: "Security service unavailable. Login is blocked." },
      { status: 503, headers: { "Cache-Control": "no-store, max-age=0" } },
    );
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { ok: false, error: "A valid JSON body is required." },
      { status: 400 },
    );
  }

  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return NextResponse.json({ ok: false, error: "Invalid request body." }, { status: 400 });
  }

  const password = (body as Record<string, unknown>).password;
  if (typeof password !== "string" || password.length < 1 || password.length > 1_024) {
    return NextResponse.json({ ok: false, error: "Invalid credentials." }, { status: 401 });
  }

  if (!verifyAdminPassword(password)) {
    return NextResponse.json(
      { ok: false, error: "Invalid credentials." },
      { status: 401, headers: { "Cache-Control": "no-store, max-age=0" } },
    );
  }

  const response = NextResponse.json(
    { ok: true, authenticated: true },
    { headers: { "Cache-Control": "no-store, max-age=0" } },
  );
  response.cookies.set(SESSION_COOKIE_NAME, createSessionToken(), sessionCookieOptions());
  return response;
}
