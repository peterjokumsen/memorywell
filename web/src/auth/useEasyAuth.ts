import { createContext, useContext } from "react";

export type Principal = { userId: string; userDetails: string } | null;

export const Ctx = createContext<Principal>(null);

export function useEasyAuth() {
  return useContext(Ctx);
}
