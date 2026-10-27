import { useState } from "react";

export function ReviewQueue() {
  const [items, setItems] = useState(["Flagged memory #1"]);

  function resolve(index: number) {
    setItems((prev) => prev.filter((_, i) => i !== index));
  }

  return (
    <div>
      <h2>Owner review queue</h2>
      <ul>
        {items.map((item, i) => (
          <li key={i}>
            {item} <button onClick={() => resolve(i)}>Resolve</button>
          </li>
        ))}
      </ul>
    </div>
  );
}
