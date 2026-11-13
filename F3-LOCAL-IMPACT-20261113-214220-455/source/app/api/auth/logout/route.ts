import { NextRequest, NextResponse } from "next/server";
import {
  isSameOriginRequest,
  sessionCookieOptions,
  SESSION_COOKIE_NAME,
} from "@/lib/security/auth";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  if (!isSameOriginRequest(request)) {
    return NextResponse.json(
      { ok: false, error: "Cross-origin request rejected." },
      { status: 403, headers: { "Cache-Control": "no-store, max-age=0" } },
    );
  }

  const response = NextResponse.json(
    { ok: true, authenticated: false },
    { headers: { "Cache-Control": "no-store, max-age=0" } },
  );
  response.cookies.set(SESSION_COOKIE_NAME, "", {
    ...sessionCookieOptions(),
    maxAge: 0,
    expires: new Date(0),
  });
  return response;
}
