import { createContext, useContext } from "react";

export type AppRoute = "welcome" | "dashboard" | "chronicle" | "circle" | "guardian" | "invite";

export interface NavigationContextValue {
  currentRoute: AppRoute;
  currentPath: string;
  childId: string;
  inviteToken: string;
  navigate: (path: string) => void;
  setChildId: (id: string) => void;
}

export function parsePath(pathname: string): { route: AppRoute; childId: string } {
  if (pathname.startsWith("/welcome")) {
    return { route: "welcome", childId: "leo" };
  }
  if (pathname.startsWith("/invite/claim")) {
    return { route: "invite", childId: "leo" };
  }
  if (pathname.startsWith("/guardian/review") || pathname.startsWith("/guardian")) {
    return { route: "guardian", childId: "leo" };
  }
  if (pathname.includes("/circle")) {
    const parts = pathname.split("/");
    const id = parts[2] || "leo";
    return { route: "circle", childId: id };
  }
  if (pathname.startsWith("/chronicle")) {
    const parts = pathname.split("/");
    const id = parts[2] || "leo";
    return { route: "chronicle", childId: id };
  }
  return { route: "dashboard", childId: "leo" };
}

export const NavigationContext = createContext<NavigationContextValue>({
  currentRoute: "dashboard",
  currentPath: "/dashboard",
  childId: "leo",
  inviteToken: "",
  navigate: () => {},
  setChildId: () => {},
});

export function useNavigation() {
  return useContext(NavigationContext);
}
