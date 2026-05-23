import { useMutation } from "@tanstack/react-query";
import { useRouter } from "@tanstack/react-router";
import { api, setToken } from "@/lib/api";
import { useAuthStore } from "@/store/authStore";

interface User {
  id: string;
  email: string;
  name: string;
}

interface AuthResponse {
  message: string;
  user: User;
}

export function useAuth() {
  const { setUser, logout: logoutStore } = useAuthStore();
  const router = useRouter();

  const signIn = useMutation({
    mutationFn: async (data: { email: string; password: string }) => {
      const response = await api.post("api/v1/auth/sign_in", { json: data });
      const token = response.headers.get("Authorization")?.replace("Bearer ", "");
      const body: AuthResponse = await response.json();
      return { token, user: body.user };
    },
    onSuccess: ({ token, user }) => {
      if (token) setToken(token);
      setUser(user);
      router.navigate({ to: "/" });
    },
  });

  const signUp = useMutation({
    mutationFn: async (data: { name: string; email: string; password: string }) => {
      const response = await api.post("api/v1/auth/sign_up", {
        json: { user: data },
      });
      const token = response.headers.get("Authorization")?.replace("Bearer ", "");
      const body: AuthResponse = await response.json();
      return { token, user: body.user };
    },
    onSuccess: ({ token, user }) => {
      if (token) setToken(token);
      setUser(user);
      router.navigate({ to: "/" });
    },
  });

  const signOut = useMutation({
    mutationFn: () => api.delete("api/v1/auth/sign_out").then(() => undefined),
    onSettled: () => {
      logoutStore();
      router.navigate({ to: "/login" });
    },
  });

  return { signIn, signUp, signOut };
}
