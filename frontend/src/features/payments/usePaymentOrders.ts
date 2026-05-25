import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { PaymentOrder } from "./types";

interface JsonApiItem<T> {
  id: string;
  type: string;
  attributes: T;
}

function flatten<T>(item: JsonApiItem<T>): { id: string } & T {
  return { id: item.id, ...item.attributes };
}

export function usePaymentOrders(accountId?: string, status?: string) {
  return useQuery({
    queryKey: ["payment_orders", { accountId, status }],
    queryFn: async () => {
      const searchParams: Record<string, string> = {};
      if (accountId) searchParams.account_id = accountId;
      if (status) searchParams.status = status;
      const res: { data: JsonApiItem<Omit<PaymentOrder, "id">>[] } = await api
        .get("api/v1/payment_orders", { searchParams })
        .json();
      return res.data.map(flatten);
    },
  });
}

export function useCreatePaymentOrder() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (payload: {
      account_id: string;
      requested_by: string;
      amount_cents: number;
      beneficiary_doc: string;
      beneficiary_name?: string;
    }) => {
      const idempotencyKey = crypto.randomUUID();
      return api
        .post("api/v1/payment_orders", {
          json: { payment_order: payload },
          headers: { "Idempotency-Key": idempotencyKey },
        })
        .json<{ data: JsonApiItem<Omit<PaymentOrder, "id">> }>();
    },
    onSuccess: (_data, variables) => {
      qc.invalidateQueries({ queryKey: ["payment_orders"] });
      qc.invalidateQueries({
        queryKey: ["accounts", variables.account_id, "balance"],
      });
      qc.invalidateQueries({
        queryKey: ["accounts", variables.account_id, "ledger_entries"],
      });
    },
  });
}

export function useCreateApproval() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({
      paymentOrderId,
      approver_id,
      decision,
    }: {
      paymentOrderId: string;
      approver_id: string;
      decision: "APPROVED" | "REJECTED";
    }) =>
      api
        .post(`api/v1/payment_orders/${paymentOrderId}/approvals`, {
          json: { approval: { approver_id, decision } },
        })
        .json(),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["payment_orders"] });
    },
  });
}
