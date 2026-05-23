import { createFileRoute } from "@tanstack/react-router";
import { useAuth } from "@/features/auth/useAuth";
import { useAuthStore } from "@/store/authStore";

export const Route = createFileRoute("/_authenticated/")({
  component: DashboardPage,
});

function DashboardPage() {
  const { signOut } = useAuth();
  const user = useAuthStore((s) => s.user);

  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between">
        <h1 className="text-lg font-bold text-gray-900">CredFlow</h1>
        <div className="flex items-center gap-4">
          {user && (
            <span className="text-sm text-gray-600">{user.name}</span>
          )}
          <button
            onClick={() => signOut.mutate()}
            disabled={signOut.isPending}
            className="text-sm text-red-600 hover:underline disabled:opacity-50"
          >
            Sair
          </button>
        </div>
      </header>

      <main className="max-w-4xl mx-auto px-6 py-10">
        <h2 className="text-2xl font-semibold text-gray-800 mb-2">Dashboard</h2>
        <p className="text-gray-500 text-sm">
          Módulos de conta vinculada, pagamentos e recebíveis serão adicionados aqui.
        </p>
      </main>
    </div>
  );
}
