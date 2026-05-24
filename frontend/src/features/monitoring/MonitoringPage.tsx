import {
  IconRefresh,
  IconAlertTriangle,
  IconCircleCheck,
  IconCircleX,
  IconClock,
  IconInbox,
} from "@tabler/icons-react";
import { useMonitoring } from "./useMonitoring";
import { formatCurrency, formatDate, formatDateOnly } from "@/lib/formatters";
import type { ReconciliationRun } from "./types";

function StatusBadge({ status }: { status: ReconciliationRun["status"] }) {
  const map = {
    completed: { bg: "#DCFCE7", color: "#16A34A", label: "concluído" },
    running:   { bg: "#EEF2FF", color: "#4F46E5", label: "rodando" },
    failed:    { bg: "#FEE2E2", color: "#DC2626", label: "falhou" },
  } as const;
  const cfg = map[status];
  return (
    <span
      className="inline-flex items-center text-[11px] font-medium px-2 py-0.5 rounded"
      style={{ background: cfg.bg, color: cfg.color }}
    >
      {cfg.label}
    </span>
  );
}

function MetricCard({
  label,
  value,
  sub,
  valueColor = "#111827",
  icon,
}: {
  label: string;
  value: React.ReactNode;
  sub?: string;
  valueColor?: string;
  icon: React.ReactNode;
}) {
  return (
    <div className="bg-[#F4F5F7] rounded-lg p-4 flex flex-col gap-1">
      <div className="flex items-center justify-between mb-1">
        <p className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF]">
          {label}
        </p>
        <span className="text-[#9CA3AF]">{icon}</span>
      </div>
      <p
        className="text-[22px] font-medium tabular-nums"
        style={{ color: valueColor }}
      >
        {value}
      </p>
      {sub && <p className="text-[11px] text-[#9CA3AF]">{sub}</p>}
    </div>
  );
}

export function MonitoringPage() {
  const { data, isLoading, dataUpdatedAt, refetch, isFetching } =
    useMonitoring();

  const rec = data?.reconciliation;
  const ov = data?.overdue;
  const dlq = data?.dlq;

  const lastUpdated = dataUpdatedAt
    ? new Date(dataUpdatedAt).toLocaleTimeString("pt-BR")
    : null;

  return (
    <div className="flex flex-col h-full overflow-hidden">
      {/* Header */}
      <div className="px-6 py-4 bg-white border-b border-[#E5E7EB] flex items-center justify-between shrink-0">
        <h1 className="text-[15px] font-medium text-[#111827]">
          Monitoramento
        </h1>
        <div className="flex items-center gap-3">
          {lastUpdated && (
            <p className="text-[12px] text-[#9CA3AF]">
              Atualizado às {lastUpdated}
            </p>
          )}
          <button
            onClick={() => refetch()}
            disabled={isFetching}
            className="flex items-center gap-1.5 text-[13px] text-[#6B7280] px-3 py-[7px] rounded-lg border border-[#E5E7EB] hover:bg-[#F4F5F7] disabled:opacity-40 transition-colors"
          >
            <IconRefresh size={14} className={isFetching ? "animate-spin" : ""} />
            Atualizar
          </button>
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-auto p-6 flex flex-col gap-5">
        {isLoading ? (
          <p className="text-[13px] text-[#9CA3AF] text-center py-10">
            Carregando...
          </p>
        ) : (
          <>
            {/* Metric cards */}
            <div className="grid grid-cols-4 gap-2.5">
              <MetricCard
                label="Conciliações"
                value={rec?.total_runs ?? 0}
                sub={`${rec?.completed ?? 0} concluídas`}
                icon={<IconCircleCheck size={15} />}
              />
              <MetricCard
                label="Com divergências"
                value={rec?.with_divergences ?? 0}
                valueColor={
                  (rec?.with_divergences ?? 0) > 0 ? "#DC2626" : "#16A34A"
                }
                sub="nas últimas execuções"
                icon={<IconAlertTriangle size={15} />}
              />
              <MetricCard
                label="Parcelas vencidas"
                value={ov?.count ?? 0}
                valueColor={(ov?.count ?? 0) > 0 ? "#DC2626" : "#16A34A"}
                sub={
                  (ov?.count ?? 0) > 0
                    ? formatCurrency(ov?.total_amount_cents ?? 0)
                    : "Nenhuma em atraso"
                }
                icon={<IconClock size={15} />}
              />
              <MetricCard
                label="DLQ — mensagens"
                value={dlq?.error ? "—" : (dlq?.messages ?? 0)}
                valueColor={
                  dlq?.error
                    ? "#9CA3AF"
                    : (dlq?.messages ?? 0) > 0
                    ? "#D97706"
                    : "#16A34A"
                }
                sub={
                  dlq?.error
                    ? "management API indisponível"
                    : `${dlq?.consumers ?? 0} consumidor${(dlq?.consumers ?? 0) !== 1 ? "es" : ""}`
                }
                icon={<IconInbox size={15} />}
              />
            </div>

            {/* Overdue detail */}
            {(ov?.count ?? 0) > 0 && ov?.oldest_due_date && (
              <div className="bg-[#FEF2F2] border border-[#FECACA] rounded-xl px-5 py-3 flex items-center gap-3">
                <IconCircleX size={16} color="#DC2626" className="shrink-0" />
                <p className="text-[13px] text-[#DC2626]">
                  <span className="font-medium">{ov.count} parcela{ov.count !== 1 ? "s" : ""}</span>
                  {" "}em atraso totalizando{" "}
                  <span className="font-medium tabular-nums">
                    {formatCurrency(ov.total_amount_cents)}
                  </span>
                  {" "}· vencimento mais antigo em{" "}
                  <span className="font-medium">{formatDateOnly(ov.oldest_due_date)}</span>
                </p>
              </div>
            )}

            {/* Reconciliation runs table */}
            <div className="bg-white border border-[#E5E7EB] rounded-xl overflow-hidden">
              <div className="px-5 py-4 border-b border-[#E5E7EB]">
                <h2 className="text-[13px] font-medium text-[#111827]">
                  Histórico de conciliações
                </h2>
                <p className="text-[12px] text-[#9CA3AF] mt-0.5">
                  Últimas 20 execuções
                </p>
              </div>

              {!rec?.runs.length ? (
                <p className="text-[13px] text-[#9CA3AF] text-center py-10">
                  Nenhuma conciliação registrada
                </p>
              ) : (
                <table className="w-full">
                  <thead>
                    <tr className="border-b border-[#E5E7EB]">
                      {[
                        "Data de referência",
                        "Conta",
                        "Status",
                        "Entradas",
                        "Divergências",
                        "Iniciado em",
                        "Duração",
                      ].map((h) => (
                        <th
                          key={h}
                          className={`px-5 py-3 text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF] ${
                            ["Entradas", "Divergências", "Duração"].includes(h)
                              ? "text-right"
                              : "text-left"
                          }`}
                        >
                          {h}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {rec.runs.map((run) => (
                      <tr
                        key={run.id}
                        className="border-b border-[#E5E7EB] last:border-0 hover:bg-[#F9FAFB]"
                      >
                        <td className="px-5 py-3 text-[13px] text-[#111827] tabular-nums">
                          {formatDateOnly(run.reference_date)}
                        </td>
                        <td className="px-5 py-3 text-[12px] text-[#6B7280] font-mono">
                          {run.account_id.slice(-8).toUpperCase()}
                        </td>
                        <td className="px-5 py-3">
                          <StatusBadge status={run.status} />
                          {run.error_message && (
                            <p className="text-[11px] text-[#DC2626] mt-0.5 max-w-[180px] truncate">
                              {run.error_message}
                            </p>
                          )}
                        </td>
                        <td className="px-5 py-3 text-[13px] text-[#6B7280] text-right tabular-nums">
                          {run.entries_checked}
                        </td>
                        <td className="px-5 py-3 text-right">
                          <span
                            className={`text-[13px] tabular-nums font-medium ${
                              run.divergences_found > 0
                                ? "text-[#DC2626]"
                                : "text-[#6B7280]"
                            }`}
                          >
                            {run.divergences_found}
                          </span>
                        </td>
                        <td className="px-5 py-3 text-[12px] text-[#9CA3AF] whitespace-nowrap">
                          {formatDate(run.ran_at)}
                        </td>
                        <td className="px-5 py-3 text-[12px] text-[#9CA3AF] text-right tabular-nums">
                          {run.duration_s != null ? `${run.duration_s}s` : "—"}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>

            {/* DLQ detail when error */}
            {dlq?.error && (
              <div className="bg-[#FEF3C7] border border-[#FDE68A] rounded-xl px-5 py-3 flex items-center gap-3">
                <IconAlertTriangle size={16} color="#D97706" className="shrink-0" />
                <p className="text-[13px] text-[#D97706]">
                  Não foi possível consultar a fila DLQ:{" "}
                  <span className="font-mono text-[12px]">{dlq.error}</span>
                </p>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
