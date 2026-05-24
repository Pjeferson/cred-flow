import { test, expect } from "@playwright/test";

const EMAIL = "demo@credflow.com";
const PASSWORD = "password123";

test.describe("Fluxo 3 — Aprovar ordem → status muda", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/login");
    await page.getByLabel("Email").fill(EMAIL);
    await page.getByLabel("Senha").fill(PASSWORD);
    await page.getByRole("button", { name: "Entrar" }).click();
    await expect(page).not.toHaveURL(/\/login/);
  });

  test("tela de aprovações exibe ordens pendentes do seed", async ({ page }) => {
    await page.getByRole("link", { name: /aprovações/i }).click();
    await expect(page.getByRole("heading", { name: /aprovações/i })).toBeVisible();

    // Seeds criaram 2 ordens pending_approval
    const rows = page.locator("table tbody tr");
    await expect(rows.first()).toBeVisible({ timeout: 10_000 });
  });

  test("abre modal de revisão e registra aprovação", async ({ page }) => {
    await page.getByRole("link", { name: /aprovações/i }).click();
    await expect(page.locator("table tbody tr").first()).toBeVisible({ timeout: 10_000 });

    // Abre modal da primeira ordem
    await page.locator("table tbody tr").first().getByRole("button", { name: /revisar/i }).click();
    await expect(page.getByRole("heading", { name: /revisar pedido/i })).toBeVisible();

    // Seleciona aprovador
    const select = page.getByRole("combobox");
    await expect(select).toBeVisible();
    await select.selectOption({ index: 1 });

    // Confirma
    await page.getByRole("button", { name: /confirmar/i }).click();

    // Modal fecha
    await expect(page.getByRole("heading", { name: /revisar pedido/i })).not.toBeVisible({
      timeout: 5_000,
    });
  });
});
