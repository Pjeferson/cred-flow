import { test, expect } from "@playwright/test";

const EMAIL = "demo@credflow.com";
const PASSWORD = "password123";

test.describe("Fluxo 1 — Login → Dashboard", () => {
  test("login com credenciais válidas redireciona para o dashboard", async ({ page }) => {
    await page.goto("/login");
    await expect(page.getByRole("heading", { name: "CredFlow" })).toBeVisible();

    await page.getByLabel("Email").fill(EMAIL);
    await page.getByLabel("Senha").fill(PASSWORD);
    await page.getByRole("button", { name: "Entrar" }).click();

    // Após login, redireciona para rota autenticada
    await expect(page).not.toHaveURL(/\/login/);
  });

  test("credenciais inválidas exibem mensagem de erro", async ({ page }) => {
    await page.goto("/login");
    await page.getByLabel("Email").fill("errado@credflow.com");
    await page.getByLabel("Senha").fill("senhaerrada");
    await page.getByRole("button", { name: "Entrar" }).click();

    await expect(page.getByText("Email ou senha inválidos")).toBeVisible();
  });

  test("rota autenticada redireciona para /login sem token", async ({ page }) => {
    // Acessa rota protegida sem estar autenticado
    await page.goto("/");
    await expect(page).toHaveURL(/\/login/);
  });
});
