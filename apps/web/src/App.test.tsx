import { render, screen, waitFor } from "@testing-library/react";
import App from "./App";

test("renders app", async () => {
  render(<App />);
  await waitFor(() => expect(screen.getByText(/Memorywell|Loading/i)).toBeTruthy());
});
