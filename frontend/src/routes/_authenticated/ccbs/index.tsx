import { createFileRoute } from "@tanstack/react-router";
import { CcbsPage } from "@/features/receivables/CcbsPage";

export const Route = createFileRoute("/_authenticated/ccbs/")({
  component: CcbsPage,
});
