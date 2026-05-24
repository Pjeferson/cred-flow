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

export function formatTTL(iso: string): string {
  return formatDistanceToNow(new Date(iso), { locale: ptBR });
}
