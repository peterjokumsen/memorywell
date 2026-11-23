import { apiFetch } from "./client";

export type ApiMemory = {
  chronicle_id: string;
  contributor_id: string;
  text: string;
  topic?: string;
  milestone?: string | null;
  date?: string | null;
  alias_at_write_time?: string;
};

export async function listMemories(chronicleId: string): Promise<ApiMemory[]> {
  const res = await apiFetch(`/memories/${chronicleId}`);
  if (!res.ok) throw new Error("Failed to load memories");
  return res.json();
}

export async function createMemory(
  chronicleId: string,
  contributorId: string,
  alias: string,
  text: string,
): Promise<ApiMemory> {
  const res = await apiFetch("/memories", {
    method: "POST",
    body: JSON.stringify({ chronicle_id: chronicleId, contributor_id: contributorId, alias, text }),
  });
  if (!res.ok) throw new Error("Failed to save memory");
  return res.json();
}
