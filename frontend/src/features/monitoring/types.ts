export interface ReconciliationRun {
  id: string;
  account_id: string;
  reference_date: string;
  status: "running" | "completed" | "failed";
  entries_checked: number;
  divergences_found: number;
  ran_at: string;
  finished_at: string | null;
  duration_s: number | null;
  error_message: string | null;
}

export interface ReconciliationData {
  total_runs: number;
  completed: number;
  with_divergences: number;
  runs: ReconciliationRun[];
}

export interface OverdueData {
  count: number;
  total_amount_cents: number;
  oldest_due_date: string | null;
}

export interface DlqData {
  messages: number;
  messages_ready: number;
  consumers: number;
  error: string | null;
}

export interface MonitoringData {
  reconciliation: ReconciliationData;
  overdue: OverdueData;
  dlq: DlqData;
}
