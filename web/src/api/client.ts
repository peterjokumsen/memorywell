const runtimeConfig = (window as any).__APP_CONFIG || {};
const API_BASE = runtimeConfig.apiBaseUrl ?? "http://localhost:8000";
const FUNCTIONS_BASE = runtimeConfig.functionsBaseUrl ?? "http://localhost:7071";

export async function apiFetch(path: string, init?: RequestInit): Promise<Response> {
  return fetch(`${API_BASE}${path}`, {
    ...init,
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
      ...(init?.headers ?? {}),
    },
  });
}

export async function functionsFetch(path: string, init?: RequestInit): Promise<Response> {
  return fetch(`${FUNCTIONS_BASE}${path}`, {
    ...init,
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
      ...(init?.headers ?? {}),
    },
  });
}
