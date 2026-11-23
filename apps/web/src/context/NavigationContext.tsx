import { useEffect, useState } from "react";
import { NavigationContext, parsePath } from "./useNavigation";

export function NavigationProvider({ children }: { children: React.ReactNode }) {
  const [currentPath, setCurrentPath] = useState<string>(() => {
    if (
      typeof window !== "undefined" &&
      window.location.pathname &&
      window.location.pathname !== "/"
    ) {
      return window.location.pathname + window.location.search;
    }
    return "/dashboard";
  });

  const [childId, setChildId] = useState<string>("leo");
  const [inviteToken, setInviteToken] = useState<string>(() => {
    if (typeof window !== "undefined") {
      return new URLSearchParams(window.location.search).get("token") || "";
    }
    return "";
  });

  useEffect(() => {
    if (typeof window !== "undefined") {
      const onPopState = () => {
        const path = window.location.pathname + window.location.search;
        setCurrentPath(path);
        const { childId: parsedChild } = parsePath(window.location.pathname);
        if (parsedChild) setChildId(parsedChild);
        const t = new URLSearchParams(window.location.search).get("token") || "";
        if (t) setInviteToken(t);
      };

      window.addEventListener("popstate", onPopState);
      return () => window.removeEventListener("popstate", onPopState);
    }
  }, []);

  const navigate = (path: string) => {
    setCurrentPath(path);
    const { childId: parsedChild } = parsePath(path);
    if (parsedChild) setChildId(parsedChild);

    if (typeof window !== "undefined") {
      try {
        const url = new URL(path, window.location.origin);
        const token = url.searchParams.get("token") || "";
        if (token) setInviteToken(token);
        window.history.pushState({}, "", path);
      } catch {
        // Fallback for relative or test environments
      }
    }
  };

  const { route } = parsePath(currentPath);

  return (
    <NavigationContext.Provider
      value={{
        currentRoute: route,
        currentPath,
        childId,
        inviteToken,
        navigate,
        setChildId,
      }}
    >
      {children}
    </NavigationContext.Provider>
  );
}
