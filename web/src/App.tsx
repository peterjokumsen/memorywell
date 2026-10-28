import { Header } from "./components/Header";
import { LandingPage } from "./components/LandingPage";
import { Dashboard } from "./components/Dashboard";
import { ChronicleView } from "./components/ChronicleView";
import { CircleManagement } from "./components/CircleManagement";
import { GuardianReview } from "./components/GuardianReview";
import { InviteClaimView } from "./components/InviteClaimView";
import { ThemeProvider } from "./context/ThemeContext";
import { NavigationProvider } from "./context/NavigationContext";
import { useNavigation } from "./context/useNavigation";
import "./App.css";

function MainContent() {
  const { currentRoute } = useNavigation();

  return (
    <div className="app-container">
      <Header />
      <main className="app-shell" role="main">
        {currentRoute === "welcome" && <LandingPage />}
        {currentRoute === "dashboard" && <Dashboard />}
        {currentRoute === "chronicle" && <ChronicleView />}
        {currentRoute === "circle" && <CircleManagement />}
        {currentRoute === "guardian" && <GuardianReview />}
        {currentRoute === "invite" && <InviteClaimView />}
      </main>
    </div>
  );
}

function App() {
  return (
    <ThemeProvider>
      <NavigationProvider>
        <MainContent />
      </NavigationProvider>
    </ThemeProvider>
  );
}

export default App;
