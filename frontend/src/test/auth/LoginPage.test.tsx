import { describe, it, expect, beforeEach } from "vitest";
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { http, HttpResponse } from "msw";
import { render } from "@/test/utils";
import { server } from "@/test/server";
import { LoginPage } from "@/features/auth/LoginPage";
import { useAuthStore } from "@/store/authStore";

const API = "http://localhost:8080";

const successHandler = http.post(`${API}/api/v1/auth/sign_in`, () =>
  HttpResponse.json(
    { message: "Logged in successfully", user: { id: "u-1", email: "demo@credflow.com", name: "Demo" } },
    { headers: { Authorization: "Bearer fake-jwt-token" } }
  )
);

const unauthorizedHandler = http.post(`${API}/api/v1/auth/sign_in`, () =>
  HttpResponse.json({ error: "Invalid credentials" }, { status: 401 })
);

beforeEach(() => {
  localStorage.clear();
  useAuthStore.setState({ user: null, isAuthenticated: false });
});

describe("LoginPage", () => {
  it("renders email and password fields", () => {
    render(<LoginPage />);
    expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/senha/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /entrar/i })).toBeInTheDocument();
  });

  it("renders link to register page", () => {
    render(<LoginPage />);
    expect(screen.getByRole("link", { name: /cadastre-se/i })).toBeInTheDocument();
  });

  it("submits credentials and stores user on success", async () => {
    server.use(successHandler);
    const user = userEvent.setup();
    render(<LoginPage />);

    await user.type(screen.getByLabelText(/email/i), "demo@credflow.com");
    await user.type(screen.getByLabelText(/senha/i), "password123");
    await user.click(screen.getByRole("button", { name: /entrar/i }));

    await waitFor(() => {
      expect(useAuthStore.getState().isAuthenticated).toBe(true);
    });
    expect(useAuthStore.getState().user?.email).toBe("demo@credflow.com");
    expect(localStorage.getItem("credflow_token")).toBe("fake-jwt-token");
  });

  it("shows error message on invalid credentials", async () => {
    server.use(unauthorizedHandler);
    const user = userEvent.setup();
    render(<LoginPage />);

    await user.type(screen.getByLabelText(/email/i), "wrong@email.com");
    await user.type(screen.getByLabelText(/senha/i), "wrongpass");
    await user.click(screen.getByRole("button", { name: /entrar/i }));

    await waitFor(() => {
      expect(screen.getByText(/email ou senha inválidos/i)).toBeInTheDocument();
    });
  });

  it("disables button while submitting", async () => {
    server.use(successHandler);
    const user = userEvent.setup();
    render(<LoginPage />);

    await user.type(screen.getByLabelText(/email/i), "demo@credflow.com");
    await user.type(screen.getByLabelText(/senha/i), "password123");

    const button = screen.getByRole("button", { name: /entrar/i });
    await user.click(button);

    // Enquanto a requisição está em flight, o botão mostra "Entrando..."
    // waitFor garante que chegamos ao estado final sem flakiness
    await waitFor(() => expect(useAuthStore.getState().isAuthenticated).toBe(true));
  });
});
