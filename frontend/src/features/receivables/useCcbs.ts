import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { Ccb, CcbWithInstallments, Installment } from "./types";

interface JsonApiItem<T> {
  id: string;
  type: string;
  attributes: T;
}

function flatten<T>(item: JsonApiItem<T>): { id: string } & T {
  return { id: item.id, ...item.attributes };
}

export function useCcbs(accountId?: string) {
  return useQuery({
    queryKey: ["ccbs", { accountId }],
    queryFn: async () => {
      const searchParams: Record<string, string> = {};
      if (accountId) searchParams.account_id = accountId;
      const res: { data: JsonApiItem<Omit<Ccb, "id">>[] } = await api
        .get("api/v1/ccbs", { searchParams })
        .json();
      return res.data.map(flatten);
    },
  });
}

export function useCcb(id: string) {
  return useQuery({
    queryKey: ["ccbs", id],
    queryFn: async () => {
      const res: {
        data: JsonApiItem<Omit<Ccb, "id">>;
        included?: JsonApiItem<Omit<Installment, "id">>[];
      } = await api.get(`api/v1/ccbs/${id}`).json();

      const ccb = flatten(res.data);
      const installments = (res.included ?? [])
        .filter((i) => i.type === "installment")
        .map(flatten)
        .sort((a, b) => a.number - b.number);

      return { ...ccb, installments } as CcbWithInstallments;
    },
    enabled: !!id,
  });
}

export function useCreateCcb() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (payload: {
      account_id: string;
      principal_cents: number;
      discount_cents: number;
      annual_rate: number;
      installment_count: number;
      first_due_date: string;
    }) =>
      api
        .post("api/v1/ccbs", { json: { ccb: payload } })
        .json<{ data: JsonApiItem<Omit<Ccb, "id">> }>(),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["ccbs"] }),
  });
}
