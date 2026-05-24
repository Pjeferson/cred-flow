import { useState } from "react";
import { IconPlus, IconX, IconRefresh } from "@tabler/icons-react";
import { useParticipants, useCreateParticipant, useKycCheck } from "./useParticipants";
import { formatDateShort } from "@/lib/formatters";
import type { Participant } from "./types";

const kycBadge: Record<Participant["kyc_status"], string> = {
  approved: "bg-[#DCFCE7] text-[#16A34A]",
  pending: "bg-[#FEF3C7] text-[#D97706]",
  rejected: "bg-[#FEE2E2] text-[#DC2626]",
};

const kycLabel: Record<Participant["kyc_status"], string> = {
  approved: "aprovado",
  pending: "pendente",
  rejected: "rejeitado",
};

const roleBadge: Record<Participant["role"], string> = {
  cedente: "bg-[#EEF2FF] text-[#4F46E5]",
  credor: "bg-[#F4F5F7] text-[#6B7280]",
  sacado: "bg-[#FEF3C7] text-[#D97706]",
};

const ROLES = ["cedente", "credor", "sacado"] as const;

interface CreateForm {
  name: string;
  document: string;
  role: string;
  email: string;
}

const EMPTY_FORM: CreateForm = { name: "", document: "", role: "cedente", email: "" };

export function ParticipantsPage() {
  const { data: participants, isLoading } = useParticipants();
  const createMutation = useCreateParticipant();
  const kycMutation = useKycCheck();

  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState<CreateForm>(EMPTY_FORM);
  const [error, setError] = useState<string | null>(null);

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
        name: form.name,
        document: form.document,
        role: form.role,
        email: form.email || undefined,
      });
      handleClose();
    } catch {
      setError("Erro ao criar participante. Verifique os dados e tente novamente.");
    }
  }

  return (
    <div className="p-6 flex flex-col gap-4 overflow-auto">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-[15px] font-medium text-[#111827]">Participantes</h1>
          <p className="text-[12px] text-[#6B7280] mt-0.5">
            Cedentes, credores e sacados cadastrados na plataforma
          </p>
        </div>
        <button
          onClick={handleOpen}
          className="bg-[#4F46E5] text-white text-[13px] font-medium px-3.5 py-[7px] rounded-lg flex items-center gap-1.5 hover:bg-[#4338CA] active:scale-[0.98] transition-all"
        >
          <IconPlus size={14} />
          Novo participante
        </button>
      </div>

      {/* Table */}
      <div className="bg-white border border-[#E5E7EB] rounded-xl overflow-hidden">
        {isLoading ? (
          <div className="p-8 text-center text-[13px] text-[#9CA3AF]">
            Carregando...
          </div>
        ) : !participants?.length ? (
          <div className="p-8 text-center text-[13px] text-[#9CA3AF]">
            Nenhum participante cadastrado
          </div>
        ) : (
          <table className="w-full">
            <thead>
              <tr className="border-b border-[#E5E7EB]">
                {["Nome", "Documento", "Função", "KYC", "Criado em", ""].map((h) => (
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
              {participants.map((p) => (
                <tr
                  key={p.id}
                  className="border-b border-[#E5E7EB] last:border-0 hover:bg-[#F9FAFB]"
                >
                  <td className="px-4 py-3 text-[13px] font-medium text-[#111827]">
                    {p.name}
                  </td>
                  <td className="px-4 py-3 text-[13px] text-[#6B7280] font-mono">
                    {p.document}
                  </td>
                  <td className="px-4 py-3">
                    <span
                      className={`inline-flex items-center text-[11px] font-medium px-2 py-0.5 rounded ${roleBadge[p.role]}`}
                    >
                      {p.role}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <span
                      className={`inline-flex items-center text-[11px] font-medium px-2 py-0.5 rounded ${kycBadge[p.kyc_status]}`}
                    >
                      {kycLabel[p.kyc_status]}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-[12px] text-[#9CA3AF]">
                    {formatDateShort(p.created_at)}
                  </td>
                  <td className="px-4 py-3">
                    {p.kyc_status === "pending" && (
                      <button
                        onClick={() => kycMutation.mutate(p.id)}
                        disabled={kycMutation.isPending}
                        className="flex items-center gap-1 text-[12px] text-[#4F46E5] hover:underline disabled:opacity-50"
                      >
                        <IconRefresh size={12} />
                        Verificar KYC
                      </button>
                    )}
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
                Novo participante
              </h2>
              <button onClick={handleClose} className="text-[#9CA3AF] hover:text-[#6B7280]">
                <IconX size={18} />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="flex flex-col gap-4">
              <div className="flex flex-col gap-1">
                <label className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF]">
                  Nome
                </label>
                <input
                  required
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                  className="border border-[#E5E7EB] rounded-lg px-3 py-2 text-[13px] text-[#111827] focus:outline-none focus:ring-2 focus:ring-[#C7D2FE] focus:border-[#4F46E5]"
                  placeholder="Construtora Alfa Ltda."
                />
              </div>

              <div className="flex flex-col gap-1">
                <label className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF]">
                  Documento (CPF ou CNPJ)
                </label>
                <input
                  required
                  value={form.document}
                  onChange={(e) => setForm({ ...form, document: e.target.value })}
                  className="border border-[#E5E7EB] rounded-lg px-3 py-2 text-[13px] text-[#111827] font-mono focus:outline-none focus:ring-2 focus:ring-[#C7D2FE] focus:border-[#4F46E5]"
                  placeholder="12.345.678/0001-99"
                />
              </div>

              <div className="flex flex-col gap-1">
                <label className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF]">
                  Função
                </label>
                <select
                  value={form.role}
                  onChange={(e) => setForm({ ...form, role: e.target.value })}
                  className="border border-[#E5E7EB] rounded-lg px-3 py-2 text-[13px] text-[#111827] focus:outline-none focus:ring-2 focus:ring-[#C7D2FE] focus:border-[#4F46E5] bg-white"
                >
                  {ROLES.map((r) => (
                    <option key={r} value={r}>
                      {r}
                    </option>
                  ))}
                </select>
              </div>

              <div className="flex flex-col gap-1">
                <label className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF]">
                  Email (opcional)
                </label>
                <input
                  type="email"
                  value={form.email}
                  onChange={(e) => setForm({ ...form, email: e.target.value })}
                  className="border border-[#E5E7EB] rounded-lg px-3 py-2 text-[13px] text-[#111827] focus:outline-none focus:ring-2 focus:ring-[#C7D2FE] focus:border-[#4F46E5]"
                  placeholder="contato@empresa.com.br"
                />
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
                  {createMutation.isPending ? "Salvando..." : "Criar participante"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
