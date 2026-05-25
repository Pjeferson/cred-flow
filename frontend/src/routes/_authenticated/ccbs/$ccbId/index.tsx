import { createFileRoute } from "@tanstack/react-router";
import { CcbDetailPage } from "@/features/receivables/CcbDetailPage";

export const Route = createFileRoute("/_authenticated/ccbs/$ccbId/")({
  component: function CcbDetailRoute() {
    const { ccbId } = Route.useParams();
    return <CcbDetailPage ccbId={ccbId} />;
  },
});
