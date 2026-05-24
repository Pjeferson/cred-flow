export type CcbStatus = "active" | "settled" | "defaulted" | "cancelled";

export interface Ccb {
  id: string;
  account_id: string;
  principal_cents: number;
  discount_cents: number;
  net_cents: number;
  annual_rate: string;
  installment_count: number;
  first_due_date: string;
  status: CcbStatus;
  issued_at: string;
  settled_at: string | null;
}

export type InstallmentStatus = "pending" | "partially_paid" | "paid" | "overdue";

export interface Installment {
  id: string;
  ccb_id: string;
  number: number;
  amount_cents: number;
  paid_cents: number;
  due_date: string;
  paid_at: string | null;
  status: InstallmentStatus;
}

export interface CcbWithInstallments extends Ccb {
  installments: Installment[];
}
