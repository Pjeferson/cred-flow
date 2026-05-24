import ky from "ky";

const API_BASE = import.meta.env.VITE_API_URL ?? "http://localhost:8080";

function getToken(): string | null {
  return localStorage.getItem("credflow_token");
}

export function setToken(token: string): void {
  localStorage.setItem("credflow_token", token);
}

export function clearToken(): void {
  localStorage.removeItem("credflow_token");
}

export const api = ky.create({
  prefixUrl: API_BASE,
  hooks: {
    beforeRequest: [
      (request) => {
        const token = getToken();
        if (token) {
          request.headers.set("Authorization", `Bearer ${token}`);
        }
      },
    ],
    afterResponse: [
      async (request, _options, response) => {
        if (response.status === 401 && !request.url.includes("/auth/")) {
          clearToken();
          window.location.href = "/login";
        }
        return response;
      },
    ],
  },
});
