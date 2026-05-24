import { createFileRoute } from "@tanstack/react-router";
import { ApprovalsPage } from "@/features/payments/ApprovalsPage";

export const Route = createFileRoute("/_authenticated/approvals")({
  component: ApprovalsPage,
});
