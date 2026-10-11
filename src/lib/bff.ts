/**
 * Server-side proxy from this app's /api/bff/* routes to the BFF, through APIM.
 *
 * The browser only ever calls this app. The Next.js server adds the APIM subscription key
 * (BFF_SUBSCRIPTION_KEY, a Static Web App app setting created by infra/) and forwards the call
 * to BFF_BASE_URL, so the key never reaches the browser and the BFF needs no CORS rules.
 */

// Request headers passed on to the BFF. Everything else (including any subscription key the
// browser sent) is dropped.
const FORWARDED_REQUEST_HEADERS = ["accept", "accept-language", "authorization", "content-type", "cookie"];

// Response headers passed back to the browser.
const FORWARDED_RESPONSE_HEADERS = ["cache-control", "content-type", "location", "set-cookie"];

export interface BffSettings {
  BFF_BASE_URL?: string;
  BFF_SUBSCRIPTION_KEY?: string;
}

/** The BFF URL for a proxied path, or null when the path tries to leave the BFF's base path. */
export function buildUpstreamUrl(baseUrl: string, path: string[], search: string): string | null {
  const segments: string[] = [];
  for (const raw of path) {
    let segment: string;
    try {
      segment = decodeURIComponent(raw);
    } catch {
      return null;
    }
    if (segment === "" || segment === "." || segment === ".." || /[/\\]/.test(segment)) return null;
    segments.push(encodeURIComponent(segment));
  }
  return `${baseUrl.replace(/\/+$/, "")}/${segments.join("/")}${search}`;
}

export async function proxyToBff(
  request: Request,
  path: string[],
  settings: BffSettings = { BFF_BASE_URL: process.env.BFF_BASE_URL, BFF_SUBSCRIPTION_KEY: process.env.BFF_SUBSCRIPTION_KEY },
  fetchImpl: typeof fetch = fetch,
): Promise<Response> {
  if (!settings.BFF_BASE_URL) {
    return Response.json({ message: "BFF_BASE_URL is not configured" }, { status: 500 });
  }

  const upstreamUrl = buildUpstreamUrl(settings.BFF_BASE_URL, path, new URL(request.url).search);
  if (!upstreamUrl) {
    return Response.json({ message: "Invalid path" }, { status: 400 });
  }

  const headers = new Headers();
  for (const name of FORWARDED_REQUEST_HEADERS) {
    const value = request.headers.get(name);
    if (value) headers.set(name, value);
  }
  if (settings.BFF_SUBSCRIPTION_KEY) headers.set("Ocp-Apim-Subscription-Key", settings.BFF_SUBSCRIPTION_KEY);

  const hasBody = request.method !== "GET" && request.method !== "HEAD";
  let upstream: Response;
  try {
    upstream = await fetchImpl(upstreamUrl, {
      method: request.method,
      headers,
      body: hasBody ? await request.arrayBuffer() : undefined,
      redirect: "manual",
      cache: "no-store",
    });
  } catch {
    return Response.json({ message: "The BFF could not be reached" }, { status: 502 });
  }

  const responseHeaders = new Headers();
  for (const name of FORWARDED_RESPONSE_HEADERS) {
    const value = upstream.headers.get(name);
    if (value) responseHeaders.set(name, value);
  }
  return new Response(upstream.body, { status: upstream.status, headers: responseHeaders });
}
