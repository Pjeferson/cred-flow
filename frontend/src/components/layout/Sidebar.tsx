import { Link, useNavigate, useRouterState } from "@tanstack/react-router";
import {
  IconBuildingBank,
  IconChecks,
  IconFileText,
  IconUsers,
  IconActivity,
  IconLogout,
} from "@tabler/icons-react";
import { useAuthStore } from "@/store/authStore";

interface NavItemProps {
  to: string;
  icon: React.ReactNode;
  label: string;
  badge?: number;
  matchPrefix?: string;
}

function NavItem({ to, icon, label, badge, matchPrefix }: NavItemProps) {
  const location = useRouterState({ select: (s) => s.location.pathname });
  const isActive =
    location === to ||
    (!!matchPrefix && location.startsWith(matchPrefix));

  return (
    <Link
      to={to}
      className={[
        "flex items-center gap-2.5 px-4 py-[7px] text-[13px] transition-colors cursor-pointer select-none",
        isActive
          ? "bg-[#EEF2FF] text-[#4F46E5] font-medium"
          : "text-[#6B7280] hover:bg-white hover:text-[#111827]",
      ].join(" ")}
    >
      <span className="text-[16px] shrink-0">{icon}</span>
      <span>{label}</span>
      {badge !== undefined && badge > 0 && (
        <span className="ml-auto bg-[#FEF3C7] text-[#D97706] text-[10px] font-medium px-1.5 py-0.5 rounded">
          {badge}
        </span>
      )}
    </Link>
  );
}

function SectionLabel({ label }: { label: string }) {
  return (
    <p className="px-4 pt-4 pb-1 text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF]">
      {label}
    </p>
  );
}

export function Sidebar() {
  const logout = useAuthStore((s) => s.logout);
  const navigate = useNavigate();

  function handleLogout() {
    logout();
    navigate({ to: "/login" });
  }

  return (
    <aside className="w-[220px] shrink-0 bg-[#F9FAFB] border-r border-[#E5E7EB] py-5 flex flex-col gap-0.5">
      <div className="px-4 pb-5 border-b border-[#E5E7EB] mb-2">
        <span className="text-[15px] font-medium text-[#111827]">CredFlow</span>
      </div>

      <SectionLabel label="Operações" />
      <NavItem
        to="/"
        matchPrefix="/accounts"
        icon={<IconBuildingBank size={16} />}
        label="Conta vinculada"
      />
      <NavItem
        to="/approvals"
        icon={<IconChecks size={16} />}
        label="Aprovações"
      />

      <SectionLabel label="Crédito" />
      <NavItem
        to="/ccbs"
        matchPrefix="/ccbs"
        icon={<IconFileText size={16} />}
        label="CCBs"
      />
      <NavItem
        to="/monitoring"
        icon={<IconActivity size={16} />}
        label="Monitoramento"
      />

      <SectionLabel label="Configuração" />
      <NavItem
        to="/participants"
        icon={<IconUsers size={16} />}
        label="Participantes"
      />

      <div className="mt-auto border-t border-[#E5E7EB] pt-2">
        <button
          onClick={handleLogout}
          className="flex w-full items-center gap-2.5 px-4 py-[7px] text-[13px] text-[#6B7280] transition-colors hover:bg-white hover:text-[#111827] cursor-pointer"
        >
          <span className="text-[16px] shrink-0"><IconLogout size={16} /></span>
          <span>Sair</span>
        </button>
      </div>
    </aside>
  );
}
