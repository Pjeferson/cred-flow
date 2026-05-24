import { useState } from "react";
import { IconClock, IconX, IconCheck, IconBan } from "@tabler/icons-react";
import { usePaymentOrders, useCreateApproval } from "./usePaymentOrders";
import { useParticipants } from "@/features/participants/useParticipants";
import { formatCurrency, formatTTL, policyReason } from "@/lib/formatters";
import type { PaymentOrder } from "./types";

interface ActionModalProps {
  order: PaymentOrder;
  onClose: () => void;
}

function ActionModal({ order, onClose }: ActionModalProps) {
  const { data: participants } = useParticipants();
  const mutation = useCreateApproval();
  const [approverId, setApproverId] = useState("");
  const [decision, setDecision] = useState<"APPROVED" | "REJECTED">("APPROVED");
  const [error, setError] = useState<string | null>(null);

  const credores = participants?.filter((p) => p.role === "credor") ?? [];

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (!approverId) {
      setError("Selecione o aprovador.");
      return;
    }
    try {
      await mutation.mutateAsync({ paymentOrderId: order.id, approver_id: approverId, decision });
      onClose();
    } catch {
      setError("Erro ao registrar decisão. Tente novamente.");
    }
  }

  return (
    <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50">
      <div className="bg-white rounded-xl border border-[#E5E7EB] w-full max-w-sm p-6 shadow-lg">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-[14px] font-medium text-[#111827]">
            Revisar pedido
          </h2>
          <button onClick={onClose} className="text-[#9CA3AF] hover:text-[#6B7280]">
            <IconX size={18} />
          </button>
        </div>

        <div className="bg-[#F4F5F7] rounded-lg p-3 mb-4">
          <p className="text-[12px] font-medium text-[#111827]">
            {order.beneficiary_name ?? order.beneficiary_doc}
          </p>
          <p className="text-[11px] text-[#6B7280] mt-0.5">
            {order.beneficiary_doc}
            {order.policy_action ? ` · ${policyReason(order.policy_action)}` : ""}
          </p>
          <p className="text-[20px] font-medium tabular-nums text-[#111827] mt-2">
            {formatCurrency(order.amount_cents)}
          </p>
          <p className="text-[11px] text-[#6B7280] mt-1">
            Aprovações já registradas:{" "}
            <span className="text-[#4F46E5] font-medium">
              {order.approvals_count}
            </span>
          </p>
        </div>

        <form onSubmit={handleSubmit} className="flex flex-col gap-4">
          <div className="flex flex-col gap-1">
            <label className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF]">
              Você está aprovando como
            </label>
            <select
              required
              value={approverId}
              onChange={(e) => setApproverId(e.target.value)}
              className="border border-[#E5E7EB] rounded-lg px-3 py-2 text-[13px] text-[#111827] bg-white focus:outline-none focus:ring-2 focus:ring-[#C7D2FE] focus:border-[#4F46E5]"
            >
              <option value="">Selecione o aprovador...</option>
              {credores.map((p) => (
                <option key={p.id} value={p.id}>{p.name}</option>
              ))}
            </select>
          </div>

          <div className="flex gap-2">
            <button
              type="button"
              onClick={() => setDecision("APPROVED")}
              className={[
                "flex-1 flex items-center justify-center gap-1.5 py-[7px] rounded-lg text-[13px] font-medium border transition-colors",
                decision === "APPROVED"
                  ? "bg-[#DCFCE7] text-[#16A34A] border-[#86EFAC]"
                  : "bg-white text-[#6B7280] border-[#E5E7EB] hover:bg-[#F9FAFB]",
              ].join(" ")}
            >
              <IconCheck size={14} />
              Aprovar
            </button>
            <button
              type="button"
              onClick={() => setDecision("REJECTED")}
              className={[
                "flex-1 flex items-center justify-center gap-1.5 py-[7px] rounded-lg text-[13px] font-medium border transition-colors",
                decision === "REJECTED"
                  ? "bg-[#FEE2E2] text-[#DC2626] border-[#FCA5A5]"
                  : "bg-white text-[#6B7280] border-[#E5E7EB] hover:bg-[#F9FAFB]",
              ].join(" ")}
            >
              <IconBan size={14} />
              Rejeitar
            </button>
          </div>

          {error && <p className="text-[12px] text-[#DC2626]">{error}</p>}

          <div className="flex gap-2 justify-end">
            <button
              type="button"
              onClick={onClose}
              className="text-[13px] text-[#6B7280] px-3.5 py-[7px] rounded-lg hover:bg-[#F4F5F7] transition-colors"
            >
              Cancelar
            </button>
            <button
              type="submit"
              disabled={mutation.isPending}
              className="bg-[#4F46E5] text-white text-[13px] font-medium px-3.5 py-[7px] rounded-lg hover:bg-[#4338CA] disabled:opacity-50 transition-all"
            >
              {mutation.isPending ? "Registrando..." : "Confirmar decisão"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

export function ApprovalsPage() {
  const { data: orders, isLoading } = usePaymentOrders(
    undefined,
    "pending_approval"
  );
  const [reviewingId, setReviewingId] = useState<string | null>(null);

  const pending = orders ?? [];
  const reviewingOrder = pending.find((o) => o.id === reviewingId) ?? null;

  return (
    <div className="p-6 flex flex-col gap-4 overflow-auto">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-[15px] font-medium text-[#111827]">Aprovações</h1>
          <p className="text-[12px] text-[#6B7280] mt-0.5">
            Pedidos de transferência aguardando decisão de quorum
          </p>
        </div>
        {pending.length > 0 && (
          <span className="bg-[#FEF3C7] text-[#D97706] text-[11px] font-medium px-2.5 py-1 rounded-lg">
            {pending.length} pendente{pending.length > 1 ? "s" : ""}
          </span>
        )}
      </div>

      <div className="bg-white border border-[#E5E7EB] rounded-xl overflow-hidden">
        {isLoading ? (
          <div className="p-8 text-center text-[13px] text-[#9CA3AF]">
            Carregando...
          </div>
        ) : pending.length === 0 ? (
          <div className="p-8 text-center text-[13px] text-[#9CA3AF]">
            Nenhum pedido aguardando aprovação
          </div>
        ) : (
          <table className="w-full">
            <thead>
              <tr className="border-b border-[#E5E7EB]">
                {["Beneficiário", "Motivo", "Valor", "Aprovações", "Expira em", ""].map(
                  (h) => (
                    <th
                      key={h}
                      className="px-4 py-3 text-left text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF]"
                    >
                      {h}
                    </th>
                  )
                )}
              </tr>
            </thead>
            <tbody>
              {pending.map((order) => (
                <tr
                  key={order.id}
                  className="border-b border-[#E5E7EB] last:border-0 hover:bg-[#F9FAFB]"
                >
                  <td className="px-4 py-3">
                    <p className="text-[13px] font-medium text-[#111827]">
                      {order.beneficiary_name ?? "—"}
                    </p>
                    <p className="text-[11px] text-[#9CA3AF] font-mono">
                      {order.beneficiary_doc}
                    </p>
                  </td>
                  <td className="px-4 py-3 text-[12px] text-[#6B7280]">
                    {order.policy_action
                      ? policyReason(order.policy_action)
                      : "—"}
                  </td>
                  <td className="px-4 py-3 text-[13px] font-medium tabular-nums text-[#111827]">
                    {formatCurrency(order.amount_cents)}
                  </td>
                  <td className="px-4 py-3">
                    <span className="text-[12px] text-[#4F46E5] font-medium">
                      {order.approvals_count} registrada
                      {order.approvals_count !== 1 ? "s" : ""}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-[12px] text-[#D97706]">
                    {order.expires_at ? (
                      <span className="flex items-center gap-1">
                        <IconClock size={12} />
                        {formatTTL(order.expires_at)}
                      </span>
                    ) : (
                      "—"
                    )}
                  </td>
                  <td className="px-4 py-3">
                    <button
                      onClick={() => setReviewingId(order.id)}
                      className="bg-[#EEF2FF] text-[#4F46E5] border border-[#C7D2FE] text-[11px] font-medium px-2.5 py-1 rounded-md hover:bg-[#E0E7FF] transition-colors whitespace-nowrap"
                    >
                      Revisar e aprovar
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {reviewingOrder && (
        <ActionModal
          order={reviewingOrder}
          onClose={() => setReviewingId(null)}
        />
      )}
    </div>
  );
}
