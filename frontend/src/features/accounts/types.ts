export interface Account {
  id: string;
  type: "escrow" | "empresa";
  status: "active" | "blocked" | "closed";
  policy_rules: PolicyRules;
  created_at: string;
  cedente_id: string;
  credor_id: string;
  sacado_id: string | null;
  cedente_name: string | null;
  credor_name: string | null;
  sacado_name: string | null;
}

export interface PolicyRules {
  approval_required_above_cents?: number;
  blocked_hours?: { start: string; end: string };
  new_beneficiary_requires_approval?: boolean;
  daily_limit_cents?: number;
  approval_threshold?: { required: number; of: number };
}

export interface Balance {
  account_id: string;
  balance_cents: number;
  available_cents: number;
}

export type LedgerEntryType =
  | "CREDIT_RECEIVED"
  | "CREDIT_ANTECIPATION"
  | "DEBIT_EXECUTED"
  | "DEBIT_RESERVED"
  | "DEBIT_REVERSED";

export interface LedgerEntry {
  id: string;
  account_id: string;
  type: LedgerEntryType;
  direction: "credit" | "debit";
  amount_cents: number;
  status: string;
  payment_order_id: string | null;
  idempotency_key: string | null;
  description: string | null;
  created_at: string;
}
