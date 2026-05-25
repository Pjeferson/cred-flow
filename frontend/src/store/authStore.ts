import { create } from "zustand";
import { persist } from "zustand/middleware";
import { clearToken } from "@/lib/api";

interface User {
  id: string;
  email: string;
  name: string;
}

interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  setUser: (user: User) => void;
  logout: () => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      user: null,
      isAuthenticated: !!localStorage.getItem("credflow_token"),
      setUser: (user) => set({ user, isAuthenticated: true }),
      logout: () => {
        clearToken();
        set({ user: null, isAuthenticated: false });
      },
    }),
    {
      name: "credflow_auth",
      partialize: (state) => ({ user: state.user, isAuthenticated: state.isAuthenticated }),
    }
  )
);
