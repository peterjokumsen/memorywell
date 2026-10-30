import { useEffect, useState } from "react";
import { useNavigation } from "../context/useNavigation";
import type { Memory } from "../types";
import { createMemory, listMemories } from "../api/memories";

const INITIAL_MEMORIES: Memory[] = [
  {
    id: "m1",
    chronicleId: "leo",
    authorName: "Eleanor Vance",
    authorAlias: "Gaga",
    authorRelation: "Maternal Grandmother",
    date: "Today at 3:15 PM",
    text: "Leo took his first three independent steps toward the kitchen pantry! He was giggling the whole way and clapped for himself.",
    hasAudio: true,
    audioDuration: "0:38",
    tags: ["#first-steps", "#milestone", "#pantry-adventure"],
    milestoneChapter: "Walking & First Steps",
  },
  {
    id: "m2",
    chronicleId: "leo",
    authorName: "Sarah Miller",
    authorAlias: "Mom",
    authorRelation: "Mother",
    date: "Yesterday",
    text: "He whispered 'night night stars' when we looked out the nursery window. He has started connecting two words together reliably.",
    hasAudio: false,
    tags: ["#first-words", "#bedtime-ritual"],
    milestoneChapter: "First Words",
  },
  {
    id: "m3",
    chronicleId: "leo",
    authorName: "Eleanor Vance",
    authorAlias: "Gaga",
    authorRelation: "Maternal Grandmother",
    date: "Last week",
    text: "Tucked him in with the knitted bear his grandfather made. He wouldn't let go of the left paw.",
    hasAudio: true,
    audioDuration: "1:12",
    tags: ["#family-treasures", "#bedtime"],
    milestoneChapter: "Baby Years",
  },
];

export function ChronicleView() {
  const { childId, navigate } = useNavigation();
  const [activeTab, setActiveTab] = useState<"timeline" | "contributors" | "chapters">("timeline");
  const [activeChapterFilter, setActiveChapterFilter] = useState<string>("all");
  const [memories, setMemories] = useState<Memory[]>(INITIAL_MEMORIES);

  useEffect(() => {
    listMemories(childId)
      .then((items) =>
        setMemories(
          items.map((m, i) => ({
            id: `m-${i}`,
            chronicleId: m.chronicle_id,
            authorName: m.contributor_id,
            authorAlias: m.alias_at_write_time || "Contributor",
            authorRelation: "",
            date: m.date || "Just now",
            text: m.text,
            hasAudio: false,
            tags: [],
            milestoneChapter: m.milestone || undefined,
          })),
        ),
      )
      .catch(() => setMemories([]));
  }, [childId]);
  const [promptReplied, setPromptReplied] = useState(false);
  const [replyInput, setReplyInput] = useState("");
  const [isRecording, setIsRecording] = useState(false);
  const [recordSeconds, setRecordSeconds] = useState(0);
  const [photoSelected, setPhotoSelected] = useState<string | null>(null);
  const [playingAudioId, setPlayingAudioId] = useState<string | null>(null);

  const childName = childId === "maya" ? "Maya" : "Leo";
  const childAge = childId === "maya" ? "Age 1" : "Age 3";

  const handleSendReply = async () => {
    if (!replyInput.trim() && !isRecording && !photoSelected) return;
    const newMemory: Memory = {
      id: `m-${Date.now()}`,
      chronicleId: childId,
      authorName: "Eleanor Vance",
      authorAlias: "Gaga",
      authorRelation: "Maternal Grandmother",
      date: "Just now",
      text:
        replyInput.trim() ||
        (photoSelected ? "Shared a new family photo." : "Voice memory recorded."),
      hasAudio: isRecording || recordSeconds > 0,
      audioDuration:
        recordSeconds > 0 ? `0:${recordSeconds.toString().padStart(2, "0")}` : undefined,
      tags: ["#prompt-reply", "#family-story"],
      milestoneChapter: "Walking & First Steps",
    };
    setMemories([newMemory, ...memories]);
    void createMemory(
      childId,
      "contributor-1",
      "Gaga",
      replyInput.trim() || "Shared a memory.",
    ).catch(() => {});
    setReplyInput("");
    setPhotoSelected(null);
    setIsRecording(false);
    setRecordSeconds(0);
    setPromptReplied(true);
  };

  const toggleRecord = () => {
    if (isRecording) {
      setIsRecording(false);
    } else {
      setIsRecording(true);
      setRecordSeconds(14);
    }
  };

  const filteredMemories =
    activeChapterFilter === "all"
      ? memories
      : memories.filter(
          (m) => m.milestoneChapter?.toLowerCase().includes(activeChapterFilter.toLowerCase()),
        );

  return (
    <div
      className="chronicle-view"
      style={{ display: "flex", flexDirection: "column", gap: "16px" }}
    >
      {/* Top Header Bar Context */}
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <button
          className="pill"
          onClick={() => navigate("/dashboard")}
          aria-label="Back to dashboard"
        >
          ← Dashboard
        </button>
        <div style={{ textAlign: "center" }}>
          <h2 className="title-display" style={{ fontSize: "18px", margin: 0 }}>
            {childName}'s Chronicle
          </h2>
          <span className="caption-meta">{childAge} • Smith Family</span>
        </div>
        <button className="pill" onClick={() => navigate(`/chronicle/${childId}/circle`)}>
          Manage Circle
        </button>
      </div>

      {/* Sub-header Segmented Navigation Pills: Timeline, Contributors, Chapters */}
      <div className="sub-header-tabs" role="tablist">
        <button
          role="tab"
          aria-selected={activeTab === "timeline"}
          className={`sub-header-tab ${activeTab === "timeline" ? "active" : ""}`}
          onClick={() => setActiveTab("timeline")}
        >
          Timeline
        </button>
        <button
          role="tab"
          aria-selected={activeTab === "contributors"}
          className={`sub-header-tab ${activeTab === "contributors" ? "active" : ""}`}
          onClick={() => {
            setActiveTab("contributors");
            navigate(`/chronicle/${childId}/circle`);
          }}
        >
          Contributors
        </button>
        <button
          role="tab"
          aria-selected={activeTab === "chapters"}
          className={`sub-header-tab ${activeTab === "chapters" ? "active" : ""}`}
          onClick={() => setActiveTab("chapters")}
        >
          Chapters
        </button>
      </div>

      {/* Chapter Filter Pill Bar */}
      <div style={{ display: "flex", gap: "6px", overflowX: "auto", paddingBottom: "4px" }}>
        <button
          className={`pill ${activeChapterFilter === "all" ? "active" : ""}`}
          onClick={() => setActiveChapterFilter("all")}
        >
          All Memories
        </button>
        <button
          className={`pill ${activeChapterFilter === "walking" ? "active" : ""}`}
          onClick={() => setActiveChapterFilter("walking")}
        >
          🚶 First Steps
        </button>
        <button
          className={`pill ${activeChapterFilter === "words" ? "active" : ""}`}
          onClick={() => setActiveChapterFilter("words")}
        >
          🗣️ First Words
        </button>
        <button
          className={`pill ${activeChapterFilter === "baby" ? "active" : ""}`}
          onClick={() => setActiveChapterFilter("baby")}
        >
          🍼 Baby Years
        </button>
      </div>

      {/* Agent 1 Dynamic Prompter Card (Pinned at top) */}
      {!promptReplied ? (
        <section className="agent-prompter-card" aria-label="Agent Prompter">
          <div className="agent-header">
            <div className="agent-avatar">🤖</div>
            <div>
              <span className="card-title">Hi Gaga!</span>
              <p className="caption-meta" style={{ margin: 0 }}>
                Agent 1 (Prompter) • Weekly Cadence
              </p>
            </div>
          </div>

          <div className="agent-bubble">
            "How has {childName}'s walking been this week? Did he explore the garden or find
            something unexpected?"
          </div>

          <div style={{ display: "flex", gap: "8px", flexWrap: "wrap", alignItems: "center" }}>
            <button className={`pill ${isRecording ? "active" : ""}`} onClick={toggleRecord}>
              🎙️ {isRecording ? "Recording... (tap to finish)" : "Voice Note"}
            </button>
            <label className="pill" style={{ cursor: "pointer" }}>
              📷 Add Photo
              <input
                type="file"
                accept="image/*"
                style={{ display: "none" }}
                onChange={(e) => {
                  if (e.target.files?.[0]) {
                    setPhotoSelected(e.target.files[0].name);
                  }
                }}
              />
            </label>
            {photoSelected && (
              <span className="caption-meta" style={{ color: "var(--color-primary)" }}>
                ✓ {photoSelected}
              </span>
            )}
            {isRecording && (
              <span className="badge badge-danger" style={{ animation: "pulse 1s infinite" }}>
                🔴 0:14
              </span>
            )}
          </div>

          <div className="agent-reply-box">
            <input
              placeholder="Type your response or story..."
              value={replyInput}
              onChange={(e) => setReplyInput(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && handleSendReply()}
            />
            <button
              className="btn btn-primary btn-sm"
              onClick={handleSendReply}
              style={{ borderRadius: "20px" }}
            >
              Send
            </button>
          </div>
        </section>
      ) : (
        <div
          className="card-secondary"
          style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}
        >
          <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
            <span>✨</span>
            <span style={{ fontSize: "13px", fontWeight: 500 }}>
              Thanks, Gaga! Your memory was captured and cataloged by Agent 2.
            </span>
          </div>
          <button className="btn btn-secondary btn-sm" onClick={() => setPromptReplied(false)}>
            New Prompt
          </button>
        </div>
      )}

      {/* Memory Feed (Reverse Chronological with Milestone Markers) */}
      <section style={{ display: "flex", flexDirection: "column", gap: "14px" }}>
        {filteredMemories.map((m, index) => {
          const showChapterMarker =
            index === 0 || m.milestoneChapter !== filteredMemories[index - 1].milestoneChapter;

          return (
            <div key={m.id} style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
              {showChapterMarker && m.milestoneChapter && (
                <div className="milestone-marker">
                  <div className="milestone-line"></div>
                  <span className="milestone-tag">🏷️ Chapter: {m.milestoneChapter}</span>
                  <div className="milestone-line"></div>
                </div>
              )}

              <article className="card" aria-label={`Memory by ${m.authorAlias}`}>
                {/* Header: Author + Snapped Alias + Date */}
                <div
                  style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}
                >
                  <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
                    <div
                      style={{
                        width: "36px",
                        height: "36px",
                        borderRadius: "50%",
                        background: "var(--color-surface-variant)",
                        border: "2px solid var(--color-primary)",
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "center",
                        fontSize: "16px",
                        fontWeight: 600,
                        color: "var(--color-primary)",
                      }}
                    >
                      {m.authorAlias[0]}
                    </div>
                    <div>
                      <h4 className="card-title" style={{ margin: 0 }}>
                        {m.authorAlias}{" "}
                        <span
                          style={{
                            fontWeight: 400,
                            color: "var(--color-text-muted)",
                            fontSize: "12px",
                          }}
                        >
                          ({m.authorRelation})
                        </span>
                      </h4>
                      <span className="caption-meta">{m.date}</span>
                    </div>
                  </div>

                  <span className="badge badge-primary">Agent 2 Curated</span>
                </div>

                {/* Inline Voice Note Player with Waveform Indicator */}
                {m.hasAudio && (
                  <div className="audio-player-widget">
                    <button
                      className="btn btn-primary btn-sm"
                      style={{ width: "32px", height: "32px", padding: 0, borderRadius: "50%" }}
                      onClick={() => setPlayingAudioId(playingAudioId === m.id ? null : m.id)}
                      aria-label={playingAudioId === m.id ? "Pause audio" : "Play audio"}
                    >
                      {playingAudioId === m.id ? "⏸" : "▶"}
                    </button>
                    <div className="waveform-bars">
                      {[40, 70, 95, 60, 80, 50, 85, 65, 45, 90, 75, 55, 70, 85, 50].map((h, i) => (
                        <div
                          key={i}
                          className="waveform-bar"
                          style={{
                            height: `${h}%`,
                            opacity: playingAudioId === m.id ? 1 : 0.6,
                            animation:
                              playingAudioId === m.id
                                ? `pulse ${(i % 3) * 0.2 + 0.4}s infinite alternate`
                                : "none",
                          }}
                        />
                      ))}
                    </div>
                    <span className="caption-meta">{m.audioDuration || "0:38"}</span>
                  </div>
                )}

                {/* Memory Transcript / Text block */}
                <p
                  className="body-regular"
                  style={{ margin: "4px 0 0", color: "var(--color-text)" }}
                >
                  "{m.text}"
                </p>

                {/* Footer Metadata: Tags & Chapter */}
                {m.tags && m.tags.length > 0 && (
                  <div style={{ display: "flex", gap: "6px", flexWrap: "wrap", marginTop: "4px" }}>
                    {m.tags.map((tag) => (
                      <span key={tag} className="badge badge-primary" style={{ fontSize: "11px" }}>
                        {tag}
                      </span>
                    ))}
                  </div>
                )}
              </article>
            </div>
          );
        })}
      </section>
    </div>
  );
}
