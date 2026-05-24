import { describe, it, expect, beforeEach } from "vitest";
import { useAuthStore } from "@/store/authStore";

const user = { id: "u-1", email: "demo@credflow.com", name: "Demo" };

beforeEach(() => {
  localStorage.clear();
  useAuthStore.setState({ user: null, isAuthenticated: false });
});

describe("authStore", () => {
  it("starts unauthenticated when no token in localStorage", () => {
    expect(useAuthStore.getState().isAuthenticated).toBe(false);
    expect(useAuthStore.getState().user).toBeNull();
  });

  it("setUser marks as authenticated", () => {
    useAuthStore.getState().setUser(user);
    expect(useAuthStore.getState().isAuthenticated).toBe(true);
    expect(useAuthStore.getState().user).toEqual(user);
  });

  it("logout clears user and isAuthenticated", () => {
    useAuthStore.getState().setUser(user);
    localStorage.setItem("credflow_token", "tok");

    useAuthStore.getState().logout();

    expect(useAuthStore.getState().isAuthenticated).toBe(false);
    expect(useAuthStore.getState().user).toBeNull();
    expect(localStorage.getItem("credflow_token")).toBeNull();
  });
});
