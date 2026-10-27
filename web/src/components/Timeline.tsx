export function Timeline() {
  const items = [
    { id: 1, label: "Baby Years", thread: "Granny" },
    { id: 2, label: "First words", thread: "Granny" },
  ];

  return (
    <div>
      <h2>Timeline</h2>
      <ul>
        {items.map((i) => (
          <li key={i.id}>
            {i.label} — {i.thread}
          </li>
        ))}
      </ul>
    </div>
  );
}
