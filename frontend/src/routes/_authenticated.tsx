import { createFileRoute, redirect } from "@tanstack/react-router";
import { AppLayout } from "@/components/layout/AppLayout";

export const Route = createFileRoute("/_authenticated")({
  beforeLoad: () => {
    if (!localStorage.getItem("credflow_token")) {
      throw redirect({ to: "/login" });
    }
  },
  component: AppLayout,
});
