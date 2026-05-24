import { describe, it, expect, beforeEach } from "vitest";
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { http, HttpResponse } from "msw";
import { render } from "@/test/utils";
import { server } from "@/test/server";
import { ParticipantsPage } from "@/features/participants/ParticipantsPage";

const API = "http://localhost:8080";

const participantItem = (overrides = {}) => ({
  id: "p-1",
  type: "participant",
  attributes: {
    name: "Agro Norte Exportações S.A.",
    document: "12.345.678/0001-90",
    role: "cedente",
    kyc_status: "approved",
    created_at: "2024-01-15T10:00:00.000Z",
    ...overrides,
  },
});

beforeEach(() => {
  server.use(
    http.get(`${API}/api/v1/participants`, () =>
      HttpResponse.json({ data: [participantItem()] })
    )
  );
});

describe("ParticipantsPage", () => {
  it("renders participant list after loading", async () => {
    render(<ParticipantsPage />);
    await waitFor(() => {
      expect(screen.getByText("Agro Norte Exportações S.A.")).toBeInTheDocument();
    });
    expect(screen.getByText("12.345.678/0001-90")).toBeInTheDocument();
  });

  it("shows empty state when no participants", async () => {
    server.use(
      http.get(`${API}/api/v1/participants`, () =>
        HttpResponse.json({ data: [] })
      )
    );
    render(<ParticipantsPage />);
    await waitFor(() => {
      expect(screen.getByText(/nenhum participante cadastrado/i)).toBeInTheDocument();
    });
  });

  it("opens create modal on button click", async () => {
    const user = userEvent.setup();
    render(<ParticipantsPage />);
    await waitFor(() => screen.getByText("Agro Norte Exportações S.A."));

    await user.click(screen.getByRole("button", { name: /novo participante/i }));
    expect(screen.getByText(/novo participante/i, { selector: "h2" })).toBeInTheDocument();
  });

  it("closes modal on Cancelar", async () => {
    const user = userEvent.setup();
    render(<ParticipantsPage />);
    await waitFor(() => screen.getByText("Agro Norte Exportações S.A."));

    await user.click(screen.getByRole("button", { name: /novo participante/i }));
    await user.click(screen.getByRole("button", { name: /cancelar/i }));
    expect(screen.queryByRole("button", { name: /cancelar/i })).not.toBeInTheDocument();
  });

  it("creates participant and closes modal on success", async () => {
    server.use(
      http.post(`${API}/api/v1/participants`, () =>
        HttpResponse.json({
          data: participantItem({ name: "Novo Participante", document: "23.456.789/0001-05" }),
        })
      ),
      http.get(`${API}/api/v1/participants`, () =>
        HttpResponse.json({
          data: [participantItem(), participantItem({ id: "p-2", name: "Novo Participante" })],
        })
      )
    );

    const user = userEvent.setup();
    render(<ParticipantsPage />);
    await waitFor(() => screen.getByText("Agro Norte Exportações S.A."));

    await user.click(screen.getByRole("button", { name: /novo participante/i }));

    const inputs = screen.getAllByRole("textbox");
    await user.type(inputs[0], "Novo Participante");
    await user.type(inputs[1], "23.456.789/0001-05");

    await user.click(screen.getByRole("button", { name: /criar participante/i }));

    await waitFor(() => {
      expect(screen.queryByRole("button", { name: /cancelar/i })).not.toBeInTheDocument();
    });
  });

  it("shows KYC check button for pending participants", async () => {
    server.use(
      http.get(`${API}/api/v1/participants`, () =>
        HttpResponse.json({ data: [participantItem({ kyc_status: "pending" })] })
      )
    );
    render(<ParticipantsPage />);
    await waitFor(() => {
      expect(screen.getByRole("button", { name: /verificar kyc/i })).toBeInTheDocument();
    });
  });
});
