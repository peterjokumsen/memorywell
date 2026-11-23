async function apiFetch(path: string, init?: RequestInit): Promise<Response> {
  return fetch(path, {
    ...init,
    credentials: "include",
    headers: { "Content-Type": "application/json", ...(init?.headers ?? {}) },
  });
}

export async function createHousehold(name: string): Promise<any> {
  const res = await apiFetch("/api/households", { method: "POST", body: JSON.stringify({ name }) });
  if (!res.ok) throw new Error("Failed to create household");
  return res.json();
}

export async function listHouseholds(): Promise<any[]> {
  const res = await apiFetch("/api/households");
  if (!res.ok) throw new Error("Failed to load households");
  return res.json();
}

export async function createChronicle(householdId: string, name: string): Promise<any> {
  const res = await apiFetch("/api/chronicles", {
    method: "POST",
    body: JSON.stringify({ householdId, name }),
  });
  if (!res.ok) throw new Error("Failed to create chronicle");
  return res.json();
}

export async function listChronicles(householdId: string): Promise<any[]> {
  const res = await apiFetch(`/api/chronicles?householdId=${encodeURIComponent(householdId)}`);
  if (!res.ok) throw new Error("Failed to load chronicles");
  return res.json();
}

export async function listContributors(householdId: string): Promise<any[]> {
  const res = await apiFetch(`/api/contributors?householdId=${encodeURIComponent(householdId)}`);
  if (!res.ok) throw new Error("Failed to load contributors");
  return res.json();
}

export async function createContributor(householdId: string, payload: any): Promise<any> {
  const res = await apiFetch("/api/contributors", {
    method: "POST",
    body: JSON.stringify({ householdId, ...payload }),
  });
  if (!res.ok) throw new Error("Failed to create contributor");
  return res.json();
}
