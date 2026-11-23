import { Ctx } from "./useEasyAuth";
import { useEasyAuthState } from "./useEasyAuth";

export function EasyAuthProvider({ children }: { children: React.ReactNode }) {
  const { principal, loading } = useEasyAuthState();
  if (loading) {
    return <div className="app-container">Loading…</div>;
  }
  if (!principal) {
    return (
      <div className="app-container" style={{ padding: "2rem", textAlign: "center" }}>
        <h1 className="title-display">Memorywell</h1>
        <p className="caption-meta">Please sign in to continue.</p>
        <a className="btn btn-primary" href="/.auth/login/aad?post_login_redirect_uri=/">
          Sign in with Microsoft
        </a>
      </div>
    );
  }
  return <Ctx.Provider value={principal}>{children}</Ctx.Provider>;
}

export { useEasyAuth } from "./useEasyAuth";
