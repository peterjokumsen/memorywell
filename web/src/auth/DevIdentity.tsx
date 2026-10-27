import { createContext, useContext, useState } from "react";

type Identity = { householdId: string; userId: string };

const Ctx = createContext<{ identity: Identity; setIdentity: (i: Identity) => void } | null>(null);

export function DevIdentityProvider({ children }: { children: React.ReactNode }) {
  const [identity, setIdentity] = useState<Identity>({ householdId: "hh-dev", userId: "user-dev" });
  return <Ctx.Provider value={{ identity, setIdentity }}>{children}</Ctx.Provider>;
}

export function useDevIdentity() {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error("DevIdentityProvider missing");
  return ctx;
}
