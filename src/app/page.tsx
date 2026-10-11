import { BffStatus } from "./bff-status";

export default function Home() {
  return (
    <main>
      <h1>nextjs1</h1>
      <p>Environment: {process.env.NEXT_PUBLIC_ENVIRONMENT ?? "local"}</p>
      <BffStatus />
    </main>
  );
}
