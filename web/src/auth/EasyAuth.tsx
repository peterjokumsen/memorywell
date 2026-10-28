import { Ctx } from "./useEasyAuth";

export function EasyAuthProvider({ children }: { children: React.ReactNode }) {
  // In production App Service injects x-ms-client-principal; read via header not available in browser.
  // Keep a placeholder for now.
  return <Ctx.Provider value={null}>{children}</Ctx.Provider>;
}

export { useEasyAuth } from "./useEasyAuth";
