import { useState } from "react";
import { useNavigation } from "../context/useNavigation";
import type { AuditEntry, ReviewFlag } from "../types";

const INITIAL_FLAGS: ReviewFlag[] = [
  {
    id: "flag-1",
    type: "memory",
    reason: "Potential duplicate memory detected",
    score: 0.92,
    authorAlias: "Gaga",
    contentPreview:
      "Leo took his first three steps toward the pantry... (Very similar to entry #m1 from this morning)",
    status: "pending",
    timestamp: "Today at 3:20 PM",
  },
  {
    id: "flag-2",
    type: "alias",
    reason: "Requested alias change validation",
    score: 0.88,
    authorAlias: "Eleanor Vance",
    contentPreview: "Requested display alias update from 'Grandmother' to 'Gaga'",
    requestedAlias: "Gaga",
    status: "pending",
    timestamp: "Yesterday",
  },
];

const INITIAL_AUDIT_LOG: AuditEntry[] = [
  {
    id: "audit-1",
    timestamp: "2026-10-27 14:10",
    actor: "sarah@miller.family (Owner)",
    action: "role.assign",
    target: "ben@miller.family",
    details: "Assigned role 'Observer'",
  },
  {
    id: "audit-2",
    timestamp: "2026-10-26 19:45",
    actor: "david@miller.family (Owner)",
    action: "flag.approve",
    target: "memory-882",
    details: "Approved voice memory transcription after low-confidence warning",
  },
  {
    id: "audit-3",
    timestamp: "2026-10-25 11:30",
    actor: "eleanor@vance.net",
    action: "invite.claimed",
    target: "inv_eleanor_k89x",
    details: "Claimed invite token; registered alias 'Gaga'",
  },
];

function createAuditEntry(action: string, target: string, details: string): AuditEntry {
  return {
    id: `audit-${Date.now()}`,
    timestamp: new Date().toISOString().replace("T", " ").substring(0, 16),
    actor: "david@miller.family (Owner)",
    action,
    target,
    details,
  };
}

export function GuardianReview() {
  const { navigate, childId } = useNavigation();
  const [filter, setFilter] = useState<"all" | "flags" | "alias">("all");
  const [flags, setFlags] = useState<ReviewFlag[]>(INITIAL_FLAGS);
  const [auditLog, setAuditLog] = useState<AuditEntry[]>(INITIAL_AUDIT_LOG);
  const [editingFlagId, setEditingFlagId] = useState<string | null>(null);
  const [editedText, setEditedText] = useState<string>("");

  const pendingFlags = flags.filter((f) => f.status === "pending");

  const filteredFlags = pendingFlags.filter((f) => {
    if (filter === "all") return true;
    if (filter === "flags") return f.type === "memory";
    if (filter === "alias") return f.type === "alias";
    return true;
  });

  const handleResolve = (
    flagId: string,
    resolution: "approved" | "hidden" | "dismissed",
    newContent?: string,
  ) => {
    const targetFlag = flags.find((f) => f.id === flagId);
    if (!targetFlag) return;

    setFlags((prev) => prev.map((f) => (f.id === flagId ? { ...f, status: resolution } : f)));

    const newAuditEntry = createAuditEntry(
      `guardian.${resolution}`,
      targetFlag.id,
      newContent
        ? `Resolved with edit: ${newContent}`
        : `Resolved flag (${targetFlag.reason}) as ${resolution}`,
    );

    setAuditLog([newAuditEntry, ...auditLog]);
    setEditingFlagId(null);
  };

  return (
    <div
      className="guardian-review"
      style={{ display: "flex", flexDirection: "column", gap: "18px" }}
    >
      {/* Top Header */}
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <button className="pill" onClick={() => navigate(`/chronicle/${childId}`)}>
          ← Back to Chronicle
        </button>
        <h2 className="title-display" style={{ fontSize: "18px", margin: 0 }}>
          Guardian Safety & Audit Queue
        </h2>
        <span className="badge badge-milestone">{pendingFlags.length} Pending</span>
      </div>

      {/* Filter Pills */}
      <div style={{ display: "flex", gap: "8px" }}>
        <button
          className={`pill ${filter === "all" ? "active" : ""}`}
          onClick={() => setFilter("all")}
        >
          All ({pendingFlags.length})
        </button>
        <button
          className={`pill ${filter === "flags" ? "active" : ""}`}
          onClick={() => setFilter("flags")}
        >
          Flags ({pendingFlags.filter((f) => f.type === "memory").length})
        </button>
        <button
          className={`pill ${filter === "alias" ? "active" : ""}`}
          onClick={() => setFilter("alias")}
        >
          Alias Requests ({pendingFlags.filter((f) => f.type === "alias").length})
        </button>
      </div>

      {/* Review Cards List */}
      <section style={{ display: "flex", flexDirection: "column", gap: "12px" }}>
        {filteredFlags.length === 0 ? (
          <div className="card-secondary" style={{ textAlign: "center", padding: "24px" }}>
            <span style={{ fontSize: "28px" }}>🎉</span>
            <h4 style={{ margin: "8px 0 4px" }}>All clear!</h4>
            <p className="caption-meta" style={{ margin: 0 }}>
              Agent 3 Guardian review queue is empty. No flagged memories or alias conflicts.
            </p>
          </div>
        ) : (
          filteredFlags.map((flag) => (
            <article
              key={flag.id}
              className="card"
              style={{ borderLeft: "4px solid var(--color-milestone)" }}
            >
              <div
                style={{
                  display: "flex",
                  justifyContent: "space-between",
                  alignItems: "flex-start",
                }}
              >
                <div>
                  <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
                    <span style={{ fontSize: "16px" }}>⚠️</span>
                    <h3 className="card-title" style={{ fontSize: "14px" }}>
                      {flag.reason}
                    </h3>
                  </div>
                  <span className="caption-meta">
                    Author: {flag.authorAlias} • {flag.timestamp}
                  </span>
                </div>

                <span className="badge badge-milestone" style={{ fontSize: "11px" }}>
                  Confidence: {Math.round(flag.score * 100)}%
                </span>
              </div>

              {/* Memory / Alias Preview Snippet */}
              {editingFlagId === flag.id ? (
                <div
                  style={{ display: "flex", flexDirection: "column", gap: "8px", margin: "6px 0" }}
                >
                  <textarea
                    className="input-capsule"
                    rows={3}
                    style={{ borderRadius: "12px", width: "100%", fontFamily: "inherit" }}
                    value={editedText}
                    onChange={(e) => setEditedText(e.target.value)}
                  />
                  <div style={{ display: "flex", gap: "6px" }}>
                    <button
                      className="btn btn-primary btn-sm"
                      onClick={() => handleResolve(flag.id, "approved", editedText)}
                    >
                      Save & Approve
                    </button>
                    <button
                      className="btn btn-secondary btn-sm"
                      onClick={() => setEditingFlagId(null)}
                    >
                      Cancel
                    </button>
                  </div>
                </div>
              ) : (
                <div className="card-secondary" style={{ padding: "10px 12px", margin: "4px 0" }}>
                  <p style={{ margin: 0, fontStyle: "italic", fontSize: "13px" }}>
                    "{flag.contentPreview}"
                  </p>
                </div>
              )}

              {/* Action Bar: Approve, Edit, Hide, Dismiss */}
              {editingFlagId !== flag.id && (
                <div style={{ display: "flex", gap: "8px", flexWrap: "wrap", marginTop: "4px" }}>
                  <button
                    className="btn btn-primary btn-sm"
                    onClick={() => handleResolve(flag.id, "approved")}
                  >
                    ✓ Approve
                  </button>
                  <button
                    className="btn btn-secondary btn-sm"
                    onClick={() => {
                      setEditingFlagId(flag.id);
                      setEditedText(flag.contentPreview);
                    }}
                  >
                    ✏️ Edit
                  </button>
                  <button
                    className="btn btn-outline btn-sm"
                    onClick={() => handleResolve(flag.id, "hidden")}
                  >
                    👁️ Hide
                  </button>
                  <button
                    className="btn btn-danger btn-sm"
                    onClick={() => handleResolve(flag.id, "dismissed")}
                  >
                    ✕ Dismiss
                  </button>
                </div>
              )}
            </article>
          ))
        )}
      </section>

      {/* Audit History Log */}
      <section className="card" style={{ gap: "10px" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <h3 className="section-heading" style={{ fontSize: "15px" }}>
            Immutable Household Audit Log
          </h3>
          <span className="caption-meta">{auditLog.length} recorded events</span>
        </div>

        <div style={{ overflowX: "auto" }}>
          <table className="audit-table">
            <thead>
              <tr>
                <th>Timestamp</th>
                <th>Actor</th>
                <th>Action</th>
                <th>Details</th>
              </tr>
            </thead>
            <tbody>
              {auditLog.map((log) => (
                <tr key={log.id}>
                  <td className="caption-meta" style={{ whiteSpace: "nowrap" }}>
                    {log.timestamp}
                  </td>
                  <td style={{ fontWeight: 500 }}>{log.actor}</td>
                  <td>
                    <span className="badge badge-primary">{log.action}</span>
                  </td>
                  <td style={{ color: "var(--color-text-muted)" }}>{log.details}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
