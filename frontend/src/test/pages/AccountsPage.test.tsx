import { describe, it, expect, beforeEach } from "vitest";
import { screen, waitFor } from "@testing-library/react";
import { http, HttpResponse } from "msw";
import { render } from "@/test/utils";
import { server } from "@/test/server";
import { AccountsPage } from "@/features/accounts/AccountsPage";

const API = "http://localhost:8080";

const accountItem = (overrides = {}) => ({
  id: "acc-1",
  type: "account",
  attributes: {
    type: "escrow",
    status: "active",
    cedente_id: "p-1",
    credor_id: "p-2",
    sacado_id: "p-3",
    cedente_name: "Agro Norte Exportações",
    credor_name: "FIDC Capital Nordeste",
    sacado_name: "Distribuidora Alfa",
    policy_rules: { approval_required_above_cents: 100_000 },
    created_at: "2024-01-15T10:00:00.000Z",
    ...overrides,
  },
});

const participantsResponse = {
  data: [
    { id: "p-1", type: "participant", attributes: { name: "Agro Norte", document: "12.345.678/0001-90", role: "cedente", kyc_status: "approved", created_at: "2024-01-01T00:00:00Z" } },
    { id: "p-2", type: "participant", attributes: { name: "FIDC Capital", document: "45.678.901/0001-23", role: "credor", kyc_status: "approved", created_at: "2024-01-01T00:00:00Z" } },
    { id: "p-3", type: "participant", attributes: { name: "Distribuidora Alfa", document: "67.890.123/0001-41", role: "sacado", kyc_status: "approved", created_at: "2024-01-01T00:00:00Z" } },
  ],
};

beforeEach(() => {
  server.use(
    http.get(`${API}/api/v1/accounts`, () =>
      HttpResponse.json({ data: [accountItem()] })
    ),
    http.get(`${API}/api/v1/participants`, () =>
      HttpResponse.json(participantsResponse)
    )
  );
});

describe("AccountsPage", () => {
  it("renders account list after loading", async () => {
    render(<AccountsPage />);
    await waitFor(() => {
      expect(screen.getByText("Agro Norte Exportações")).toBeInTheDocument();
    });
    expect(screen.getByText("FIDC Capital Nordeste")).toBeInTheDocument();
  });

  it("shows empty state when no accounts", async () => {
    server.use(
      http.get(`${API}/api/v1/accounts`, () =>
        HttpResponse.json({ data: [] })
      )
    );
    render(<AccountsPage />);
    await waitFor(() => {
      expect(screen.getByText(/nenhuma conta cadastrada/i)).toBeInTheDocument();
    });
  });

  it("shows active status badge", async () => {
    render(<AccountsPage />);
    await waitFor(() => {
      expect(screen.getByText("ativa")).toBeInTheDocument();
    });
  });

  it("shows blocked account badge", async () => {
    server.use(
      http.get(`${API}/api/v1/accounts`, () =>
        HttpResponse.json({ data: [accountItem({ status: "blocked" })] })
      )
    );
    render(<AccountsPage />);
    await waitFor(() => {
      expect(screen.getByText("bloqueada")).toBeInTheDocument();
    });
  });
});
