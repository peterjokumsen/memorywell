import { createContext, useContext } from "react";

export type Identity = { householdId: string; userId: string };

export const Ctx = createContext<{ identity: Identity; setIdentity: (i: Identity) => void } | null>(
  null,
);

export function useDevIdentity() {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error("DevIdentityProvider missing");
  return ctx;
}
