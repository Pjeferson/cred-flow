import { createFileRoute } from "@tanstack/react-router";
import { ParticipantsPage } from "@/features/participants/ParticipantsPage";

export const Route = createFileRoute("/_authenticated/participants")({
  component: ParticipantsPage,
});
