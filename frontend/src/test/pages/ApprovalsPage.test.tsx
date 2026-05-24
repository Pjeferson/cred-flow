import { describe, it, expect, beforeEach } from "vitest";
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { http, HttpResponse } from "msw";
import { render } from "@/test/utils";
import { server } from "@/test/server";
import { ApprovalsPage } from "@/features/payments/ApprovalsPage";

const API = "http://localhost:8080";

const orderItem = (overrides = {}) => ({
  id: "ord-1",
  type: "payment_order",
  attributes: {
    account_id: "acc-1",
    requested_by: "u-1",
    amount_cents: 250_000,
    beneficiary_doc: "67.890.123/0001-41",
    beneficiary_name: "Distribuidora Alfa Ltda",
    status: "pending_approval",
    policy_action: "amount_threshold",
    rejection_reason: null,
    spb_transaction_id: null,
    idempotency_key: "key-1",
    scheduled_for: null,
    expires_at: new Date(Date.now() + 3_600_000).toISOString(),
    executed_at: null,
    settled_at: null,
    created_at: "2024-06-01T10:00:00.000Z",
    approvals_count: 1,
    ...overrides,
  },
});

const participantsResponse = {
  data: [
    { id: "p-1", type: "participant", attributes: { name: "FIDC Capital Nordeste", document: "45.678.901/0001-23", role: "credor", kyc_status: "approved", created_at: "2024-01-01T00:00:00Z" } },
  ],
};

beforeEach(() => {
  server.use(
    http.get(`${API}/api/v1/payment_orders`, () =>
      HttpResponse.json({ data: [orderItem()] })
    ),
    http.get(`${API}/api/v1/participants`, () =>
      HttpResponse.json(participantsResponse)
    )
  );
});

describe("ApprovalsPage", () => {
  it("renders pending order list after loading", async () => {
    render(<ApprovalsPage />);
    await waitFor(() => {
      expect(screen.getByText("Distribuidora Alfa Ltda")).toBeInTheDocument();
    });
    expect(screen.getByText("R$ 2.500,00")).toBeInTheDocument();
  });

  it("shows empty state when no pending orders", async () => {
    server.use(
      http.get(`${API}/api/v1/payment_orders`, () =>
        HttpResponse.json({ data: [] })
      )
    );
    render(<ApprovalsPage />);
    await waitFor(() => {
      expect(screen.getByText(/nenhum pedido aguardando aprovação/i)).toBeInTheDocument();
    });
  });

  it("opens action modal on review click", async () => {
    const user = userEvent.setup();
    render(<ApprovalsPage />);
    await waitFor(() => screen.getByText("Distribuidora Alfa Ltda"));

    await user.click(screen.getByRole("button", { name: /revisar/i }));
    expect(screen.getByText(/revisar pedido/i, { selector: "h2" })).toBeInTheDocument();
    // O valor aparece na lista e no modal; verifica que existe pelo menos uma ocorrência
    expect(screen.getAllByText("R$ 2.500,00").length).toBeGreaterThanOrEqual(1);
  });

  it("closes modal on X button", async () => {
    const user = userEvent.setup();
    render(<ApprovalsPage />);
    await waitFor(() => screen.getByText("Distribuidora Alfa Ltda"));

    await user.click(screen.getByRole("button", { name: /revisar/i }));
    const closeButtons = screen.getAllByRole("button");
    const xButton = closeButtons.find((b) => b.querySelector("svg"));
    if (xButton) await user.click(xButton);

    await waitFor(() => {
      expect(screen.queryByText(/revisar pedido/i, { selector: "h2" })).not.toBeInTheDocument();
    });
  });

  it("submits approval decision and closes modal", async () => {
    server.use(
      http.post(`${API}/api/v1/payment_orders/:id/approvals`, () =>
        HttpResponse.json({ data: { id: "appr-1", type: "approval", attributes: { decision: "APPROVED" } } })
      )
    );

    const user = userEvent.setup();
    render(<ApprovalsPage />);
    await waitFor(() => screen.getByText("Distribuidora Alfa Ltda"));

    await user.click(screen.getByRole("button", { name: /revisar/i }));
    await waitFor(() => screen.getByRole("combobox"));

    const select = screen.getByRole("combobox");
    await user.selectOptions(select, "p-1");

    await user.click(screen.getByRole("button", { name: /confirmar/i }));

    await waitFor(() => {
      expect(screen.queryByText(/revisar pedido/i, { selector: "h2" })).not.toBeInTheDocument();
    });
  });
});
