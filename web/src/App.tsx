import { AliasCadence } from "./components/AliasCadence";
import { Chat } from "./components/Chat";
import { InviteClaim } from "./components/InviteClaim";
import "./App.css";

function App() {
  return (
    <main>
      <h1>Memorywell</h1>
      <InviteClaim />
      <AliasCadence />
      <Chat />
    </main>
  );
}

export default App;
