import { createFileRoute } from "@tanstack/react-router";
import { AccountsPage } from "@/features/accounts/AccountsPage";

export const Route = createFileRoute("/_authenticated/")({
  component: AccountsPage,
});
