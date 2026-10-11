"use client";

import { useState } from "react";

// Calls the BFF the way every page should: through this app's /api/bff/* proxy, never directly.
export function BffStatus() {
  const [result, setResult] = useState<string>("");

  async function check() {
    setResult("Checking...");
    try {
      const response = await fetch("/api/bff/health", { cache: "no-store" });
      setResult(`${response.status} ${await response.text()}`);
    } catch (error) {
      setResult(error instanceof Error ? error.message : "Request failed");
    }
  }

  return (
    <section>
      <button type="button" onClick={check}>
        Check the BFF (springboot1)
      </button>
      {result && <pre>{result}</pre>}
    </section>
  );
}
