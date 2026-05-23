import { createFileRoute, redirect } from "@tanstack/react-router";
import { RegisterPage } from "@/features/auth/RegisterPage";

export const Route = createFileRoute("/register")({
  beforeLoad: () => {
    if (localStorage.getItem("credflow_token")) {
      throw redirect({ to: "/" });
    }
  },
  component: RegisterPage,
});
