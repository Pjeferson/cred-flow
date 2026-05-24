import { createFileRoute } from "@tanstack/react-router";
import { StatementPage } from "@/features/accounts/StatementPage";

export const Route = createFileRoute(
  "/_authenticated/accounts/$accountId/statement"
)({
  component: function StatementRoute() {
    const { accountId } = Route.useParams();
    return <StatementPage accountId={accountId} />;
  },
});
