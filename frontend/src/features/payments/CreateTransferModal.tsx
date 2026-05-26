import { useState } from "react";
import { IconX, IconArrowUpRight } from "@tabler/icons-react";
import { useCreatePaymentOrder } from "./usePaymentOrders";
import { useAuthStore } from "@/store/authStore";

interface Props {
  accountId: string;
  onClose: () => void;
}

interface Form {
  amount: string;
  beneficiary_doc: string;
  beneficiary_name: string;
}

const EMPTY: Form = { amount: "", beneficiary_doc: "", beneficiary_name: "" };

const REJECTION_MESSAGES: Record<string, string> = {
  daily_limit_exceeded: "Limite diário atingido. O valor solicitado ultrapassa o limite configurado para esta conta.",
  insufficient_balance: "Saldo insuficiente. Verifique o saldo disponível antes de tentar novamente.",
};

function rejectionMessage(reason: string | null): string {
  if (!reason) return "Pedido rejeitado pelo motor de aprovação.";
  return REJECTION_MESSAGES[reason] ?? `Pedido rejeitado: ${reason}.`;
}

export function CreateTransferModal({ accountId, onClose }: Props) {
  const user = useAuthStore((s) => s.user);
  const mutation = useCreatePaymentOrder();
  const [form, setForm] = useState<Form>(EMPTY);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

    const amount_cents = Math.round(Number(form.amount) * 100);
    if (!amount_cents || amount_cents <= 0) {
      setError("Informe um valor válido.");
      return;
    }

    try {
      const result = await mutation.mutateAsync({
        account_id: accountId,
        requested_by: user?.id ?? "",
        amount_cents,
        beneficiary_doc: form.beneficiary_doc,
        beneficiary_name: form.beneficiary_name || undefined,
      });

      const order = result.data.attributes;
      if (order.status === "rejected") {
        setError(rejectionMessage(order.rejection_reason));
        return;
      }

      onClose();
    } catch {
      setError("Erro ao criar pedido. Verifique os dados e tente novamente.");
    }
  }

  return (
    <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50">
      <div className="bg-white rounded-xl border border-[#E5E7EB] w-full max-w-md p-6 shadow-lg">
        <div className="flex items-center justify-between mb-5">
          <div>
            <h2 className="text-[14px] font-medium text-[#111827]">
              Nova transferência
            </h2>
            <p className="text-[12px] text-[#6B7280] mt-0.5">
              Pedido passa pelo motor de aprovação automaticamente
            </p>
          </div>
          <button onClick={onClose} className="text-[#9CA3AF] hover:text-[#6B7280]">
            <IconX size={18} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="flex flex-col gap-4">
          <div className="flex flex-col gap-1">
            <label htmlFor="transfer-amount" className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF]">
              Valor (R$)
            </label>
            <input
              id="transfer-amount"
              required
              type="number"
              min="0.01"
              step="0.01"
              value={form.amount}
              onChange={(e) => setForm({ ...form, amount: e.target.value })}
              className="border border-[#E5E7EB] rounded-lg px-3 py-2 text-[13px] text-[#111827] tabular-nums focus:outline-none focus:ring-2 focus:ring-[#C7D2FE] focus:border-[#4F46E5]"
              placeholder="50000.00"
            />
          </div>

          <div className="flex flex-col gap-1">
            <label htmlFor="transfer-beneficiary-doc" className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF]">
              CNPJ / CPF do beneficiário
            </label>
            <input
              id="transfer-beneficiary-doc"
              required
              value={form.beneficiary_doc}
              onChange={(e) =>
                setForm({ ...form, beneficiary_doc: e.target.value })
              }
              className="border border-[#E5E7EB] rounded-lg px-3 py-2 text-[13px] text-[#111827] font-mono focus:outline-none focus:ring-2 focus:ring-[#C7D2FE] focus:border-[#4F46E5]"
              placeholder="12.345.678/0001-99"
            />
          </div>

          <div className="flex flex-col gap-1">
            <label htmlFor="transfer-beneficiary-name" className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF]">
              Nome do beneficiário (opcional)
            </label>
            <input
              id="transfer-beneficiary-name"
              value={form.beneficiary_name}
              onChange={(e) =>
                setForm({ ...form, beneficiary_name: e.target.value })
              }
              className="border border-[#E5E7EB] rounded-lg px-3 py-2 text-[13px] text-[#111827] focus:outline-none focus:ring-2 focus:ring-[#C7D2FE] focus:border-[#4F46E5]"
              placeholder="Fornecedores S.A."
            />
          </div>

          {error && <p className="text-[12px] text-[#DC2626]">{error}</p>}

          <div className="flex gap-2 justify-end mt-1">
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
              className="bg-[#4F46E5] text-white text-[13px] font-medium px-3.5 py-[7px] rounded-lg flex items-center gap-1.5 hover:bg-[#4338CA] disabled:opacity-50 transition-all"
            >
              <IconArrowUpRight size={14} />
              {mutation.isPending ? "Enviando..." : "Enviar pedido"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
