import { format, formatDistanceToNow } from "date-fns";
import { ptBR } from "date-fns/locale";

export function formatCurrency(cents: number): string {
  return new Intl.NumberFormat("pt-BR", {
    style: "currency",
    currency: "BRL",
  }).format(cents / 100);
}

export function formatDate(iso: string): string {
  return format(new Date(iso), "d MMM, HH:mm", { locale: ptBR });
}

export function formatDateShort(iso: string): string {
  return format(new Date(iso), "d MMM yyyy", { locale: ptBR });
}

export function formatDateOnly(dateStr: string): string {
  const [year, month, day] = dateStr.split("-").map(Number);
  return format(new Date(year, month - 1, day), "d MMM yyyy", { locale: ptBR });
}

export function formatTTL(iso: string): string {
  return formatDistanceToNow(new Date(iso), { locale: ptBR });
}

const policyReasons: Record<string, string> = {
  amount_threshold: "valor acima do limite",
  new_beneficiary: "beneficiário novo",
  daily_limit_exceeded: "limite diário atingido",
  outside_banking_hours: "fora do horário SPB",
};

export function policyReason(action: string): string {
  return policyReasons[action] ?? action;
}
