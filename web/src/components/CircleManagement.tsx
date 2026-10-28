import { useState } from "react";
import { useNavigation } from "../context/useNavigation";
import type { Cadence, Contributor, Role } from "../types";

const INITIAL_ROSTER: Contributor[] = [
  {
    id: "c1",
    name: "Sarah Miller",
    canonicalRelation: "Mother",
    displayAlias: "Mom",
    role: "Owner",
    cadence: "weekly",
  },
  {
    id: "c2",
    name: "David Miller",
    canonicalRelation: "Father",
    displayAlias: "Dad",
    role: "Owner",
    cadence: "weekly",
  },
  {
    id: "c3",
    name: "Eleanor Vance",
    canonicalRelation: "Maternal Grandmother",
    displayAlias: "Gaga",
    role: "Full Contributor",
    cadence: "weekly",
  },
  {
    id: "c4",
    name: "Ben Miller",
    canonicalRelation: "Paternal Uncle",
    displayAlias: "Uncle Ben",
    role: "Observer",
    cadence: "monthly",
  },
  {
    id: "c5",
    name: "Leo Miller",
    canonicalRelation: "Child",
    displayAlias: "Leo",
    role: "Recipient",
    cadence: "none",
  },
];

function generateInviteUrl(name: string, relation: string, origin: string): string {
  const token = `inv_${name.toLowerCase().replace(/\s+/g, "")}_${Date.now().toString(36)}`;
  return `${origin}/invite/claim?token=${token}&relation=${encodeURIComponent(relation)}`;
}

export function CircleManagement() {
  const { childId, navigate } = useNavigation();
  const [roster, setRoster] = useState<Contributor[]>(INITIAL_ROSTER);

  // Magic Link generator state
  const [inviteName, setInviteName] = useState("");
  const [inviteRelation, setInviteRelation] = useState("");
  const [inviteRole, setInviteRole] = useState<Role>("Full Contributor");
  const [generatedLink, setGeneratedLink] = useState("");
  const [copied, setCopied] = useState(false);

  // Selected contributor for alias/cadence editor
  const [editingId, setEditingId] = useState<string>("c3"); // default to Eleanor (Gaga)

  const handleGenerateMagicLink = (e: React.FormEvent) => {
    e.preventDefault();
    if (!inviteName.trim() || !inviteRelation.trim()) return;

    const link = generateInviteUrl(inviteName, inviteRelation, window.location.origin);
    setGeneratedLink(link);
    setCopied(false);
  };

  const copyToClipboard = () => {
    if (!generatedLink) return;
    navigator.clipboard?.writeText(generatedLink);
    setCopied(true);
    setTimeout(() => setCopied(false), 2500);
  };

  const activeContributor = roster.find((c) => c.id === editingId) || roster[2];

  const updateAlias = (newAlias: string) => {
    setRoster((prev) =>
      prev.map((c) => (c.id === editingId ? { ...c, displayAlias: newAlias } : c)),
    );
  };

  const updateCadence = (newCadence: Cadence) => {
    setRoster((prev) => prev.map((c) => (c.id === editingId ? { ...c, cadence: newCadence } : c)));
  };

  return (
    <div
      className="circle-management"
      style={{ display: "flex", flexDirection: "column", gap: "18px" }}
    >
      {/* Header Context */}
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <button className="pill" onClick={() => navigate(`/chronicle/${childId}`)}>
          ← Chronicle
        </button>
        <h2 className="title-display" style={{ fontSize: "18px", margin: 0 }}>
          Circle of Care Management
        </h2>
        <span className="badge badge-primary">5 Members</span>
      </div>

      {/* Active Contributor Roster */}
      <section className="card" style={{ gap: "12px" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <h3 className="section-heading" style={{ fontSize: "16px" }}>
            Active Contributor Roster
          </h3>
          <span className="caption-meta">Click member to edit</span>
        </div>

        <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
          {roster.map((c) => {
            const isSelected = c.id === editingId;
            return (
              <div
                key={c.id}
                onClick={() => setEditingId(c.id)}
                style={{
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "space-between",
                  padding: "10px 12px",
                  borderRadius: "12px",
                  background: isSelected ? "var(--color-badge-bg)" : "var(--color-surface-variant)",
                  border: isSelected ? "1px solid var(--color-primary)" : "1px solid transparent",
                  cursor: "pointer",
                }}
              >
                <div>
                  <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
                    <span style={{ fontWeight: 600, fontSize: "14px" }}>{c.displayAlias}</span>
                    <span className="caption-meta">({c.canonicalRelation})</span>
                  </div>
                  <span className="caption-meta">{c.name}</span>
                </div>

                <div style={{ display: "flex", alignItems: "center", gap: "6px" }}>
                  <span
                    className="badge badge-primary"
                    style={{
                      background:
                        c.role === "Owner" ? "var(--color-primary)" : "var(--color-surface)",
                      color: c.role === "Owner" ? "#ffffff" : "var(--color-primary)",
                    }}
                  >
                    {c.role}
                  </span>
                  <span className="badge badge-milestone" style={{ fontSize: "10px" }}>
                    {c.cadence}
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      </section>

      {/* Alias & Cadence Manager for Selected Contributor */}
      <section className="card">
        <h3 className="section-heading" style={{ fontSize: "16px" }}>
          Contributor Settings: {activeContributor.displayAlias}
        </h3>
        <p className="caption-meta" style={{ margin: "2px 0 12px" }}>
          Canonical Relation: {activeContributor.canonicalRelation} • Role: {activeContributor.role}
        </p>

        <div style={{ display: "flex", flexDirection: "column", gap: "12px" }}>
          <div>
            <label
              style={{ display: "block", fontSize: "13px", fontWeight: 600, marginBottom: "4px" }}
            >
              Display Alias (What the child and AI call them):
            </label>
            <input
              className="input-capsule"
              value={activeContributor.displayAlias}
              onChange={(e) => updateAlias(e.target.value)}
              placeholder="e.g. Gaga, Nana, Pop-Pop"
            />
            <span className="caption-meta" style={{ display: "block", marginTop: "4px" }}>
              Past memories retain their snapshot alias ({activeContributor.displayAlias})
            </span>
          </div>

          <div>
            <label
              style={{ display: "block", fontSize: "13px", fontWeight: 600, marginBottom: "4px" }}
            >
              Agent 1 Check-in Cadence:
            </label>
            <select
              className="input-capsule"
              value={activeContributor.cadence}
              onChange={(e) => updateCadence(e.target.value as Cadence)}
            >
              <option value="none">none (never nudged)</option>
              <option value="special-occasions">special-occasions (birthdays & holidays)</option>
              <option value="monthly">monthly (gentle monthly question)</option>
              <option value="weekly">weekly (regular weekly check-in)</option>
            </select>
          </div>
        </div>
      </section>

      {/* Magic Link Generator Panel */}
      <section className="card" style={{ gap: "12px" }}>
        <h3 className="section-heading" style={{ fontSize: "16px" }}>
          Invite Generator (WhatsApp & iMessage Magic Link)
        </h3>
        <p className="caption-meta" style={{ margin: "0" }}>
          Generate a zero-friction link with pre-assigned canonical relation. No password required.
        </p>

        <form
          onSubmit={handleGenerateMagicLink}
          style={{ display: "flex", flexDirection: "column", gap: "10px" }}
        >
          <div>
            <label
              style={{ display: "block", fontSize: "12px", fontWeight: 600, marginBottom: "4px" }}
            >
              Recipient's Full Name:
            </label>
            <input
              className="input-capsule"
              placeholder="e.g. Grandma Eleanor"
              value={inviteName}
              onChange={(e) => setInviteName(e.target.value)}
            />
          </div>

          <div>
            <label
              style={{ display: "block", fontSize: "12px", fontWeight: 600, marginBottom: "4px" }}
            >
              Canonical Relation to Child:
            </label>
            <input
              className="input-capsule"
              placeholder="e.g. Maternal Grandmother, Uncle, Godmother"
              value={inviteRelation}
              onChange={(e) => setInviteRelation(e.target.value)}
            />
          </div>

          <div>
            <label
              style={{ display: "block", fontSize: "12px", fontWeight: 600, marginBottom: "4px" }}
            >
              Initial Role:
            </label>
            <select
              className="input-capsule"
              value={inviteRole}
              onChange={(e) => setInviteRole(e.target.value as Role)}
            >
              <option value="Full Contributor">Full Contributor (Record memories & photos)</option>
              <option value="Observer">Observer (Read-only chronicle access)</option>
              <option value="Owner">Co-Owner (Manage circle & review)</option>
            </select>
          </div>

          <button type="submit" className="btn btn-primary" style={{ marginTop: "6px" }}>
            Generate Magic Link
          </button>
        </form>

        {generatedLink && (
          <div
            className="card-secondary"
            style={{ display: "flex", flexDirection: "column", gap: "8px" }}
          >
            <span style={{ fontSize: "12px", fontWeight: 600, color: "var(--color-primary)" }}>
              Shareable Invite Link Created:
            </span>
            <div style={{ display: "flex", gap: "8px" }}>
              <input
                readOnly
                value={generatedLink}
                className="input-capsule"
                style={{ fontSize: "12px" }}
              />
              <button className="btn btn-primary btn-sm" onClick={copyToClipboard}>
                {copied ? "Copied! ✓" : "Copy"}
              </button>
            </div>
            <p className="caption-meta" style={{ margin: 0 }}>
              Send via WhatsApp or SMS. Recipient clicks to confirm display name & enters
              immediately.
            </p>
          </div>
        )}
      </section>
    </div>
  );
}
