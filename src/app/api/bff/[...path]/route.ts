import { proxyToBff } from "@/lib/bff";

export const dynamic = "force-dynamic";

type Context = { params: Promise<{ path: string[] }> };

async function handler(request: Request, { params }: Context): Promise<Response> {
  const { path } = await params;
  return proxyToBff(request, path);
}

export const GET = handler;
export const POST = handler;
export const PUT = handler;
export const PATCH = handler;
export const DELETE = handler;
