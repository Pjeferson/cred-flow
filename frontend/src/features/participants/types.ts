export interface Participant {
  id: string;
  name: string;
  document: string;
  role: "cedente" | "credor" | "sacado";
  kyc_status: "pending" | "approved" | "rejected";
  kyc_checked_at: string | null;
  created_at: string;
}
