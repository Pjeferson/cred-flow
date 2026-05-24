import { createFileRoute } from "@tanstack/react-router";
import { MonitoringPage } from "@/features/monitoring/MonitoringPage";

export const Route = createFileRoute("/_authenticated/monitoring")({
  component: MonitoringPage,
});
