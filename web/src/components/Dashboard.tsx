import { useState } from "react";
import { useNavigation } from "../context/useNavigation";
import type { ChildChronicle, Contributor } from "../types";

const INITIAL_CHRONICLES: ChildChronicle[] = [
  {
    id: "leo",
    name: "Leo",
    age: "Age 3",
    avatar: "🧒",
    memoryCount: 18,
    lastActivity: "2h ago",
  },
  {
    id: "maya",
    name: "Maya",
    age: "Age 1",
    avatar: "👶",
    memoryCount: 7,
    lastActivity: "Yesterday",
  },
];

const INITIAL_CONTRIBUTORS: Contributor[] = [
  {
    id: "c1",
    name: "Sarah Miller",
    canonicalRelation: "Mother",
    displayAlias: "Mom",
    role: "Owner",
    cadence: "weekly",
    avatar: "👩",
  },
  {
    id: "c2",
    name: "David Miller",
    canonicalRelation: "Father",
    displayAlias: "Dad",
    role: "Owner",
    cadence: "weekly",
    avatar: "👨",
  },
  {
    id: "c3",
    name: "Eleanor Vance",
    canonicalRelation: "Maternal Grandmother",
    displayAlias: "Gaga",
    role: "Full Contributor",
    cadence: "weekly",
    avatar: "👵",
  },
  {
    id: "c4",
    name: "Ben Miller",
    canonicalRelation: "Paternal Uncle",
    displayAlias: "Uncle Ben",
    role: "Observer",
    cadence: "monthly",
    avatar: "🧔",
  },
  {
    id: "c5",
    name: "Leo Miller",
    canonicalRelation: "Child",
    displayAlias: "Leo",
    role: "Recipient",
    cadence: "none",
    avatar: "🧒",
  },
];

export function Dashboard() {
  const { navigate, setChildId } = useNavigation();
  const [household, setHousehold] = useState("Smith Family Household");
  const [flagPending, setFlagPending] = useState(true);

  const openChronicle = (id: string) => {
    setChildId(id);
    navigate(`/chronicle/${id}`);
  };

  const openCircle = () => {
    navigate("/chronicle/leo/circle");
  };

  return (
    <div
      className="dashboard-view"
      style={{ display: "flex", flexDirection: "column", gap: "20px" }}
    >
      {/* Top Bar: Household Switcher */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
          <span style={{ fontSize: "16px" }}>🏡</span>
          <select
            value={household}
            onChange={(e) => setHousehold(e.target.value)}
            className="input-capsule"
            style={{ width: "auto", padding: "4px 12px", fontSize: "13px", fontWeight: 600 }}
            aria-label="Household switcher"
          >
            <option value="Smith Family Household">Smith Family Household</option>
            <option value="Dev Household (hh-dev)">Dev Household (hh-dev)</option>
          </select>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: "6px" }}>
          <span className="badge badge-primary">Owner Mode</span>
        </div>
      </div>

      {/* Children's Chronicles Section */}
      <section style={{ display: "flex", flexDirection: "column", gap: "12px" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <h2 className="section-heading">Our Children's Chronicles</h2>
          <span className="caption-meta">2 Chronicles active</span>
        </div>

        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "12px" }}>
          {INITIAL_CHRONICLES.map((chronicle) => (
            <div
              key={chronicle.id}
              className="card"
              style={{ cursor: "pointer", padding: "14px", position: "relative" }}
              onClick={() => openChronicle(chronicle.id)}
            >
              <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
                <div style={{ fontSize: "28px" }}>{chronicle.avatar}</div>
                <div>
                  <h3 className="card-title" style={{ fontSize: "16px" }}>
                    {chronicle.name}
                  </h3>
                  <span className="badge badge-milestone" style={{ marginTop: "2px" }}>
                    {chronicle.age}
                  </span>
                </div>
              </div>
              <div
                style={{
                  marginTop: "8px",
                  borderTop: "1px solid var(--color-border)",
                  paddingTop: "8px",
                  display: "flex",
                  justifyContent: "space-between",
                }}
              >
                <span className="caption-meta">{chronicle.memoryCount} memories</span>
                <span className="caption-meta">{chronicle.lastActivity}</span>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* Circle of Care Overview & Contributor Strip */}
      <section style={{ display: "flex", flexDirection: "column", gap: "12px" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <h2 className="section-heading">Circle of Care</h2>
          <button className="btn btn-outline btn-sm" onClick={openCircle}>
            + Invite Contributor
          </button>
        </div>

        <div className="card" style={{ padding: "12px 14px" }}>
          <p className="caption-meta" style={{ margin: "0 0 8px" }}>
            Active contributors & prompt cadences:
          </p>
          <div className="contributor-strip">
            {INITIAL_CONTRIBUTORS.map((c) => (
              <div
                key={c.id}
                className="contributor-item"
                onClick={openCircle}
                title={`${c.displayAlias} (${c.canonicalRelation}) — ${c.role}`}
              >
                <div className="contributor-avatar">{c.avatar || "👤"}</div>
                <span style={{ fontSize: "12px", fontWeight: 600 }}>{c.displayAlias}</span>
                <span
                  className="badge badge-primary"
                  style={{
                    fontSize: "9px",
                    padding: "1px 5px",
                    background:
                      c.role === "Owner" ? "var(--color-badge-bg)" : "var(--color-surface-variant)",
                  }}
                >
                  {c.role === "Recipient" ? "Locked" : c.role}
                </span>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Guardian Review Queue Banner (Owner Only) */}
      {flagPending ? (
        <section className="guardian-banner" onClick={() => navigate("/guardian/review")}>
          <div style={{ display: "flex", alignItems: "center", gap: "12px" }}>
            <span style={{ fontSize: "24px" }}>🛡️</span>
            <div>
              <h4
                style={{ margin: 0, fontSize: "14px", fontWeight: 600, color: "var(--color-text)" }}
              >
                Agent Guardian: 1 Item Requiring Review
              </h4>
              <p className="caption-meta" style={{ margin: "2px 0 0" }}>
                Review duplicate/unclear memory from Gaga
              </p>
            </div>
          </div>
          <div style={{ display: "flex", gap: "6px" }}>
            <button
              className="btn btn-primary btn-sm"
              onClick={(e) => {
                e.stopPropagation();
                setFlagPending(false);
              }}
            >
              Approve
            </button>
            <button
              className="btn btn-secondary btn-sm"
              onClick={(e) => {
                e.stopPropagation();
                navigate("/guardian/review");
              }}
            >
              View
            </button>
          </div>
        </section>
      ) : (
        <div
          className="card-secondary"
          style={{ display: "flex", alignItems: "center", gap: "10px" }}
        >
          <span style={{ fontSize: "18px" }}>✅</span>
          <span className="caption-meta">
            Guardian review queue is clear. All memories verified.
          </span>
        </div>
      )}
    </div>
  );
}
