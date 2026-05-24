import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { Account, Balance, LedgerEntry } from "./types";

interface JsonApiItem<T> {
  id: string;
  type: string;
  attributes: T;
}

function flatten<T>(item: JsonApiItem<T>): { id: string } & T {
  return { id: item.id, ...item.attributes };
}

export function useAccounts() {
  return useQuery({
    queryKey: ["accounts"],
    queryFn: async () => {
      const res: { data: JsonApiItem<Omit<Account, "id">>[] } = await api
        .get("api/v1/accounts")
        .json();
      return res.data.map(flatten);
    },
  });
}

export function useAccount(id: string) {
  return useQuery({
    queryKey: ["accounts", id],
    queryFn: async () => {
      const res: { data: JsonApiItem<Omit<Account, "id">> } = await api
        .get(`api/v1/accounts/${id}`)
        .json();
      return flatten(res.data);
    },
    enabled: !!id,
  });
}

export function useAccountBalance(id: string) {
  return useQuery({
    queryKey: ["accounts", id, "balance"],
    queryFn: async (): Promise<Balance> =>
      api.get(`api/v1/accounts/${id}/balance`).json(),
    enabled: !!id,
  });
}

export function useLedgerEntries(accountId: string, page = 1) {
  return useQuery({
    queryKey: ["accounts", accountId, "ledger_entries", page],
    queryFn: async () => {
      const res: { data: JsonApiItem<Omit<LedgerEntry, "id">>[] } = await api
        .get(`api/v1/accounts/${accountId}/ledger_entries`, {
          searchParams: { page, per_page: 10 },
        })
        .json();
      return res.data.map(flatten);
    },
    enabled: !!accountId,
  });
}

interface LedgerMeta {
  total_count: number;
  total_pages: number;
  current_page: number;
  per_page: number;
}

export function useStatementEntries(accountId: string, page = 1) {
  return useQuery({
    queryKey: ["accounts", accountId, "statement", page],
    queryFn: async () => {
      const res: {
        data: JsonApiItem<Omit<LedgerEntry, "id">>[];
        meta?: LedgerMeta;
      } = await api
        .get(`api/v1/accounts/${accountId}/ledger_entries`, {
          searchParams: { page, per_page: 20 },
        })
        .json();
      return {
        entries: res.data.map(flatten),
        meta: res.meta,
      };
    },
    enabled: !!accountId,
  });
}

export function useCreateAccount() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (payload: {
      type: string;
      cedente_id: string;
      credor_id: string;
      sacado_id?: string;
      policy_rules?: Record<string, unknown>;
    }) => api.post("api/v1/accounts", { json: { account: payload } }).json(),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["accounts"] }),
  });
}
