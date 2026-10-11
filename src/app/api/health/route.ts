export const dynamic = "force-dynamic";

// The pipeline checks this after each deploy: version is the build it just uploaded.
export function GET(): Response {
  return Response.json(
    { status: "ok", version: process.env.NEXT_PUBLIC_APP_VERSION ?? "local" },
    { headers: { "Cache-Control": "no-store" } },
  );
}
