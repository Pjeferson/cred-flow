import { create } from "zustand";
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

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  isAuthenticated: !!localStorage.getItem("credflow_token"),
  setUser: (user) => set({ user, isAuthenticated: true }),
  logout: () => {
    clearToken();
    set({ user: null, isAuthenticated: false });
  },
}));
