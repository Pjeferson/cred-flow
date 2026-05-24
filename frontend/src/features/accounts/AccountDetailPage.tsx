import { useState } from "react";
import { useNavigate } from "@tanstack/react-router";
import {
  IconArrowLeft,
  IconArrowUpRight,
  IconArrowDownLeft,
  IconBuildingBank,
  IconLock,
  IconRefresh,
} from "@tabler/icons-react";
import { useAccount, useAccountBalance, useLedgerEntries } from "./useAccounts";
import { formatCurrency, formatDate } from "@/lib/formatters";
import { CreateTransferModal } from "@/features/payments/CreateTransferModal";
import { ApprovalQueue } from "@/features/payments/ApprovalQueue";
import type { LedgerEntry, LedgerEntryType } from "./types";

function accountCode(account: { id: string; type: "escrow" | "empresa" }) {
  const prefix = account.type === "escrow" ? "ESC" : "EMP";
  return `${prefix}-${account.id.slice(-4).toUpperCase()}`;
}

const entryConfig: Record<
  LedgerEntryType,
  { icon: React.ReactNode; bg: string; color: string; sign: string }
> = {
  CREDIT_RECEIVED: {
    icon: <IconArrowDownLeft size={14} />,
    bg: "#DCFCE7",
    color: "#16A34A",
    sign: "+",
  },
  CREDIT_ANTECIPATION: {
    icon: <IconBuildingBank size={14} />,
    bg: "#DCFCE7",
    color: "#16A34A",
    sign: "+",
  },
  DEBIT_EXECUTED: {
    icon: <IconArrowUpRight size={14} />,
    bg: "#FEE2E2",
    color: "#DC2626",
    sign: "−",
  },
  DEBIT_RESERVED: {
    icon: <IconLock size={14} />,
    bg: "#FEF3C7",
    color: "#D97706",
    sign: "−",
  },
  DEBIT_REVERSED: {
    icon: <IconRefresh size={14} />,
    bg: "#F4F5F7",
    color: "#6B7280",
    sign: "+",
  },
};

function LedgerItem({ entry }: { entry: LedgerEntry }) {
  const cfg = entryConfig[entry.type] ?? entryConfig.DEBIT_EXECUTED;
  const label =
    entry.description ?? entry.type.replace(/_/g, " ").toLowerCase();

  return (
    <div className="flex items-center gap-2.5 py-2 border-b border-[#E5E7EB] last:border-0">
      <div
        className="w-7 h-7 rounded-full flex items-center justify-center shrink-0"
        style={{ background: cfg.bg }}
      >
        <span style={{ color: cfg.color }}>{cfg.icon}</span>
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-[12px] font-medium text-[#111827] truncate capitalize">
          {label}
        </p>
        <p className="text-[11px] text-[#9CA3AF]">
          {formatDate(entry.created_at)}
        </p>
      </div>
      <span
        className="text-[13px] font-medium tabular-nums whitespace-nowrap"
        style={{ color: cfg.color }}
      >
        {cfg.sign} {formatCurrency(entry.amount_cents)}
      </span>
    </div>
  );
}

export function AccountDetailPage({ accountId }: { accountId: string }) {
  const navigate = useNavigate();
  const [showTransfer, setShowTransfer] = useState(false);
  const { data: account, isLoading: loadingAccount } = useAccount(accountId);
  const { data: balance, isLoading: loadingBalance } =
    useAccountBalance(accountId);
  const { data: entries, isLoading: loadingEntries } =
    useLedgerEntries(accountId);

  if (loadingAccount) {
    return (
      <div className="p-8 text-center text-[13px] text-[#9CA3AF]">
        Carregando conta...
      </div>
    );
  }

  if (!account) {
    return (
      <div className="p-8 text-center text-[13px] text-[#DC2626]">
        Conta não encontrada.
      </div>
    );
  }

  const reserved = balance
    ? balance.balance_cents - balance.available_cents
    : null;

  return (
    <div className="flex flex-col h-full overflow-hidden">
      {/* Page header */}
      <div className="px-6 py-4 bg-white border-b border-[#E5E7EB] flex items-center justify-between shrink-0">
        <div className="flex items-center gap-3">
          <button
            onClick={() => navigate({ to: "/" })}
            className="text-[#9CA3AF] hover:text-[#6B7280] transition-colors"
          >
            <IconArrowLeft size={16} />
          </button>
          <div>
            <h1 className="text-[15px] font-medium text-[#111827]">
              Conta vinculada — {accountCode(account)}
            </h1>
            <p className="text-[12px] text-[#6B7280] mt-0.5">
              Cedente: {account.cedente_name ?? "—"} · Credor:{" "}
              {account.credor_name ?? "—"}
            </p>
          </div>
        </div>
        <button
          onClick={() => setShowTransfer(true)}
          className="bg-[#4F46E5] text-white text-[13px] font-medium px-3.5 py-[7px] rounded-lg flex items-center gap-1.5 hover:bg-[#4338CA] active:scale-[0.98] transition-all"
        >
          <IconArrowUpRight size={14} />
          Nova transferência
        </button>
      </div>

      {/* Content */}
      <div className="p-6 flex flex-col gap-4 overflow-auto flex-1">
        {/* Metric cards */}
        <div className="grid grid-cols-3 gap-2.5">
          <div className="bg-[#F4F5F7] rounded-lg p-4">
            <p className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF] mb-1.5">
              Saldo disponível
            </p>
            {loadingBalance ? (
              <p className="text-[22px] font-medium text-[#9CA3AF]">—</p>
            ) : (
              <p className="text-[22px] font-medium tabular-nums text-[#16A34A]">
                {formatCurrency(balance?.available_cents ?? 0)}
              </p>
            )}
            <p className="text-[11px] text-[#9CA3AF] mt-0.5">
              Atualizado agora
            </p>
          </div>

          <div className="bg-[#F4F5F7] rounded-lg p-4">
            <p className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF] mb-1.5">
              Reservado
            </p>
            {loadingBalance ? (
              <p className="text-[22px] font-medium text-[#9CA3AF]">—</p>
            ) : (
              <p className="text-[22px] font-medium tabular-nums text-[#D97706]">
                {formatCurrency(reserved ?? 0)}
              </p>
            )}
            <p className="text-[11px] text-[#9CA3AF] mt-0.5">
              TEDs em execução
            </p>
          </div>

          <div className="bg-[#F4F5F7] rounded-lg p-4">
            <p className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF] mb-1.5">
              A receber
            </p>
            <p className="text-[22px] font-medium tabular-nums text-[#9CA3AF]">
              —
            </p>
            <p className="text-[11px] text-[#9CA3AF] mt-0.5">
              CCBs disponíveis em breve
            </p>
          </div>
        </div>

        {/* Two-column: ledger + approval queue */}
        <div className="grid grid-cols-[1fr_320px] gap-4">
          {/* Ledger panel */}
          <div className="bg-white border border-[#E5E7EB] rounded-xl p-5">
            <div className="flex items-center justify-between mb-3">
              <h2 className="text-[13px] font-medium text-[#111827]">
                Ledger
              </h2>
              <span className="text-[12px] text-[#9CA3AF]">
                últimas 10 entradas
              </span>
            </div>
            {loadingEntries ? (
              <p className="text-[13px] text-[#9CA3AF] py-6 text-center">
                Carregando...
              </p>
            ) : !entries?.length ? (
              <p className="text-[13px] text-[#9CA3AF] py-6 text-center">
                Nenhuma movimentação
              </p>
            ) : (
              entries.map((entry) => <LedgerItem key={entry.id} entry={entry} />)
            )}
          </div>

          <ApprovalQueue
            accountId={accountId}
            thresholdRequired={
              account.policy_rules?.approval_threshold?.required ?? 1
            }
          />
        </div>
      </div>

      {showTransfer && (
        <CreateTransferModal
          accountId={accountId}
          onClose={() => setShowTransfer(false)}
        />
      )}
    </div>
  );
}
