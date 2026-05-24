import { useState } from "react";
import { useNavigate } from "@tanstack/react-router";
import { IconPlus, IconX, IconArrowRight } from "@tabler/icons-react";
import { useCcbs, useCreateCcb } from "./useCcbs";
import { useAccounts } from "@/features/accounts/useAccounts";
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

interface CreateForm {
  account_id: string;
  principal: string;
  discount: string;
  annual_rate: string;
  installment_count: string;
  first_due_date: string;
}

const EMPTY: CreateForm = {
  account_id: "",
  principal: "",
  discount: "0",
  annual_rate: "12",
  installment_count: "12",
  first_due_date: "",
};

export function CcbsPage() {
  const navigate = useNavigate();
  const { data: ccbs, isLoading } = useCcbs();
  const { data: accounts } = useAccounts();
  const mutation = useCreateCcb();

  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState<CreateForm>(EMPTY);
  const [error, setError] = useState<string | null>(null);

  function handleOpen() {
    setForm(EMPTY);
    setError(null);
    setShowModal(true);
  }

  function handleClose() {
    setShowModal(false);
    setError(null);
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    try {
      await mutation.mutateAsync({
        account_id:        form.account_id,
        principal_cents:   Math.round(Number(form.principal) * 100),
        discount_cents:    Math.round(Number(form.discount) * 100),
        annual_rate:       Number(form.annual_rate) / 100,
        installment_count: Number(form.installment_count),
        first_due_date:    form.first_due_date,
      });
      handleClose();
    } catch {
      setError("Erro ao emitir CCB. Verifique os dados e tente novamente.");
    }
  }

  return (
    <div className="p-6 flex flex-col gap-4 overflow-auto">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-[15px] font-medium text-[#111827]">CCBs</h1>
          <p className="text-[12px] text-[#6B7280] mt-0.5">
            Cédulas de Crédito Bancário emitidas na plataforma
          </p>
        </div>
        <button
          onClick={handleOpen}
          className="bg-[#4F46E5] text-white text-[13px] font-medium px-3.5 py-[7px] rounded-lg flex items-center gap-1.5 hover:bg-[#4338CA] active:scale-[0.98] transition-all"
        >
          <IconPlus size={14} />
          Emitir CCB
        </button>
      </div>

      <div className="bg-white border border-[#E5E7EB] rounded-xl overflow-hidden">
        {isLoading ? (
          <div className="p-8 text-center text-[13px] text-[#9CA3AF]">
            Carregando...
          </div>
        ) : !ccbs?.length ? (
          <div className="p-8 text-center text-[13px] text-[#9CA3AF]">
            Nenhuma CCB emitida
          </div>
        ) : (
          <table className="w-full">
            <thead>
              <tr className="border-b border-[#E5E7EB]">
                {["Conta", "Principal", "Deságio", "Líquido", "Parcelas", "Taxa a.a.", "Status", "Emitida em", ""].map(
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
              {ccbs.map((ccb) => (
                <tr
                  key={ccb.id}
                  className="border-b border-[#E5E7EB] last:border-0 hover:bg-[#F9FAFB] cursor-pointer"
                  onClick={() =>
                    navigate({ to: "/ccbs/$ccbId", params: { ccbId: ccb.id } })
                  }
                >
                  <td className="px-4 py-3 text-[12px] font-mono text-[#6B7280]">
                    {ccb.account_id.slice(-8).toUpperCase()}
                  </td>
                  <td className="px-4 py-3 text-[13px] tabular-nums font-medium text-[#111827]">
                    {formatCurrency(ccb.principal_cents)}
                  </td>
                  <td className="px-4 py-3 text-[13px] tabular-nums text-[#DC2626]">
                    {ccb.discount_cents > 0
                      ? `− ${formatCurrency(ccb.discount_cents)}`
                      : "—"}
                  </td>
                  <td className="px-4 py-3 text-[13px] tabular-nums font-medium text-[#16A34A]">
                    {formatCurrency(ccb.net_cents)}
                  </td>
                  <td className="px-4 py-3 text-[13px] text-[#6B7280]">
                    {ccb.installment_count}x
                  </td>
                  <td className="px-4 py-3 text-[13px] tabular-nums text-[#6B7280]">
                    {(Number(ccb.annual_rate) * 100).toFixed(2)}%
                  </td>
                  <td className="px-4 py-3">
                    <span
                      className={`inline-flex text-[11px] font-medium px-2 py-0.5 rounded ${statusBadge[ccb.status]}`}
                    >
                      {statusLabel[ccb.status]}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-[12px] text-[#9CA3AF]">
                    {formatDateShort(ccb.issued_at)}
                  </td>
                  <td className="px-4 py-3 text-[#9CA3AF]">
                    <IconArrowRight size={14} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {showModal && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50">
          <div className="bg-white rounded-xl border border-[#E5E7EB] w-full max-w-md p-6 shadow-lg">
            <div className="flex items-center justify-between mb-5">
              <div>
                <h2 className="text-[14px] font-medium text-[#111827]">
                  Emitir CCB
                </h2>
                <p className="text-[12px] text-[#6B7280] mt-0.5">
                  Gera cronograma de parcelas automaticamente
                </p>
              </div>
              <button onClick={handleClose} className="text-[#9CA3AF] hover:text-[#6B7280]">
                <IconX size={18} />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="flex flex-col gap-4">
              <div className="flex flex-col gap-1">
                <label className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF]">
                  Conta vinculada
                </label>
                <select
                  required
                  value={form.account_id}
                  onChange={(e) => setForm({ ...form, account_id: e.target.value })}
                  className="border border-[#E5E7EB] rounded-lg px-3 py-2 text-[13px] text-[#111827] bg-white focus:outline-none focus:ring-2 focus:ring-[#C7D2FE] focus:border-[#4F46E5]"
                >
                  <option value="">Selecione...</option>
                  {accounts?.map((a) => (
                    <option key={a.id} value={a.id}>
                      {a.cedente_name ?? a.id.slice(-8).toUpperCase()} —{" "}
                      {a.type === "escrow" ? "ESC" : "EMP"}-
                      {a.id.slice(-4).toUpperCase()}
                    </option>
                  ))}
                </select>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div className="flex flex-col gap-1">
                  <label className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF]">
                    Principal (R$)
                  </label>
                  <input
                    required
                    type="number"
                    min="1"
                    step="0.01"
                    value={form.principal}
                    onChange={(e) => setForm({ ...form, principal: e.target.value })}
                    className="border border-[#E5E7EB] rounded-lg px-3 py-2 text-[13px] text-[#111827] focus:outline-none focus:ring-2 focus:ring-[#C7D2FE] focus:border-[#4F46E5]"
                    placeholder="2000000.00"
                  />
                </div>
                <div className="flex flex-col gap-1">
                  <label className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF]">
                    Deságio (R$)
                  </label>
                  <input
                    type="number"
                    min="0"
                    step="0.01"
                    value={form.discount}
                    onChange={(e) => setForm({ ...form, discount: e.target.value })}
                    className="border border-[#E5E7EB] rounded-lg px-3 py-2 text-[13px] text-[#111827] focus:outline-none focus:ring-2 focus:ring-[#C7D2FE] focus:border-[#4F46E5]"
                    placeholder="200000.00"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div className="flex flex-col gap-1">
                  <label className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF]">
                    Taxa a.a. (%)
                  </label>
                  <input
                    required
                    type="number"
                    min="0.01"
                    step="0.01"
                    value={form.annual_rate}
                    onChange={(e) => setForm({ ...form, annual_rate: e.target.value })}
                    className="border border-[#E5E7EB] rounded-lg px-3 py-2 text-[13px] text-[#111827] focus:outline-none focus:ring-2 focus:ring-[#C7D2FE] focus:border-[#4F46E5]"
                    placeholder="12"
                  />
                </div>
                <div className="flex flex-col gap-1">
                  <label className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF]">
                    Nº de parcelas
                  </label>
                  <input
                    required
                    type="number"
                    min="1"
                    step="1"
                    value={form.installment_count}
                    onChange={(e) =>
                      setForm({ ...form, installment_count: e.target.value })
                    }
                    className="border border-[#E5E7EB] rounded-lg px-3 py-2 text-[13px] text-[#111827] focus:outline-none focus:ring-2 focus:ring-[#C7D2FE] focus:border-[#4F46E5]"
                    placeholder="12"
                  />
                </div>
              </div>

              <div className="flex flex-col gap-1">
                <label className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF]">
                  Primeiro vencimento
                </label>
                <input
                  required
                  type="date"
                  value={form.first_due_date}
                  onChange={(e) =>
                    setForm({ ...form, first_due_date: e.target.value })
                  }
                  className="border border-[#E5E7EB] rounded-lg px-3 py-2 text-[13px] text-[#111827] focus:outline-none focus:ring-2 focus:ring-[#C7D2FE] focus:border-[#4F46E5]"
                />
              </div>

              {error && <p className="text-[12px] text-[#DC2626]">{error}</p>}

              <div className="flex gap-2 justify-end mt-1">
                <button
                  type="button"
                  onClick={handleClose}
                  className="text-[13px] text-[#6B7280] px-3.5 py-[7px] rounded-lg hover:bg-[#F4F5F7] transition-colors"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  disabled={mutation.isPending}
                  className="bg-[#4F46E5] text-white text-[13px] font-medium px-3.5 py-[7px] rounded-lg hover:bg-[#4338CA] disabled:opacity-50 transition-all"
                >
                  {mutation.isPending ? "Emitindo..." : "Emitir CCB"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
