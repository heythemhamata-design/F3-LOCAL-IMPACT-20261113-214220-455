import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);

  const latParam = searchParams.get("lat");
  const lonParam = searchParams.get("lon");

  const lat = latParam ?? request.headers.get("x-vercel-ip-latitude");
  const lon = lonParam ?? request.headers.get("x-vercel-ip-longitude");

  if (!lat || !lon) {
    return NextResponse.json(
      { error: "LOCATION_REQUIRED", message: "Location permission is required." },
      { status: 400 }
    );
  }

  const latitude = Number(lat);
  const longitude = Number(lon);

  if (
    !Number.isFinite(latitude) ||
    !Number.isFinite(longitude) ||
    latitude < -90 ||
    latitude > 90 ||
    longitude < -180 ||
    longitude > 180
  ) {
    return NextResponse.json(
      { error: "INVALID_COORDINATES" },
      { status: 400 }
    );
  }

  const city = request.headers.get("x-vercel-ip-city") ?? "Your location";

  try {
    const url = new URL("https://api.open-meteo.com/v1/forecast");
    url.searchParams.set("latitude", String(latitude));
    url.searchParams.set("longitude", String(longitude));
    url.searchParams.set("current", "temperature_2m,weather_code");
    url.searchParams.set("timezone", "auto");

    const response = await fetch(url.toString(), {
      signal: AbortSignal.timeout(10000),
      cache: "no-store",
    });

    if (!response.ok) {
      throw new Error(`Open-Meteo HTTP ${response.status}`);
    }

    const data = await response.json();

    if (!data.current) {
      throw new Error("Weather data unavailable");
    }

    return NextResponse.json(
      { current: data.current, city },
      { headers: { "Cache-Control": "no-store" } }
    );
  } catch (error) {
    console.error("Weather API error:", error);

    return NextResponse.json(
      { error: "WEATHER_UNAVAILABLE" },
      { status: 502 }
    );
  }
}