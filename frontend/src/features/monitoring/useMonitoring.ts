import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { MonitoringData } from "./types";

export function useMonitoring() {
  return useQuery<MonitoringData>({
    queryKey: ["monitoring"],
    queryFn: () => api.get("api/v1/monitoring").json<MonitoringData>(),
    refetchInterval: 30_000,
  });
}
