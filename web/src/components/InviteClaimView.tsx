import { useState } from "react";
import { useNavigation } from "../context/useNavigation";
import type { Cadence } from "../types";

export function InviteClaimView() {
  const { childId, inviteToken, navigate } = useNavigation();
  const [token, setToken] = useState(inviteToken || "inv_eleanor_892a");
  const [alias, setAlias] = useState("Gaga");
  const [cadence, setCadence] = useState<Cadence>("weekly");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [success, setSuccess] = useState(false);

  const childName = childId === "maya" ? "Maya" : "Leo";

  const handleClaim = (e: React.FormEvent) => {
    e.preventDefault();
    if (!alias.trim()) return;

    setIsSubmitting(true);
    setTimeout(() => {
      setIsSubmitting(false);
      setSuccess(true);
      setTimeout(() => {
        navigate(`/chronicle/${childId}`);
      }, 1200);
    }, 600);
  };

  return (
    <div
      className="invite-claim-view"
      style={{ display: "flex", flexDirection: "column", gap: "20px" }}
    >
      {/* Top Banner: Child Avatar & Welcome Greeting */}
      <div
        className="card"
        style={{
          textAlign: "center",
          background:
            "linear-gradient(135deg, var(--color-surface) 0%, var(--color-surface-variant) 100%)",
          padding: "24px 16px",
          alignItems: "center",
          gap: "12px",
        }}
      >
        <div
          style={{
            width: "64px",
            height: "64px",
            borderRadius: "50%",
            background: "var(--color-badge-bg)",
            border: "3px solid var(--color-primary)",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            fontSize: "32px",
          }}
        >
          🧒
        </div>
        <div>
          <h2 className="title-display" style={{ fontSize: "20px", margin: "0 0 4px" }}>
            You've been invited to {childName}'s Chronicle!
          </h2>
          <p className="caption-meta" style={{ margin: 0, fontSize: "13px" }}>
            Invited by Sarah & David Miller • No password required
          </p>
        </div>
        <span className="badge badge-primary" style={{ fontSize: "11px" }}>
          Invite Token: {token}
        </span>
      </div>

      {success ? (
        <div className="card" style={{ textAlign: "center", padding: "32px 16px", gap: "12px" }}>
          <span style={{ fontSize: "36px" }}>🎉</span>
          <h3 className="section-heading">Welcome, {alias}!</h3>
          <p className="body-regular" style={{ color: "var(--color-text-muted)" }}>
            Your display alias and check-in cadence are set. Entering {childName}'s chronicle...
          </p>
        </div>
      ) : (
        <form
          onSubmit={handleClaim}
          style={{ display: "flex", flexDirection: "column", gap: "16px" }}
        >
          {/* Step 1: Confirm Display Name */}
          <div className="card">
            <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
              <span
                className="badge badge-primary"
                style={{
                  width: "20px",
                  height: "20px",
                  borderRadius: "50%",
                  padding: 0,
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                }}
              >
                1
              </span>
              <h3 className="card-title">What should {childName} call you?</h3>
            </div>
            <p className="caption-meta" style={{ margin: "2px 0 8px" }}>
              This will be your personalized name across AI check-ins and memory timeline entries.
            </p>

            <input
              className="input-capsule"
              value={alias}
              onChange={(e) => setAlias(e.target.value)}
              placeholder="e.g. Gaga, Nana, Uncle Ben"
              required
            />
            <span className="caption-meta" style={{ color: "var(--color-primary)" }}>
              ✓ "{alias}" is available in {childName}'s circle
            </span>
          </div>

          {/* Step 2: Choose Prompt Cadence */}
          <div className="card">
            <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
              <span
                className="badge badge-primary"
                style={{
                  width: "20px",
                  height: "20px",
                  borderRadius: "50%",
                  padding: 0,
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                }}
              >
                2
              </span>
              <h3 className="card-title">How often should Agent 1 prompt you?</h3>
            </div>
            <p className="caption-meta" style={{ margin: "2px 0 8px" }}>
              We'll send gentle, tailored questions to help you share stories before they are
              forgotten.
            </p>

            <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
              {[
                {
                  value: "weekly",
                  title: "Weekly Check-ins",
                  desc: "A short, fun story prompt every Sunday afternoon.",
                },
                {
                  value: "monthly",
                  title: "Monthly Digest",
                  desc: "A reflective question each month aligned with developmental milestones.",
                },
                {
                  value: "special-occasions",
                  title: "Special Occasions",
                  desc: "Prompts only on birthdays, holidays, and family milestones.",
                },
                {
                  value: "none",
                  title: "No Automatic Prompts",
                  desc: "Contribute photos and voice notes manually whenever you wish.",
                },
              ].map((opt) => (
                <label
                  key={opt.value}
                  style={{
                    display: "flex",
                    alignItems: "flex-start",
                    gap: "10px",
                    padding: "10px 12px",
                    borderRadius: "12px",
                    background:
                      cadence === opt.value
                        ? "var(--color-badge-bg)"
                        : "var(--color-surface-variant)",
                    border:
                      cadence === opt.value
                        ? "1px solid var(--color-primary)"
                        : "1px solid transparent",
                    cursor: "pointer",
                  }}
                >
                  <input
                    type="radio"
                    name="cadence"
                    value={opt.value}
                    checked={cadence === opt.value}
                    onChange={() => setCadence(opt.value as Cadence)}
                    style={{ marginTop: "3px" }}
                  />
                  <div>
                    <span style={{ fontWeight: 600, fontSize: "13px" }}>{opt.title}</span>
                    <p className="caption-meta" style={{ margin: "2px 0 0" }}>
                      {opt.desc}
                    </p>
                  </div>
                </label>
              ))}
            </div>
          </div>

          {/* Optional token manual override */}
          <div style={{ padding: "0 4px" }}>
            <span className="caption-meta">Token: </span>
            <input
              value={token}
              onChange={(e) => setToken(e.target.value)}
              style={{
                background: "transparent",
                border: "none",
                fontSize: "12px",
                color: "var(--color-text-muted)",
              }}
            />
          </div>

          {/* Primary CTA Button */}
          <button
            type="submit"
            className="btn btn-primary"
            style={{ padding: "12px 20px", fontSize: "15px" }}
            disabled={isSubmitting}
          >
            {isSubmitting ? "Connecting to Circle..." : `Enter ${childName}'s Chronicle`}
          </button>
        </form>
      )}
    </div>
  );
}
