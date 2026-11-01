import { useState } from "react";
import { useNavigation } from "../context/useNavigation";
import { useEasyAuth } from "../auth/useEasyAuth";
import { createHousehold, createChronicle, createContributor } from "../api/admin";

export function Administration() {
  const { childId, navigate } = useNavigation();
  const principal = useEasyAuth();
  const [householdName, setHouseholdName] = useState("");
  const [householdId, setHouseholdId] = useState("hh-dev");
  const [chronicleName, setChronicleName] = useState("");
  const [contributorName, setContributorName] = useState("");
  const [relation, setRelation] = useState("");
  const [message, setMessage] = useState("");

  const isAdmin = true; // TODO: gate by household role once identity exposes roles

  if (!isAdmin) {
    return (
      <div className="card" style={{ margin: "2rem" }}>
        <h2>Not authorized</h2>
        <p className="caption-meta">You do not have permission to administer households.</p>
        <button className="btn btn-primary" onClick={() => navigate("/dashboard")}>
          Back to Dashboard
        </button>
      </div>
    );
  }

  const handleHousehold = async (e: React.SubmitEvent) => {
    e.preventDefault();
    try {
      await createHousehold(householdName);
      setMessage(`Household "${householdName}" created.`);
      setHouseholdName("");
    } catch {
      setMessage("Failed to create household.");
    }
  };

  const handleChronicle = async (e: React.SubmitEvent) => {
    e.preventDefault();
    try {
      await createChronicle(householdId, chronicleName);
      setMessage(`Chronicle "${chronicleName}" added.`);
      setChronicleName("");
    } catch {
      setMessage("Failed to add chronicle.");
    }
  };

  const handleContributor = async (e: React.SubmitEvent) => {
    e.preventDefault();
    try {
      await createContributor(householdId, {
        name: contributorName,
        canonicalRelation: relation,
        role: "Full Contributor",
      });
      setMessage(`Contributor "${contributorName}" added.`);
      setContributorName("");
      setRelation("");
    } catch {
      setMessage("Failed to add contributor.");
    }
  };

  return (
    <div
      className="administration"
      style={{ display: "flex", flexDirection: "column", gap: "18px" }}
    >
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <button className="pill" onClick={() => navigate(`/chronicle/${childId}`)}>
          ← Chronicle
        </button>
        <h2 className="title-display" style={{ fontSize: "18px", margin: 0 }}>
          Administration
        </h2>
      </div>

      {message && <div className="card-secondary">{message}</div>}

      <section className="card">
        <h3 className="section-heading">Create Household</h3>
        <form onSubmit={handleHousehold} style={{ display: "flex", gap: "8px" }}>
          <input
            className="input-capsule"
            value={householdName}
            onChange={(e) => setHouseholdName(e.target.value)}
            placeholder="Household name"
          />
          <button className="btn btn-primary" type="submit">
            Create
          </button>
        </form>
      </section>

      <section className="card">
        <h3 className="section-heading">Add Chronicle</h3>
        <form onSubmit={handleChronicle} style={{ display: "flex", gap: "8px" }}>
          <input
            className="input-capsule"
            value={householdId}
            onChange={(e) => setHouseholdId(e.target.value)}
            placeholder="Household ID"
          />
          <input
            className="input-capsule"
            value={chronicleName}
            onChange={(e) => setChronicleName(e.target.value)}
            placeholder="Chronicle name"
          />
          <button className="btn btn-primary" type="submit">
            Add
          </button>
        </form>
      </section>

      <section className="card">
        <h3 className="section-heading">Add Contributor</h3>
        <form
          onSubmit={handleContributor}
          style={{ display: "flex", flexDirection: "column", gap: "8px" }}
        >
          <input
            className="input-capsule"
            value={contributorName}
            onChange={(e) => setContributorName(e.target.value)}
            placeholder="Name"
          />
          <input
            className="input-capsule"
            value={relation}
            onChange={(e) => setRelation(e.target.value)}
            placeholder="Canonical relation"
          />
          <button className="btn btn-primary" type="submit">
            Add
          </button>
        </form>
      </section>
    </div>
  );
}
