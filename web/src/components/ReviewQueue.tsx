import { useState } from "react";

export function ReviewQueue() {
  const [items, setItems] = useState(["Flagged memory #1"]);

  function resolve(index: number) {
    setItems((prev) => prev.filter((_, i) => i !== index));
  }

  return (
    <div className="card" style={{ gap: "10px" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <h2 className="section-heading">Owner review queue</h2>
        <span className="badge badge-milestone">{items.length} Pending</span>
      </div>
      <ul
        style={{
          listStyle: "none",
          padding: 0,
          margin: 0,
          display: "flex",
          flexDirection: "column",
          gap: "8px",
        }}
      >
        {items.map((item, i) => (
          <li
            key={i}
            style={{
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
              padding: "10px 12px",
              background: "var(--color-surface-variant)",
              borderRadius: "12px",
            }}
          >
            <span style={{ fontSize: "13px", fontWeight: 500 }}>{item}</span>
            <button className="btn btn-primary btn-sm" onClick={() => resolve(i)}>
              Resolve
            </button>
          </li>
        ))}
        {items.length === 0 && (
          <li className="caption-meta" style={{ padding: "8px 0" }}>
            All items resolved.
          </li>
        )}
      </ul>
    </div>
  );
}
