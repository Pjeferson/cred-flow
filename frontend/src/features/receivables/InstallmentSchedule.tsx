import { formatCurrency, formatDateOnly } from "@/lib/formatters";
import type { Installment, InstallmentStatus } from "./types";

const statusBadge: Record<InstallmentStatus, string> = {
  pending:       "bg-[#F4F5F7] text-[#6B7280]",
  partially_paid:"bg-[#FEF3C7] text-[#D97706]",
  paid:          "bg-[#DCFCE7] text-[#16A34A]",
  overdue:       "bg-[#FEE2E2] text-[#DC2626]",
};

const statusLabel: Record<InstallmentStatus, string> = {
  pending:       "pendente",
  partially_paid:"parcial",
  paid:          "pago",
  overdue:       "vencido",
};

function paidColor(inst: Installment): string {
  if (inst.status === "paid") return "#16A34A";
  if (inst.status === "overdue") return "#DC2626";
  if (inst.paid_cents > 0) return "#D97706";
  return "#9CA3AF";
}

interface Props {
  installments: Installment[];
}

export function InstallmentSchedule({ installments }: Props) {
  if (!installments.length) {
    return (
      <p className="text-[13px] text-[#9CA3AF] py-6 text-center">
        Nenhuma parcela encontrada
      </p>
    );
  }

  return (
    <table className="w-full">
      <thead>
        <tr className="border-b border-[#E5E7EB]">
          {["#", "Vencimento", "Valor", "Pago", "Status"].map((h) => (
            <th
              key={h}
              className="px-4 py-3 text-left text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF]"
            >
              {h}
            </th>
          ))}
        </tr>
      </thead>
      <tbody>
        {installments.map((inst) => (
          <tr
            key={inst.id}
            className={[
              "border-b border-[#E5E7EB] last:border-0 text-[12px]",
              inst.status === "overdue" ? "bg-[#FEF2F2]" : "",
            ].join(" ")}
          >
            <td className="px-4 py-2.5 text-[#6B7280] w-10">{inst.number}</td>
            <td className="px-4 py-2.5 text-[#6B7280]">
              {formatDateOnly(inst.due_date)}
            </td>
            <td className="px-4 py-2.5 tabular-nums font-medium text-[#111827]">
              {formatCurrency(inst.amount_cents)}
            </td>
            <td
              className="px-4 py-2.5 tabular-nums font-medium"
              style={{ color: paidColor(inst) }}
            >
              {inst.paid_cents > 0 ? formatCurrency(inst.paid_cents) : "—"}
            </td>
            <td className="px-4 py-2.5">
              <span
                className={`inline-flex items-center text-[11px] font-medium px-2 py-0.5 rounded ${statusBadge[inst.status]}`}
              >
                {statusLabel[inst.status]}
              </span>
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
