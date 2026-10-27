import { useState } from "react";

export function AliasCadence() {
  const [alias, setAlias] = useState("");
  const [cadence, setCadence] = useState("monthly");

  return (
    <div>
      <h2>Contributor settings</h2>
      <label>
        Display alias
        <input value={alias} onChange={(e) => setAlias(e.target.value)} />
      </label>
      <label>
        Cadence
        <select value={cadence} onChange={(e) => setCadence(e.target.value)}>
          <option value="none">none</option>
          <option value="special-occasions">special-occasions</option>
          <option value="monthly">monthly</option>
          <option value="weekly">weekly</option>
        </select>
      </label>
    </div>
  );
}
