import { describe, expect, it, vi } from "vitest";
import { buildUpstreamUrl, proxyToBff } from "./bff";

const settings = { BFF_BASE_URL: "https://apim.example.net/orders/", BFF_SUBSCRIPTION_KEY: "test-key" };

function upstreamOk(body = '{"status":"UP"}') {
  return vi.fn(
    async (_url: string, _init?: RequestInit) =>
      new Response(body, { status: 200, headers: { "content-type": "application/json", "x-internal": "1" } }),
  );
}

describe("buildUpstreamUrl", () => {
  it("joins the base URL, path and query", () => {
    expect(buildUpstreamUrl(settings.BFF_BASE_URL, ["api", "v1", "orders"], "?page=2")).toBe(
      "https://apim.example.net/orders/api/v1/orders?page=2",
    );
  });

  it.each([[[".."]], [["api", "%2e%2e"]], [["a%2Fb"]], [["a%5Cb"]], [[""]], [["%E0%A4%A"]]])(
    "rejects a path that could leave the BFF base path: %j",
    (path) => {
      expect(buildUpstreamUrl(settings.BFF_BASE_URL, path, "")).toBeNull();
    },
  );
});

describe("proxyToBff", () => {
  it("adds the subscription key and forwards only allowed headers", async () => {
    const fetchImpl = upstreamOk();
    const request = new Request("https://ui.example.net/api/bff/health", {
      headers: { authorization: "Bearer abc", "ocp-apim-subscription-key": "from-browser", "x-other": "dropped" },
    });

    const response = await proxyToBff(request, ["health"], settings, fetchImpl as unknown as typeof fetch);

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ status: "UP" });
    const [url, init] = fetchImpl.mock.calls[0];
    expect(url).toBe("https://apim.example.net/orders/health");
    const sent = new Headers(init?.headers);
    expect(sent.get("ocp-apim-subscription-key")).toBe("test-key");
    expect(sent.get("authorization")).toBe("Bearer abc");
    expect(sent.get("x-other")).toBeNull();
    expect(response.headers.get("x-internal")).toBeNull();
  });

  it("forwards the body of a POST", async () => {
    const fetchImpl = upstreamOk();
    const request = new Request("https://ui.example.net/api/bff/orders", { method: "POST", body: '{"id":1}' });

    await proxyToBff(request, ["orders"], settings, fetchImpl as unknown as typeof fetch);

    const [, init] = fetchImpl.mock.calls[0];
    expect(init?.method).toBe("POST");
    expect(new TextDecoder().decode(init?.body as ArrayBuffer)).toBe('{"id":1}');
  });

  it("returns 500 when BFF_BASE_URL is missing", async () => {
    const response = await proxyToBff(new Request("https://ui.example.net/api/bff/x"), ["x"], {}, upstreamOk() as unknown as typeof fetch);
    expect(response.status).toBe(500);
  });

  it("returns 400 for a path traversal attempt without calling the BFF", async () => {
    const fetchImpl = upstreamOk();
    const response = await proxyToBff(new Request("https://ui.example.net/api/bff/x"), [".."], settings, fetchImpl as unknown as typeof fetch);
    expect(response.status).toBe(400);
    expect(fetchImpl).not.toHaveBeenCalled();
  });

  it("returns 502 when the BFF can't be reached", async () => {
    const fetchImpl = vi.fn(async () => {
      throw new Error("connect ECONNREFUSED");
    });
    const response = await proxyToBff(new Request("https://ui.example.net/api/bff/x"), ["x"], settings, fetchImpl as unknown as typeof fetch);
    expect(response.status).toBe(502);
  });
});
