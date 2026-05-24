import { createFileRoute } from "@tanstack/react-router";
import { AccountDetailPage } from "@/features/accounts/AccountDetailPage";

export const Route = createFileRoute("/_authenticated/accounts/$accountId")({
  component: function AccountDetailRoute() {
    const { accountId } = Route.useParams();
    return <AccountDetailPage accountId={accountId} />;
  },
});
