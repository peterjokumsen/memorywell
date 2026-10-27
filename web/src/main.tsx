import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import App from "./App.tsx";
import { DevIdentityProvider } from "./auth/DevIdentity.tsx";
import "./index.css";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <DevIdentityProvider>
      <App />
    </DevIdentityProvider>
  </StrictMode>,
);
