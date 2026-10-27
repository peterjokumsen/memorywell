import { describe, it, expect, vi } from "vitest";
import { apiFetch } from "./client";

describe("apiFetch", () => {
  it("calls fetch with base url", async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response("{}"));
    vi.stubGlobal("fetch", fetchMock);
    await apiFetch("/x");
    expect(fetchMock).toHaveBeenCalled();
    vi.unstubAllGlobals();
  });
});
