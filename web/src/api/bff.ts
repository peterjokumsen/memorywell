import { apiFetch } from "./client";

const entities = [
  "households",
  "chronicles",
  "contributors",
  "invites",
  "prompts",
  "memories",
  "transcripts",
  "flags",
  "aliasHistory",
] as const;

export type Entity = (typeof entities)[number];

async function req(path: string, init?: RequestInit) {
  const res = await apiFetch(path, init);
  if (!res.ok) throw new Error(`BFF request failed: ${res.status}`);
  if (res.status === 204) return null;
  return res.json();
}

export const listEntity = (entity: Entity, params?: Record<string, string>) => {
  const qs = params ? "?" + new URLSearchParams(params).toString() : "";
  return req(`/${entity}${qs}`);
};

export const getEntity = (entity: Entity, id: string, params?: Record<string, string>) => {
  const qs = params ? "?" + new URLSearchParams(params).toString() : "";
  return req(`/${entity}/${id}${qs}`);
};

export const createEntity = (entity: Entity, body: any) =>
  req(`/${entity}`, { method: "POST", body: JSON.stringify(body) });

export const updateEntity = (entity: Entity, id: string, body: any) =>
  req(`/${entity}/${id}`, { method: "PUT", body: JSON.stringify(body) });

export const patchEntity = (entity: Entity, id: string, body: any) =>
  req(`/${entity}/${id}`, { method: "PATCH", body: JSON.stringify(body) });

export const deleteEntity = (entity: Entity, id: string) =>
  req(`/${entity}/${id}`, { method: "DELETE" });
