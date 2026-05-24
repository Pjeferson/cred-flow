import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { Participant } from "./types";

interface JsonApiItem<T> {
  id: string;
  type: string;
  attributes: T;
}

export function useParticipants() {
  return useQuery({
    queryKey: ["participants"],
    queryFn: async () => {
      const res: { data: JsonApiItem<Omit<Participant, "id">>[] } = await api
        .get("api/v1/participants")
        .json();
      return res.data.map((item) => ({ id: item.id, ...item.attributes }));
    },
  });
}

export function useCreateParticipant() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (payload: {
      name: string;
      document: string;
      role: string;
      email?: string;
    }) =>
      api
        .post("api/v1/participants", { json: { participant: payload } })
        .json(),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["participants"] }),
  });
}

export function useKycCheck() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) =>
      api.post(`api/v1/participants/${id}/kyc_check`).json(),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["participants"] }),
  });
}
