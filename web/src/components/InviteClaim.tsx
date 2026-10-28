import { useState } from "react";
import { apiFetch } from "../api/client";

export function InviteClaim() {
  const [token, setToken] = useState("");
  const [status, setStatus] = useState("");

  async function claim() {
    try {
      const res = await apiFetch("/api/invites/claim", {
        method: "POST",
        body: JSON.stringify({ token }),
      });
      setStatus(res.ok ? "Claimed" : "Failed");
    } catch {
      setStatus("Failed");
    }
  }

  return (
    <div className="card" style={{ gap: "10px" }}>
      <h2 className="section-heading">Claim invite</h2>
      <p className="caption-meta" style={{ margin: 0 }}>
        Enter your zero-friction invite token below:
      </p>
      <div style={{ display: "flex", gap: "8px" }}>
        <input
          className="input-capsule"
          value={token}
          onChange={(e) => setToken(e.target.value)}
          placeholder="token"
        />
        <button className="btn btn-primary" onClick={claim}>
          Claim
        </button>
      </div>
      {status && (
        <p
          className="caption-meta"
          style={{
            margin: 0,
            fontWeight: 600,
            color: status === "Claimed" ? "var(--color-primary)" : "var(--color-danger)",
          }}
        >
          {status}
        </p>
      )}
    </div>
  );
}
