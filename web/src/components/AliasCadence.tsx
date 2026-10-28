import { useState } from "react";

export function AliasCadence() {
  const [alias, setAlias] = useState("");
  const [cadence, setCadence] = useState("monthly");

  return (
    <div className="card" style={{ gap: "12px" }}>
      <h2 className="section-heading">Contributor settings</h2>
      <label
        style={{
          display: "flex",
          flexDirection: "column",
          gap: "4px",
          fontSize: "13px",
          fontWeight: 600,
        }}
      >
        Display alias
        <input
          className="input-capsule"
          value={alias}
          onChange={(e) => setAlias(e.target.value)}
          placeholder="e.g. Gaga"
        />
      </label>
      <label
        style={{
          display: "flex",
          flexDirection: "column",
          gap: "4px",
          fontSize: "13px",
          fontWeight: 600,
        }}
      >
        Cadence
        <select
          className="input-capsule"
          value={cadence}
          onChange={(e) => setCadence(e.target.value)}
        >
          <option value="none">none</option>
          <option value="special-occasions">special-occasions</option>
          <option value="monthly">monthly</option>
          <option value="weekly">weekly</option>
        </select>
      </label>
    </div>
  );
}
