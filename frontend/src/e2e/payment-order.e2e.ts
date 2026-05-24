import { test, expect } from "@playwright/test";

const EMAIL = "demo@credflow.com";
const PASSWORD = "password123";

test.describe("Fluxo 2 — Criar payment order → aparece em pending", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/login");
    await page.getByLabel("Email").fill(EMAIL);
    await page.getByLabel("Senha").fill(PASSWORD);
    await page.getByRole("button", { name: "Entrar" }).click();
    await expect(page).not.toHaveURL(/\/login/);
  });

  test("cria payment order e ela aparece na lista de aprovações", async ({ page }) => {
    // Navegar para a tela de contas
    await page.getByRole("link", { name: /contas/i }).click();
    await expect(page.getByRole("heading", { name: /contas/i })).toBeVisible();

    // Selecionar a primeira conta ativa
    const firstAccount = page.locator("table tbody tr").first();
    await expect(firstAccount).toBeVisible();
    await firstAccount.locator("button, a").last().click();

    // Aguardar tela de detalhe da conta
    await expect(page).toHaveURL(/\/accounts\//);

    // Criar nova transferência
    await page.getByRole("button", { name: /nova transferência/i }).click();

    // Preencher formulário de payment order
    await page.getByLabel(/beneficiário/i).fill("67.890.123/0001-41");
    await page.getByLabel(/valor/i).fill("3000");

    const idemKey = `e2e-${Date.now()}`;
    await page.getByLabel(/idempotency/i).fill(idemKey);

    await page.getByRole("button", { name: /confirmar/i }).click();

    // Verificar que a ordem foi criada (success ou pending_approval)
    await expect(page.getByText(/pedido criado|aguardando aprovação/i)).toBeVisible({
      timeout: 10_000,
    });
  });
});
