import { createFileRoute, redirect, Outlet } from "@tanstack/react-router";

export const Route = createFileRoute("/_authenticated")({
  beforeLoad: () => {
    if (!localStorage.getItem("credflow_token")) {
      throw redirect({ to: "/login" });
    }
  },
  component: () => <Outlet />,
});
