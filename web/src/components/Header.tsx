import { useTheme } from "../context/useTheme";
import { useNavigation } from "../context/useNavigation";

export function Header() {
  const { theme, toggleTheme } = useTheme();
  const { currentRoute, childId, navigate } = useNavigation();

  const title =
    currentRoute === "chronicle"
      ? `${childId === "maya" ? "Maya" : "Leo"}'s Chronicle`
      : currentRoute === "circle"
        ? "Circle of Care Management"
        : currentRoute === "guardian"
          ? "Guardian Safety & Audit Queue"
          : currentRoute === "welcome"
            ? "Circle of Care"
            : "Circle of Care";

  return (
    <header className="app-header">
      <div className="app-header-content">
        <button
          className="app-brand"
          onClick={() => navigate("/dashboard")}
          aria-label="Go to Dashboard"
        >
          <div className="app-logo-mark">C</div>
          <div>
            <h1 className="title-display" style={{ fontSize: "20px", margin: 0 }}>
              {title}
            </h1>
            <span className="caption-meta">
              {currentRoute === "welcome" ? "Family Memory Vault" : "Smith Family Chronicle"}
            </span>
          </div>
        </button>

        <div className="app-header-actions">
          {/* Quick theme toggle */}
          <button
            className="pill"
            onClick={toggleTheme}
            title={`Switch to ${theme === "light" ? "dark" : "light"} mode`}
            aria-label="Toggle theme"
          >
            {theme === "light" ? "🌙 Dark" : "☀️ Light"}
          </button>

          {/* Guardian Flag Badge */}
          <button
            className="pill pill-amber"
            onClick={() => navigate("/guardian/review")}
            title="1 memory flagged for review"
            aria-label="Guardian review badge"
          >
            <span>🛡️</span>
            <span>1</span>
          </button>
        </div>
      </div>

      {/* Primary Navigation Segmented Pills Bar */}
      <nav className="nav-segmented-bar" aria-label="Main Navigation" style={{ marginTop: "8px" }}>
        <button
          className={`pill ${currentRoute === "dashboard" ? "active" : ""}`}
          onClick={() => navigate("/dashboard")}
        >
          🏠 Dashboard
        </button>
        <button
          className={`pill ${currentRoute === "chronicle" ? "active" : ""}`}
          onClick={() => navigate(`/chronicle/${childId}`)}
        >
          📖 Chronicle
        </button>
        <button
          className={`pill ${currentRoute === "circle" ? "active" : ""}`}
          onClick={() => navigate(`/chronicle/${childId}/circle`)}
        >
          👥 Circle of Care
        </button>
        <button
          className={`pill ${currentRoute === "guardian" ? "active" : ""}`}
          onClick={() => navigate("/guardian/review")}
        >
          🛡️ Guardian Review
        </button>
        <button
          className={`pill ${currentRoute === "invite" ? "active" : ""}`}
          onClick={() => navigate("/invite/claim")}
        >
          ✉️ Claim Invite
        </button>
        <button
          className={`pill ${currentRoute === "welcome" ? "active" : ""}`}
          onClick={() => navigate("/welcome")}
        >
          🌟 Welcome
        </button>
      </nav>
    </header>
  );
}
