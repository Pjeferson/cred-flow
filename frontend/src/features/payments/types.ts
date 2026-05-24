export type PaymentOrderStatus =
  | "draft"
  | "policy_check"
  | "pending_approval"
  | "scheduled"
  | "approved"
  | "executing"
  | "settled"
  | "rejected"
  | "failed"
  | "expired";

export interface PaymentOrder {
  id: string;
  account_id: string;
  requested_by: string;
  amount_cents: number;
  beneficiary_doc: string;
  beneficiary_name: string | null;
  status: PaymentOrderStatus;
  policy_action: string | null;
  rejection_reason: string | null;
  spb_transaction_id: string | null;
  idempotency_key: string;
  scheduled_for: string | null;
  expires_at: string | null;
  executed_at: string | null;
  settled_at: string | null;
  created_at: string;
  approvals_count: number;
}
