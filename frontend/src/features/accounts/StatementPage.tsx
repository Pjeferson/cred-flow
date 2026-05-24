import { useState } from "react";
import { useNavigate } from "@tanstack/react-router";
import {
  IconArrowLeft,
  IconArrowDownLeft,
  IconBuildingBank,
  IconArrowUpRight,
  IconLock,
  IconRefresh,
  IconChevronLeft,
  IconChevronRight,
} from "@tabler/icons-react";
import { useAccount } from "./useAccounts";
import { useStatementEntries } from "./useAccounts";
import { formatCurrency, formatDate } from "@/lib/formatters";
import type { LedgerEntry, LedgerEntryType } from "./types";

function accountCode(account: { id: string; type: "escrow" | "empresa" }) {
  const prefix = account.type === "escrow" ? "ESC" : "EMP";
  return `${prefix}-${account.id.slice(-4).toUpperCase()}`;
}

const entryConfig: Record<
  LedgerEntryType,
  { icon: React.ReactNode; bg: string; color: string; sign: string; label: string }
> = {
  CREDIT_RECEIVED: {
    icon: <IconArrowDownLeft size={14} />,
    bg: "#DCFCE7",
    color: "#16A34A",
    sign: "+",
    label: "Crédito recebido",
  },
  CREDIT_ANTECIPATION: {
    icon: <IconBuildingBank size={14} />,
    bg: "#DCFCE7",
    color: "#16A34A",
    sign: "+",
    label: "Antecipação",
  },
  DEBIT_EXECUTED: {
    icon: <IconArrowUpRight size={14} />,
    bg: "#FEE2E2",
    color: "#DC2626",
    sign: "−",
    label: "TED executada",
  },
  DEBIT_RESERVED: {
    icon: <IconLock size={14} />,
    bg: "#FEF3C7",
    color: "#D97706",
    sign: "−",
    label: "Reserva",
  },
  DEBIT_REVERSED: {
    icon: <IconRefresh size={14} />,
    bg: "#F4F5F7",
    color: "#6B7280",
    sign: "+",
    label: "Estorno",
  },
};

function LedgerRow({ entry }: { entry: LedgerEntry }) {
  const cfg = entryConfig[entry.type] ?? entryConfig.DEBIT_EXECUTED;
  const label = entry.description ?? cfg.label;

  return (
    <tr className="border-b border-[#E5E7EB] last:border-0 hover:bg-[#F9FAFB]">
      <td className="px-5 py-3">
        <div className="flex items-center gap-2.5">
          <div
            className="w-7 h-7 rounded-full flex items-center justify-center shrink-0"
            style={{ background: cfg.bg }}
          >
            <span style={{ color: cfg.color }}>{cfg.icon}</span>
          </div>
          <div className="min-w-0">
            <p className="text-[12px] font-medium text-[#111827] truncate capitalize">
              {label}
            </p>
            <p className="text-[11px] text-[#9CA3AF]">
              {formatDate(entry.created_at)}
            </p>
          </div>
        </div>
      </td>
      <td className="px-5 py-3">
        <span className="text-[11px] font-medium px-2 py-0.5 rounded bg-[#F4F5F7] text-[#6B7280]">
          {entry.type.replace(/_/g, " ").toLowerCase()}
        </span>
      </td>
      <td className="px-5 py-3 text-right">
        <span
          className="text-[13px] font-medium tabular-nums whitespace-nowrap"
          style={{ color: cfg.color }}
        >
          {cfg.sign} {formatCurrency(entry.amount_cents)}
        </span>
      </td>
      <td className="px-5 py-3 text-right">
        <span
          className={`inline-flex items-center text-[11px] font-medium px-2 py-0.5 rounded ${
            entry.status === "SETTLED"
              ? "bg-[#DCFCE7] text-[#16A34A]"
              : "bg-[#FEF3C7] text-[#D97706]"
          }`}
        >
          {entry.status?.toLowerCase() ?? "—"}
        </span>
      </td>
    </tr>
  );
}

export function StatementPage({ accountId }: { accountId: string }) {
  const navigate = useNavigate();
  const [page, setPage] = useState(1);

  const { data: account } = useAccount(accountId);
  const { data, isLoading } = useStatementEntries(accountId, page);

  const entries = data?.entries ?? [];
  const meta = data?.meta;
  const totalPages = meta?.total_pages ?? 1;
  const totalCount = meta?.total_count ?? 0;

  return (
    <div className="flex flex-col h-full overflow-hidden">
      {/* Header */}
      <div className="px-6 py-4 bg-white border-b border-[#E5E7EB] flex items-center justify-between shrink-0">
        <div className="flex items-center gap-3">
          <button
            onClick={() =>
              navigate({
                to: "/accounts/$accountId",
                params: { accountId },
              })
            }
            className="text-[#9CA3AF] hover:text-[#6B7280] transition-colors"
          >
            <IconArrowLeft size={16} />
          </button>
          <div>
            <h1 className="text-[15px] font-medium text-[#111827]">
              Extrato
              {account ? ` — ${accountCode(account)}` : ""}
            </h1>
            {account && (
              <p className="text-[12px] text-[#6B7280] mt-0.5">
                Cedente: {account.cedente_name ?? "—"} · Credor:{" "}
                {account.credor_name ?? "—"}
              </p>
            )}
          </div>
        </div>
        {totalCount > 0 && (
          <p className="text-[12px] text-[#9CA3AF]">
            {totalCount} lançamento{totalCount !== 1 ? "s" : ""}
          </p>
        )}
      </div>

      {/* Content */}
      <div className="flex flex-col flex-1 overflow-hidden">
        <div className="flex-1 overflow-auto">
          <div className="bg-white border border-[#E5E7EB] rounded-xl overflow-hidden m-6">
            {isLoading ? (
              <div className="p-8 text-center text-[13px] text-[#9CA3AF]">
                Carregando...
              </div>
            ) : entries.length === 0 ? (
              <div className="p-8 text-center text-[13px] text-[#9CA3AF]">
                Nenhum lançamento encontrado
              </div>
            ) : (
              <table className="w-full">
                <thead>
                  <tr className="border-b border-[#E5E7EB]">
                    {["Lançamento", "Tipo", "Valor", "Status"].map((h) => (
                      <th
                        key={h}
                        className={`px-5 py-3 text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF] ${
                          h === "Valor" || h === "Status" ? "text-right" : "text-left"
                        }`}
                      >
                        {h}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {entries.map((entry) => (
                    <LedgerRow key={entry.id} entry={entry} />
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>

        {/* Pagination */}
        {totalPages > 1 && (
          <div className="px-6 py-4 bg-white border-t border-[#E5E7EB] flex items-center justify-between shrink-0">
            <button
              onClick={() => setPage((p) => Math.max(1, p - 1))}
              disabled={page === 1}
              className="flex items-center gap-1.5 text-[13px] text-[#6B7280] px-3 py-[7px] rounded-lg border border-[#E5E7EB] hover:bg-[#F4F5F7] disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
            >
              <IconChevronLeft size={14} />
              Anterior
            </button>

            <p className="text-[12px] text-[#6B7280]">
              Página{" "}
              <span className="font-medium text-[#111827]">{page}</span> de{" "}
              <span className="font-medium text-[#111827]">{totalPages}</span>
            </p>

            <button
              onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
              disabled={page === totalPages}
              className="flex items-center gap-1.5 text-[13px] text-[#6B7280] px-3 py-[7px] rounded-lg border border-[#E5E7EB] hover:bg-[#F4F5F7] disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
            >
              Próxima
              <IconChevronRight size={14} />
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
