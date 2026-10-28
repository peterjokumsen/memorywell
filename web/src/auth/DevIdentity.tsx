import { useState } from "react";
import { Ctx, type Identity } from "./useDevIdentity";

export function DevIdentityProvider({ children }: { children: React.ReactNode }) {
  const [identity, setIdentity] = useState<Identity>({ householdId: "hh-dev", userId: "user-dev" });
  return <Ctx.Provider value={{ identity, setIdentity }}>{children}</Ctx.Provider>;
}

export { useDevIdentity } from "./useDevIdentity";
