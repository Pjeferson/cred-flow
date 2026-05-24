import { describe, it, expect, beforeEach } from "vitest";
import { screen, waitFor } from "@testing-library/react";
import { http, HttpResponse } from "msw";
import { render } from "@/test/utils";
import { server } from "@/test/server";
import { MonitoringPage } from "@/features/monitoring/MonitoringPage";

const API = "http://localhost:8080";

const monitoringResponse = {
  reconciliation: {
    total_runs: 21,
    completed: 20,
    with_divergences: 1,
    runs: [
      {
        id: "run-1",
        account_id: "acc-1",
        reference_date: "2024-06-10",
        status: "completed",
        entries_checked: 12,
        divergences_found: 2,
        ran_at: "2024-06-10T02:00:00.000Z",
        finished_at: "2024-06-10T02:05:00.000Z",
        duration_s: 300,
        error_message: null,
      },
      {
        id: "run-2",
        account_id: "acc-2",
        reference_date: "2024-06-09",
        status: "failed",
        entries_checked: 0,
        divergences_found: 0,
        ran_at: "2024-06-09T02:00:00.000Z",
        finished_at: "2024-06-09T02:01:00.000Z",
        duration_s: 60,
        error_message: "spb_connection_timeout",
      },
    ],
  },
  overdue: {
    count: 7,
    total_amount_cents: 280_000,
    oldest_due_date: "2024-05-01",
  },
  dlq: {
    messages: 0,
    messages_ready: 0,
    consumers: 1,
    error: null,
  },
};

beforeEach(() => {
  server.use(
    http.get(`${API}/api/v1/monitoring`, () =>
      HttpResponse.json(monitoringResponse)
    )
  );
});

describe("MonitoringPage", () => {
  it("renders reconciliation metric cards", async () => {
    render(<MonitoringPage />);
    await waitFor(() => {
      expect(screen.getByText("21")).toBeInTheDocument();
    });
    expect(screen.getByText("1")).toBeInTheDocument();
  });

  it("renders overdue count metric", async () => {
    render(<MonitoringPage />);
    await waitFor(() => {
      expect(screen.getByText("7")).toBeInTheDocument();
    });
  });

  it("shows overdue alert banner when count > 0", async () => {
    render(<MonitoringPage />);
    await waitFor(() => {
      expect(screen.getByText(/em atraso totalizando/i)).toBeInTheDocument();
    });
  });

  it("does not show overdue alert when count is zero", async () => {
    server.use(
      http.get(`${API}/api/v1/monitoring`, () =>
        HttpResponse.json({
          ...monitoringResponse,
          overdue: { count: 0, total_amount_cents: 0, oldest_due_date: null },
        })
      )
    );
    render(<MonitoringPage />);
    await waitFor(() => screen.getByText("21"));
    expect(screen.queryByText(/em atraso totalizando/i)).not.toBeInTheDocument();
  });

  it("renders reconciliation runs table with status badges", async () => {
    render(<MonitoringPage />);
    await waitFor(() => {
      expect(screen.getByText("concluído")).toBeInTheDocument();
    });
    expect(screen.getByText("falhou")).toBeInTheDocument();
  });

  it("shows DLQ messages count", async () => {
    server.use(
      http.get(`${API}/api/v1/monitoring`, () =>
        HttpResponse.json({
          ...monitoringResponse,
          dlq: { messages: 3, messages_ready: 3, consumers: 0, error: null },
        })
      )
    );
    render(<MonitoringPage />);
    await waitFor(() => {
      expect(screen.getByText("3")).toBeInTheDocument();
    });
  });
});
