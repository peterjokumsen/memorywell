import { AliasCadence } from "./components/AliasCadence";
import { Capture } from "./components/Capture";
import { Chat } from "./components/Chat";
import { InviteClaim } from "./components/InviteClaim";
import { ReviewQueue } from "./components/ReviewQueue";
import { Timeline } from "./components/Timeline";
import "./App.css";

function App() {
  return (
    <main>
      <h1>Memorywell</h1>
      <InviteClaim />
      <AliasCadence />
      <Chat />
      <Capture />
      <Timeline />
      <ReviewQueue />
    </main>
  );
}

export default App;
