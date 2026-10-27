import { useState } from "react";
import { apiFetch } from "../api/client";

export function InviteClaim() {
  const [token, setToken] = useState("");
  const [status, setStatus] = useState("");

  async function claim() {
    const res = await apiFetch("/api/invites/claim", {
      method: "POST",
      body: JSON.stringify({ token }),
    });
    setStatus(res.ok ? "Claimed" : "Failed");
  }

  return (
    <div>
      <h2>Claim invite</h2>
      <input value={token} onChange={(e) => setToken(e.target.value)} placeholder="token" />
      <button onClick={claim}>Claim</button>
      <p>{status}</p>
    </div>
  );
}
