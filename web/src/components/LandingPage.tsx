import { useState } from "react";
import { useNavigation } from "../context/useNavigation";
import { useTheme } from "../context/useTheme";

export function LandingPage() {
  const { navigate } = useNavigation();
  const { setTheme } = useTheme();
  const [inviteTokenInput, setInviteTokenInput] = useState("");
  const [selectedAgentTab, setSelectedAgentTab] = useState<"prompter" | "curator" | "guardian">(
    "prompter",
  );
  const [previewTheme, setPreviewTheme] = useState<"light" | "dark">("light");

  const handleClaimSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (inviteTokenInput.trim()) {
      navigate(`/invite/claim?token=${encodeURIComponent(inviteTokenInput.trim())}`);
    } else {
      navigate("/invite/claim");
    }
  };

  return (
    <div className="landing-page" style={{ display: "flex", flexDirection: "column", gap: "28px" }}>
      {/* Hero Section */}
      <section className="landing-hero">
        <span className="badge badge-primary" style={{ padding: "4px 12px", fontSize: "12px" }}>
          🌿 AI-Guided Family Chronicles
        </span>
        <h2 className="landing-headline">
          Capture childhood before it fades. Effortless family chronicles for the whole circle.
        </h2>
        <p className="landing-subheadline">
          Invite grandparents, aunts, and uncles via WhatsApp or iMessage—no account setup required.
          Gentle AI prompts them for stories, transcribes audio, and creates a gift your child will
          cherish forever.
        </p>

        <div
          style={{
            display: "flex",
            flexWrap: "wrap",
            gap: "10px",
            justifyContent: "center",
            width: "100%",
            maxWidth: "420px",
          }}
        >
          <button
            className="btn btn-primary"
            style={{ flex: "1 1 180px", padding: "12px 20px", fontSize: "14px" }}
            onClick={() => navigate("/dashboard")}
          >
            Start Household Chronicle
          </button>
          <button
            className="btn btn-secondary"
            style={{ flex: "1 1 140px", padding: "12px 20px", fontSize: "14px" }}
            onClick={() => {
              const el = document.getElementById("hero-invite-input");
              el?.focus();
            }}
          >
            Have an Invite Link?
          </button>
        </div>

        {/* Hero Invite Input */}
        <form
          onSubmit={handleClaimSubmit}
          style={{ width: "100%", maxWidth: "380px", marginTop: "12px" }}
        >
          <div style={{ display: "flex", gap: "8px" }}>
            <input
              id="hero-invite-input"
              className="input-capsule"
              placeholder="Paste invite code or token..."
              value={inviteTokenInput}
              onChange={(e) => setInviteTokenInput(e.target.value)}
              aria-label="Invite token"
            />
            <button
              type="submit"
              className="btn btn-primary btn-sm"
              style={{ borderRadius: "20px" }}
            >
              Claim
            </button>
          </div>
        </form>

        {/* Mode Preview Switcher & Interactive Mobile App Preview */}
        <div
          style={{
            marginTop: "24px",
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            gap: "12px",
            width: "100%",
          }}
        >
          <div className="mode-preview-switcher">
            <button
              className={`mode-preview-option ${previewTheme === "light" ? "active" : ""}`}
              onClick={() => {
                setPreviewTheme("light");
                setTheme("light");
              }}
            >
              ☀️ Light Mode
            </button>
            <button
              className={`mode-preview-option ${previewTheme === "dark" ? "active" : ""}`}
              onClick={() => {
                setPreviewTheme("dark");
                setTheme("dark");
              }}
            >
              🌙 Dark Mode
            </button>
          </div>

          <div className="hero-preview-frame">
            <div
              style={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "center",
                borderBottom: "1px solid var(--color-border)",
                paddingBottom: "8px",
              }}
            >
              <div style={{ display: "flex", alignItems: "center", gap: "6px" }}>
                <div
                  style={{
                    width: "24px",
                    height: "24px",
                    borderRadius: "8px",
                    background: "var(--color-primary)",
                    color: "#fff",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    fontSize: "12px",
                    fontWeight: "bold",
                  }}
                >
                  C
                </div>
                <span style={{ fontWeight: 600, fontSize: "13px" }}>Leo's Chronicle</span>
              </div>
              <span className="badge badge-milestone" style={{ fontSize: "10px" }}>
                Age 3
              </span>
            </div>

            {/* Simulated Prompt Card in Preview */}
            <div className="agent-prompter-card" style={{ padding: "12px" }}>
              <div className="agent-header">
                <div
                  className="agent-avatar"
                  style={{ width: "28px", height: "28px", fontSize: "14px" }}
                >
                  🤖
                </div>
                <div>
                  <span className="card-title" style={{ fontSize: "13px" }}>
                    Hi Gaga!
                  </span>
                  <p className="caption-meta" style={{ margin: 0 }}>
                    Agent 1 • Monthly Check-in
                  </p>
                </div>
              </div>
              <div className="agent-bubble" style={{ fontSize: "13px", padding: "8px 12px" }}>
                "What was Leo's favorite song when you tucked him in last Sunday?"
              </div>
              <div style={{ display: "flex", gap: "6px" }}>
                <span className="pill" style={{ fontSize: "11px", padding: "3px 8px" }}>
                  🎙️ Voice Note
                </span>
                <span className="pill" style={{ fontSize: "11px", padding: "3px 8px" }}>
                  📷 Add Photo
                </span>
              </div>
            </div>

            {/* Simulated Memory Item in Preview */}
            <div className="card" style={{ padding: "12px", gap: "6px" }}>
              <div
                style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}
              >
                <span style={{ fontWeight: 600, fontSize: "13px" }}>Gaga (Grandmother)</span>
                <span className="caption-meta">Yesterday</span>
              </div>
              <div className="audio-player-widget" style={{ padding: "4px 10px" }}>
                <span>▶️</span>
                <div className="waveform-bars" style={{ height: "16px" }}>
                  <div className="waveform-bar" style={{ height: "60%" }}></div>
                  <div className="waveform-bar" style={{ height: "90%" }}></div>
                  <div className="waveform-bar" style={{ height: "40%" }}></div>
                  <div className="waveform-bar" style={{ height: "75%" }}></div>
                  <div className="waveform-bar" style={{ height: "50%" }}></div>
                </div>
                <span className="caption-meta">0:42</span>
              </div>
              <p style={{ margin: 0, fontSize: "12px", color: "var(--color-text)" }}>
                "He kept singing the teapot song and doing the little spout gesture..."
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Feature Arc: Frictionless Family Bridge (3-Step Feature Arc) */}
      <section style={{ display: "flex", flexDirection: "column", gap: "14px" }}>
        <h3 className="section-heading" style={{ textAlign: "center" }}>
          How It Works: The Frictionless Family Bridge
        </h3>
        <div style={{ display: "flex", flexDirection: "column", gap: "12px" }}>
          <div className="card">
            <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
              <span style={{ fontSize: "24px" }}>🔗</span>
              <div>
                <h4 className="card-title">1. Zero-Friction Invites</h4>
                <p className="caption-meta" style={{ margin: 0 }}>
                  WhatsApp & iMessage Magic Links
                </p>
              </div>
            </div>
            <p className="body-regular" style={{ margin: 0, color: "var(--color-text-muted)" }}>
              Contributors join via a single click on a messaging link—no password creation, no
              account setup, and no heavy app downloads required.
            </p>
          </div>

          <div className="card">
            <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
              <span style={{ fontSize: "24px" }}>💌</span>
              <div>
                <h4 className="card-title">2. Custom Display Aliases & Gentle AI Prompts</h4>
                <p className="caption-meta" style={{ margin: 0 }}>
                  Cadence-aware questions tailored to aliases
                </p>
              </div>
            </div>
            <p className="body-regular" style={{ margin: 0, color: "var(--color-text-muted)" }}>
              Every family member is recognized by their preferred name (<em>Gaga</em>,{" "}
              <em>Nana</em>, <em>Uncle Ben</em>). Agent 1 checks in with thoughtful questions
              tailored to milestones.
            </p>
          </div>

          <div className="card">
            <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
              <span style={{ fontSize: "24px" }}>🎙️</span>
              <div>
                <h4 className="card-title">3. Voice & Photo First: A Legacy to Hear & Read</h4>
                <p className="caption-meta" style={{ margin: 0 }}>
                  Timeline with audio waveforms & transcripts
                </p>
              </div>
            </div>
            <p className="body-regular" style={{ margin: 0, color: "var(--color-text-muted)" }}>
              Contributors record spontaneous voice notes directly in the browser. Agent 2
              transcribes every spoken memory and catalogs tags for chapters.
            </p>
          </div>
        </div>
      </section>

      {/* Three Agents Demo: Interactive Showcase */}
      <section style={{ display: "flex", flexDirection: "column", gap: "14px" }}>
        <div style={{ textAlign: "center" }}>
          <h3 className="section-heading">Three Asynchronous AI Agents</h3>
          <p className="caption-meta" style={{ margin: "4px 0 0" }}>
            Click an agent to explore how it coordinates via Azure event buses
          </p>
        </div>

        <div className="sub-header-tabs">
          <button
            className={`sub-header-tab ${selectedAgentTab === "prompter" ? "active" : ""}`}
            onClick={() => setSelectedAgentTab("prompter")}
          >
            🤖 Agent 1: Prompter
          </button>
          <button
            className={`sub-header-tab ${selectedAgentTab === "curator" ? "active" : ""}`}
            onClick={() => setSelectedAgentTab("curator")}
          >
            ✨ Agent 2: Curator
          </button>
          <button
            className={`sub-header-tab ${selectedAgentTab === "guardian" ? "active" : ""}`}
            onClick={() => setSelectedAgentTab("guardian")}
          >
            🛡️ Agent 3: Guardian
          </button>
        </div>

        {selectedAgentTab === "prompter" && (
          <div className="card" style={{ borderLeft: "4px solid var(--color-primary)" }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
              <h4 className="card-title">Agent 1: Contextual Nudger & Prompter</h4>
              <span className="badge badge-primary">Event Grid Trigger</span>
            </div>
            <p className="body-regular" style={{ margin: 0 }}>
              Evaluates contributor cadence (weekly, monthly, special occasions) and generates
              personalized, persona-aware questions referencing the child's developmental stage and
              chosen aliases.
            </p>
            <div className="card-secondary" style={{ marginTop: "4px" }}>
              <p className="caption-meta" style={{ margin: "0 0 4px" }}>
                Simulated Prompt Card:
              </p>
              <p style={{ margin: 0, fontStyle: "italic" }}>
                "Hi Gaga! Leo turns 3 this month. Do you remember what he said when you brought him
                strawberries?"
              </p>
            </div>
          </div>
        )}

        {selectedAgentTab === "curator" && (
          <div className="card" style={{ borderLeft: "4px solid var(--color-primary)" }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
              <h4 className="card-title">Agent 2: Curator & Memory Keeper</h4>
              <span className="badge badge-primary">Service Bus Queue</span>
            </div>
            <p className="body-regular" style={{ margin: 0 }}>
              Transcribes uploaded audio recordings, extracts semantic metadata (dates,
              relationships, topics), and generates vector embeddings for semantic search across
              years of memories.
            </p>
            <div className="card-secondary" style={{ marginTop: "4px" }}>
              <p className="caption-meta" style={{ margin: "0 0 4px" }}>
                Curated Metadata Output:
              </p>
              <div style={{ display: "flex", gap: "6px", flexWrap: "wrap" }}>
                <span className="badge badge-milestone">#first-steps</span>
                <span className="badge badge-primary">#language-development</span>
                <span className="badge badge-primary">Topic: Walking in Garden</span>
              </div>
            </div>
          </div>
        )}

        {selectedAgentTab === "guardian" && (
          <div className="card" style={{ borderLeft: "4px solid var(--color-milestone)" }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
              <h4 className="card-title">Agent 3: Guardian & Safety Reviewer</h4>
              <span className="badge badge-milestone">Content Safety Gate</span>
            </div>
            <p className="body-regular" style={{ margin: 0 }}>
              Performs quality scoring, duplicate detection, and checks for sensitive or confusing
              content. Dispatches flagged items directly to the household owner's review queue.
            </p>
            <div className="card-secondary" style={{ marginTop: "4px" }}>
              <p className="caption-meta" style={{ margin: "0 0 4px" }}>
                Safety Review Gate:
              </p>
              <p style={{ margin: 0, color: "var(--color-milestone)", fontWeight: 600 }}>
                ⚠️ Review duplicate/unclear memory (Confidence: 92%)
              </p>
            </div>
          </div>
        )}
      </section>

      {/* Trust, Privacy & Governance */}
      <section className="card" style={{ background: "var(--color-surface-variant)" }}>
        <h3 className="section-heading" style={{ fontSize: "16px" }}>
          🔒 Trust, Privacy & Governance
        </h3>
        <ul
          style={{
            paddingLeft: "20px",
            margin: "6px 0 0",
            display: "flex",
            flexDirection: "column",
            gap: "8px",
          }}
        >
          <li>
            <strong>Private Household Vault:</strong> Dedicated Cosmos DB storage without ad
            tracking or public discovery.
          </li>
          <li>
            <strong>Granular Circle Roles:</strong> Owners, Full Contributors, Observers, and locked
            Recipients (unlocked when older).
          </li>
          <li>
            <strong>Enterprise Identity & Audit Logging:</strong> Microsoft Easy Auth and
            tamper-proof audit trails on every alias/flag resolution.
          </li>
        </ul>
      </section>

      {/* Footer CTA & Authentication */}
      <section
        style={{
          textAlign: "center",
          padding: "16px 0 24px",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          gap: "12px",
        }}
      >
        <h3 className="title-display" style={{ fontSize: "20px" }}>
          Start Building Your Children's Chronicle
        </h3>
        <p className="caption-meta">Zero hassle for grandparents. Complete security for parents.</p>
        <button
          className="btn btn-primary"
          style={{ padding: "12px 28px", fontSize: "14px" }}
          onClick={() => navigate("/dashboard")}
        >
          Sign in with Microsoft
        </button>
      </section>
    </div>
  );
}
