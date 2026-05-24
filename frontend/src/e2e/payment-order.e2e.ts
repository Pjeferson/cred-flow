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
    await page.getByRole("link", { name: /conta vinculada/i }).click();
    await expect(page.getByRole("heading", { name: /contas vinculadas/i })).toBeVisible();

    // Selecionar a primeira conta ativa
    const firstAccount = page.locator("table tbody tr").first();
    await expect(firstAccount).toBeVisible();
    await firstAccount.click();

    // Aguardar tela de detalhe da conta
    await expect(page).toHaveURL(/\/accounts\//);

    // Criar nova transferência
    await page.getByRole("button", { name: /nova transferência/i }).click();

    // Preencher formulário de payment order
    await page.getByLabel(/valor/i).fill("3000");
    await page.getByLabel(/cnpj \/ cpf do beneficiário/i).fill("67.890.123/0001-41");

    await page.getByRole("button", { name: /enviar pedido/i }).click();

    // Modal fecha após criação bem-sucedida
    await expect(page.getByRole("button", { name: /enviar pedido/i })).not.toBeVisible({
      timeout: 10_000,
    });

    // Ordem aparece na fila de aprovação da conta
    await expect(page.getByRole("button", { name: /revisar e aprovar/i }).first()).toBeVisible({
      timeout: 10_000,
    });
  });
});
