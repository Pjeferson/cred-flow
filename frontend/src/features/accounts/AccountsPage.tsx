import { useState } from "react";
import { useNavigate } from "@tanstack/react-router";
import { IconPlus, IconX, IconArrowRight } from "@tabler/icons-react";
import { useAccounts, useCreateAccount } from "./useAccounts";
import { useParticipants } from "@/features/participants/useParticipants";
import { formatDateShort } from "@/lib/formatters";
import type { Account } from "./types";

const statusBadge: Record<Account["status"], string> = {
  active: "bg-[#DCFCE7] text-[#16A34A]",
  blocked: "bg-[#FEE2E2] text-[#DC2626]",
  closed: "bg-[#F4F5F7] text-[#6B7280]",
};

const statusLabel: Record<Account["status"], string> = {
  active: "ativa",
  blocked: "bloqueada",
  closed: "encerrada",
};

function accountCode(account: { id: string; type: Account["type"] }) {
  const prefix = account.type === "escrow" ? "ESC" : "EMP";
  return `${prefix}-${account.id.slice(-4).toUpperCase()}`;
}

interface CreateForm {
  type: "escrow" | "empresa";
  cedente_id: string;
  credor_id: string;
  sacado_id: string;
  approval_required_above_cents: string;
  daily_limit_cents: string;
}

const EMPTY_FORM: CreateForm = {
  type: "escrow",
  cedente_id: "",
  credor_id: "",
  sacado_id: "",
  approval_required_above_cents: "5000000",
  daily_limit_cents: "50000000",
};

export function AccountsPage() {
  const navigate = useNavigate();
  const { data: accounts, isLoading } = useAccounts();
  const { data: participants } = useParticipants();
  const createMutation = useCreateAccount();

  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState<CreateForm>(EMPTY_FORM);
  const [error, setError] = useState<string | null>(null);

  const cedentes = participants?.filter((p) => p.role === "cedente") ?? [];
  const credores = participants?.filter((p) => p.role === "credor") ?? [];
  const sacados = participants?.filter((p) => p.role === "sacado") ?? [];

  function handleOpen() {
    setForm(EMPTY_FORM);
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
      await createMutation.mutateAsync({
        type: form.type,
        cedente_id: form.cedente_id,
        credor_id: form.credor_id,
        sacado_id: form.sacado_id || undefined,
        policy_rules: {
          approval_required_above_cents: Number(form.approval_required_above_cents),
          daily_limit_cents: Number(form.daily_limit_cents),
          new_beneficiary_requires_approval: true,
          approval_threshold: { required: 2, of: 3 },
        },
      });
      handleClose();
    } catch {
      setError("Erro ao criar conta. Verifique os dados e tente novamente.");
    }
  }

  return (
    <div className="p-6 flex flex-col gap-4 overflow-auto">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-[15px] font-medium text-[#111827]">
            Contas vinculadas
          </h1>
          <p className="text-[12px] text-[#6B7280] mt-0.5">
            Todas as contas escrow e empresa da plataforma
          </p>
        </div>
        <button
          onClick={handleOpen}
          className="bg-[#4F46E5] text-white text-[13px] font-medium px-3.5 py-[7px] rounded-lg flex items-center gap-1.5 hover:bg-[#4338CA] active:scale-[0.98] transition-all"
        >
          <IconPlus size={14} />
          Nova conta
        </button>
      </div>

      {/* Table */}
      <div className="bg-white border border-[#E5E7EB] rounded-xl overflow-hidden">
        {isLoading ? (
          <div className="p-8 text-center text-[13px] text-[#9CA3AF]">
            Carregando...
          </div>
        ) : !accounts?.length ? (
          <div className="p-8 text-center text-[13px] text-[#9CA3AF]">
            Nenhuma conta cadastrada
          </div>
        ) : (
          <table className="w-full">
            <thead>
              <tr className="border-b border-[#E5E7EB]">
                {["Conta", "Cedente", "Credor", "Tipo", "Status", "Criada em", ""].map(
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
              {accounts.map((acc) => (
                <tr
                  key={acc.id}
                  className="border-b border-[#E5E7EB] last:border-0 hover:bg-[#F9FAFB] cursor-pointer"
                  onClick={() =>
                    navigate({ to: "/accounts/$accountId", params: { accountId: acc.id } })
                  }
                >
                  <td className="px-4 py-3 text-[13px] font-medium text-[#111827] font-mono">
                    {accountCode(acc)}
                  </td>
                  <td className="px-4 py-3 text-[13px] text-[#6B7280]">
                    {acc.cedente_name ?? "—"}
                  </td>
                  <td className="px-4 py-3 text-[13px] text-[#6B7280]">
                    {acc.credor_name ?? "—"}
                  </td>
                  <td className="px-4 py-3">
                    <span className="text-[11px] font-medium px-2 py-0.5 rounded bg-[#F4F5F7] text-[#6B7280]">
                      {acc.type}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <span
                      className={`inline-flex text-[11px] font-medium px-2 py-0.5 rounded ${statusBadge[acc.status]}`}
                    >
                      {statusLabel[acc.status]}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-[12px] text-[#9CA3AF]">
                    {formatDateShort(acc.created_at)}
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

      {/* Create Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50">
          <div className="bg-white rounded-xl border border-[#E5E7EB] w-full max-w-md p-6 shadow-lg">
            <div className="flex items-center justify-between mb-5">
              <h2 className="text-[14px] font-medium text-[#111827]">
                Nova conta vinculada
              </h2>
              <button onClick={handleClose} className="text-[#9CA3AF] hover:text-[#6B7280]">
                <IconX size={18} />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="flex flex-col gap-4">
              <div className="flex flex-col gap-1">
                <label className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF]">
                  Tipo
                </label>
                <select
                  value={form.type}
                  onChange={(e) =>
                    setForm({ ...form, type: e.target.value as "escrow" | "empresa" })
                  }
                  className="border border-[#E5E7EB] rounded-lg px-3 py-2 text-[13px] text-[#111827] bg-white focus:outline-none focus:ring-2 focus:ring-[#C7D2FE] focus:border-[#4F46E5]"
                >
                  <option value="escrow">Escrow</option>
                  <option value="empresa">Empresa</option>
                </select>
              </div>

              <div className="flex flex-col gap-1">
                <label className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF]">
                  Cedente
                </label>
                <select
                  required
                  value={form.cedente_id}
                  onChange={(e) => setForm({ ...form, cedente_id: e.target.value })}
                  className="border border-[#E5E7EB] rounded-lg px-3 py-2 text-[13px] text-[#111827] bg-white focus:outline-none focus:ring-2 focus:ring-[#C7D2FE] focus:border-[#4F46E5]"
                >
                  <option value="">Selecione...</option>
                  {cedentes.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.name}
                    </option>
                  ))}
                </select>
              </div>

              <div className="flex flex-col gap-1">
                <label className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF]">
                  Credor
                </label>
                <select
                  required
                  value={form.credor_id}
                  onChange={(e) => setForm({ ...form, credor_id: e.target.value })}
                  className="border border-[#E5E7EB] rounded-lg px-3 py-2 text-[13px] text-[#111827] bg-white focus:outline-none focus:ring-2 focus:ring-[#C7D2FE] focus:border-[#4F46E5]"
                >
                  <option value="">Selecione...</option>
                  {credores.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.name}
                    </option>
                  ))}
                </select>
              </div>

              {form.type === "escrow" && (
                <div className="flex flex-col gap-1">
                  <label className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF]">
                    Sacado
                  </label>
                  <select
                    required
                    value={form.sacado_id}
                    onChange={(e) => setForm({ ...form, sacado_id: e.target.value })}
                    className="border border-[#E5E7EB] rounded-lg px-3 py-2 text-[13px] text-[#111827] bg-white focus:outline-none focus:ring-2 focus:ring-[#C7D2FE] focus:border-[#4F46E5]"
                  >
                    <option value="">Selecione...</option>
                    {sacados.map((p) => (
                      <option key={p.id} value={p.id}>
                        {p.name}
                      </option>
                    ))}
                  </select>
                </div>
              )}

              <div className="grid grid-cols-2 gap-3">
                <div className="flex flex-col gap-1">
                  <label className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF]">
                    Limite p/ aprovação (R$)
                  </label>
                  <input
                    type="number"
                    required
                    value={Number(form.approval_required_above_cents) / 100}
                    onChange={(e) =>
                      setForm({
                        ...form,
                        approval_required_above_cents: String(
                          Math.round(Number(e.target.value) * 100)
                        ),
                      })
                    }
                    className="border border-[#E5E7EB] rounded-lg px-3 py-2 text-[13px] text-[#111827] focus:outline-none focus:ring-2 focus:ring-[#C7D2FE] focus:border-[#4F46E5]"
                    placeholder="50000"
                  />
                </div>
                <div className="flex flex-col gap-1">
                  <label className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF]">
                    Limite diário (R$)
                  </label>
                  <input
                    type="number"
                    required
                    value={Number(form.daily_limit_cents) / 100}
                    onChange={(e) =>
                      setForm({
                        ...form,
                        daily_limit_cents: String(
                          Math.round(Number(e.target.value) * 100)
                        ),
                      })
                    }
                    className="border border-[#E5E7EB] rounded-lg px-3 py-2 text-[13px] text-[#111827] focus:outline-none focus:ring-2 focus:ring-[#C7D2FE] focus:border-[#4F46E5]"
                    placeholder="500000"
                  />
                </div>
              </div>

              {error && (
                <p className="text-[12px] text-[#DC2626]">{error}</p>
              )}

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
                  disabled={createMutation.isPending}
                  className="bg-[#4F46E5] text-white text-[13px] font-medium px-3.5 py-[7px] rounded-lg hover:bg-[#4338CA] disabled:opacity-50 transition-all"
                >
                  {createMutation.isPending ? "Criando..." : "Criar conta"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
