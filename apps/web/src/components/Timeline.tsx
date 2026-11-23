export function Timeline() {
  const items = [
    { id: 1, label: "Baby Years", thread: "Granny" },
    { id: 2, label: "First words", thread: "Granny" },
  ];

  return (
    <div className="card" style={{ gap: "10px" }}>
      <h2 className="section-heading">Timeline</h2>
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
        {items.map((i) => (
          <li
            key={i.id}
            style={{
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
              padding: "10px 12px",
              background: "var(--color-surface-variant)",
              borderRadius: "12px",
            }}
          >
            <span style={{ fontWeight: 600 }}>{i.label}</span>
            <span className="caption-meta">Thread: {i.thread}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}
