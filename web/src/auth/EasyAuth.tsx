import { createContext, useContext } from "react";

type Principal = { userId: string; userDetails: string } | null;

const Ctx = createContext<Principal>(null);

export function EasyAuthProvider({ children }: { children: React.ReactNode }) {
  // In production App Service injects x-ms-client-principal; read via header not available in browser.
  // Keep a placeholder for now.
  return <Ctx.Provider value={null}>{children}</Ctx.Provider>;
}

export function useEasyAuth() {
  return useContext(Ctx);
}
