import { request } from "@playwright/test";

const SERVICE_KEY = "credflow-internal";

async function seedService(name: string, url: string) {
  const ctx = await request.newContext();
  try {
    const res = await ctx.post(url, {
      headers: { "X-Service-Key": SERVICE_KEY },
    });
    if (!res.ok()) {
      const body = await res.text();
      throw new Error(`${name} seed falhou (${res.status()}): ${body}`);
    }
    const body = await res.json();
    console.log(`[E2E] ${name} seedado:`, body);
  } finally {
    await ctx.dispose();
  }
}

export default async function globalSetup() {
  console.log("\n[E2E] Preparando bancos de test...");
  await seedService("account-service", "http://localhost:3001/internal/e2e/seed");
  await seedService("payment-service", "http://localhost:3002/internal/e2e/seed");
  console.log("[E2E] Pronto.\n");
}
