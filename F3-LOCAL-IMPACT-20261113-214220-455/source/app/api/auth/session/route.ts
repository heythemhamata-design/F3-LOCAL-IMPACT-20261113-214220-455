import { NextRequest, NextResponse } from "next/server";
import { SESSION_COOKIE_NAME, verifySessionToken } from "@/lib/security/auth";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const authenticated = Boolean(
    verifySessionToken(request.cookies.get(SESSION_COOKIE_NAME)?.value),
  );
  return NextResponse.json(
    { ok: true, authenticated },
    { headers: { "Cache-Control": "no-store, max-age=0" } },
  );
}
