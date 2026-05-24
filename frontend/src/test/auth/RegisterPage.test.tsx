import { describe, it, expect, beforeEach } from "vitest";
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { http, HttpResponse } from "msw";
import { render } from "@/test/utils";
import { server } from "@/test/server";
import { RegisterPage } from "@/features/auth/RegisterPage";
import { useAuthStore } from "@/store/authStore";

const API = "http://localhost:8080";

beforeEach(() => {
  localStorage.clear();
  useAuthStore.setState({ user: null, isAuthenticated: false });
});

describe("RegisterPage", () => {
  it("renders name, email and password fields", () => {
    render(<RegisterPage />);
    expect(screen.getByLabelText(/nome/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/senha/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /criar conta/i })).toBeInTheDocument();
  });

  it("renders link back to login", () => {
    render(<RegisterPage />);
    expect(screen.getByRole("link", { name: /entrar/i })).toBeInTheDocument();
  });

  it("registers user and stores token on success", async () => {
    server.use(
      http.post(`${API}/api/v1/auth/sign_up`, () =>
        HttpResponse.json(
          { message: "Signed up successfully", user: { id: "u-2", email: "new@credflow.com", name: "Novo" } },
          { headers: { Authorization: "Bearer new-jwt-token" } }
        )
      )
    );
    const user = userEvent.setup();
    render(<RegisterPage />);

    await user.type(screen.getByLabelText(/nome/i), "Novo Usuário");
    await user.type(screen.getByLabelText(/email/i), "new@credflow.com");
    await user.type(screen.getByLabelText(/senha/i), "password123");
    await user.click(screen.getByRole("button", { name: /criar conta/i }));

    await waitFor(() => {
      expect(useAuthStore.getState().isAuthenticated).toBe(true);
    });
    expect(localStorage.getItem("credflow_token")).toBe("new-jwt-token");
  });

  it("shows error message when registration fails", async () => {
    server.use(
      http.post(`${API}/api/v1/auth/sign_up`, () =>
        HttpResponse.json({ error: "Email já em uso" }, { status: 422 })
      )
    );
    const user = userEvent.setup();
    render(<RegisterPage />);

    await user.type(screen.getByLabelText(/nome/i), "Alguém");
    await user.type(screen.getByLabelText(/email/i), "existente@credflow.com");
    await user.type(screen.getByLabelText(/senha/i), "password123");
    await user.click(screen.getByRole("button", { name: /criar conta/i }));

    await waitFor(() => {
      expect(screen.getByText(/não foi possível criar a conta/i)).toBeInTheDocument();
    });
  });
});
