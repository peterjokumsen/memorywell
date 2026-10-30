import { createContext, useContext, useEffect, useState } from "react";

export type Principal = { userId: string; userDetails: string } | null;

export const Ctx = createContext<Principal>(null);

export function useEasyAuth() {
  return useContext(Ctx);
}

export function useEasyAuthState() {
  const [principal, setPrincipal] = useState<Principal>(null);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    let cancelled = false;
    fetch("/.auth/me", { credentials: "include" })
      .then((r) => (r.ok ? r.json() : null))
      .then((data) => {
        if (cancelled) return;
        const clientPrincipal = data?.clientPrincipal;
        if (clientPrincipal) {
          setPrincipal({
            userId: clientPrincipal.userId,
            userDetails: clientPrincipal.userDetails ?? clientPrincipal.userId,
          });
        } else {
          setPrincipal(null);
        }
      })
      .catch(() => {
        if (!cancelled) setPrincipal(null);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);
  return { principal, loading };
}
