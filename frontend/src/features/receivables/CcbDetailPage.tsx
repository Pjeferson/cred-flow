import { useNavigate } from "@tanstack/react-router";
import { IconArrowLeft } from "@tabler/icons-react";
import { useCcb } from "./useCcbs";
import { InstallmentSchedule } from "./InstallmentSchedule";
import { formatCurrency, formatDateShort } from "@/lib/formatters";
import type { CcbStatus } from "./types";

const statusBadge: Record<CcbStatus, string> = {
  active:    "bg-[#DCFCE7] text-[#16A34A]",
  settled:   "bg-[#EEF2FF] text-[#4F46E5]",
  defaulted: "bg-[#FEE2E2] text-[#DC2626]",
  cancelled: "bg-[#F4F5F7] text-[#6B7280]",
};

const statusLabel: Record<CcbStatus, string> = {
  active:    "ativa",
  settled:   "liquidada",
  defaulted: "inadimplente",
  cancelled: "cancelada",
};

export function CcbDetailPage({ ccbId }: { ccbId: string }) {
  const navigate = useNavigate();
  const { data: ccb, isLoading } = useCcb(ccbId);

  if (isLoading) {
    return (
      <div className="p-8 text-center text-[13px] text-[#9CA3AF]">
        Carregando CCB...
      </div>
    );
  }

  if (!ccb) {
    return (
      <div className="p-8 text-center text-[13px] text-[#DC2626]">
        CCB não encontrada.
      </div>
    );
  }

  const paid = ccb.installments.filter((i) => i.status === "paid").length;
  const overdue = ccb.installments.filter((i) => i.status === "overdue").length;
  const pending = ccb.installments.filter(
    (i) => i.status === "pending" || i.status === "partially_paid"
  ).length;

  const pendingAmount = ccb.installments
    .filter((i) => i.status !== "paid")
    .reduce((sum, i) => sum + (i.amount_cents - i.paid_cents), 0);

  return (
    <div className="flex flex-col h-full overflow-hidden">
      {/* Header */}
      <div className="px-6 py-4 bg-white border-b border-[#E5E7EB] flex items-center justify-between shrink-0">
        <div className="flex items-center gap-3">
          <button
            onClick={() => navigate({ to: "/ccbs" })}
            className="text-[#9CA3AF] hover:text-[#6B7280] transition-colors"
          >
            <IconArrowLeft size={16} />
          </button>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-[15px] font-medium text-[#111827]">
                CCB — {ccb.id.slice(-8).toUpperCase()}
              </h1>
              <span
                className={`text-[11px] font-medium px-2 py-0.5 rounded ${statusBadge[ccb.status]}`}
              >
                {statusLabel[ccb.status]}
              </span>
            </div>
            <p className="text-[12px] text-[#6B7280] mt-0.5">
              Emitida em {formatDateShort(ccb.issued_at)} ·{" "}
              {ccb.installment_count} parcelas ·{" "}
              {(Number(ccb.annual_rate) * 100).toFixed(2)}% a.a.
            </p>
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="p-6 flex flex-col gap-4 overflow-auto flex-1">
        {/* Summary cards */}
        <div className="grid grid-cols-3 gap-2.5">
          <div className="bg-[#F4F5F7] rounded-lg p-4">
            <p className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF] mb-1.5">
              Principal
            </p>
            <p className="text-[22px] font-medium tabular-nums text-[#111827]">
              {formatCurrency(ccb.principal_cents)}
            </p>
            <p className="text-[11px] text-[#9CA3AF] mt-0.5">
              Deságio: {formatCurrency(ccb.discount_cents)}
            </p>
          </div>

          <div className="bg-[#F4F5F7] rounded-lg p-4">
            <p className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF] mb-1.5">
              Líquido antecipado
            </p>
            <p className="text-[22px] font-medium tabular-nums text-[#16A34A]">
              {formatCurrency(ccb.net_cents)}
            </p>
            <p className="text-[11px] text-[#9CA3AF] mt-0.5">
              {paid} paga{paid !== 1 ? "s" : ""} · {pending} pendente
              {pending !== 1 ? "s" : ""} · {overdue} vencida
              {overdue !== 1 ? "s" : ""}
            </p>
          </div>

          <div className="bg-[#F4F5F7] rounded-lg p-4">
            <p className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF] mb-1.5">
              A receber
            </p>
            <p
              className={`text-[22px] font-medium tabular-nums ${
                overdue > 0 ? "text-[#DC2626]" : "text-[#4F46E5]"
              }`}
            >
              {formatCurrency(pendingAmount)}
            </p>
            <p className="text-[11px] text-[#9CA3AF] mt-0.5">
              saldo devedor
            </p>
          </div>
        </div>

        {/* Installment table */}
        <div className="bg-white border border-[#E5E7EB] rounded-xl overflow-hidden">
          <div className="px-5 py-4 border-b border-[#E5E7EB]">
            <h2 className="text-[13px] font-medium text-[#111827]">
              Cronograma de parcelas
            </h2>
          </div>
          <InstallmentSchedule installments={ccb.installments} />
        </div>
      </div>
    </div>
  );
}
