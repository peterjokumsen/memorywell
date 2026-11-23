import { useState } from "react";

export function Chat() {
  const [messages, setMessages] = useState<string[]>([]);
  const [input, setInput] = useState("");

  function send() {
    if (!input.trim()) return;
    setMessages((m) => [...m, input.trim()]);
    setInput("");
  }

  return (
    <div className="card" style={{ gap: "10px" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <h2 className="section-heading">Chat</h2>
        <span className="badge badge-primary">Agent 1 Prompter</span>
      </div>
      <ul
        style={{
          listStyle: "none",
          padding: 0,
          margin: 0,
          display: "flex",
          flexDirection: "column",
          gap: "6px",
        }}
      >
        {messages.map((m, i) => (
          <li
            key={i}
            style={{
              background: "var(--color-surface-variant)",
              padding: "8px 12px",
              borderRadius: "12px",
              fontSize: "13px",
            }}
          >
            {m}
          </li>
        ))}
      </ul>
      <div style={{ display: "flex", gap: "8px" }}>
        <input
          className="input-capsule"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="Type message..."
          onKeyDown={(e) => e.key === "Enter" && send()}
        />
        <button className="btn btn-primary" onClick={send}>
          Send
        </button>
      </div>
    </div>
  );
}
