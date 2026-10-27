import { useRef, useState } from "react";

export function Capture() {
  const [photo, setPhoto] = useState<File | null>(null);
  const [recording, setRecording] = useState(false);
  const mediaRef = useRef<MediaRecorder | null>(null);

  async function toggleRecord() {
    if (recording) {
      mediaRef.current?.stop();
      setRecording(false);
      return;
    }
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    const rec = new MediaRecorder(stream);
    mediaRef.current = rec;
    rec.start();
    setRecording(true);
  }

  return (
    <div>
      <h2>Capture</h2>
      <input type="file" accept="image/*" onChange={(e) => setPhoto(e.target.files?.[0] ?? null)} />
      {photo && <p>Selected photo: {photo.name}</p>}
      <button onClick={toggleRecord}>{recording ? "Stop" : "Record"}</button>
    </div>
  );
}
