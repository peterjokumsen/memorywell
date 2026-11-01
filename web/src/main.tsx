import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import App from "./App.tsx";
import { DevIdentityProvider } from "./auth/DevIdentity.tsx";
import { EasyAuthProvider } from "./auth/EasyAuth.tsx";
import "./index.css";

async function bootstrap() {
  try {
    const res = await fetch("/config.json");
    if (res.ok) (window as any).__APP_CONFIG = await res.json();
  } catch {
    // ignore
  }
  createRoot(document.getElementById("root")!).render(
    <StrictMode>
      <EasyAuthProvider>
        <DevIdentityProvider>
          <App />
        </DevIdentityProvider>
      </EasyAuthProvider>
    </StrictMode>,
  );
}

bootstrap();
