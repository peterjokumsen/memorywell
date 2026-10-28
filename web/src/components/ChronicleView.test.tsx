import { render, screen, fireEvent } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { ChronicleView } from "./ChronicleView";
import { NavigationProvider } from "../context/NavigationContext";
import { ThemeProvider } from "../context/ThemeContext";

function renderWithProviders(ui: React.ReactElement) {
  return render(
    <ThemeProvider>
      <NavigationProvider>{ui}</NavigationProvider>
    </ThemeProvider>,
  );
}

describe("ChronicleView", () => {
  it("renders chronicle header and Agent 1 Prompter card", () => {
    renderWithProviders(<ChronicleView />);
    expect(screen.getByText(/Leo's Chronicle/i)).toBeTruthy();
    expect(screen.getByText("Hi Gaga!")).toBeTruthy();
    expect(screen.getByText(/Agent 1 \(Prompter\)/i)).toBeTruthy();
    expect(screen.getByPlaceholderText(/Type your response/i)).toBeTruthy();
  });

  it("submits prompt reply and adds to feed", () => {
    renderWithProviders(<ChronicleView />);
    const input = screen.getByPlaceholderText(/Type your response/i);
    fireEvent.change(input, { target: { value: "He built a giant wooden block tower!" } });

    const sendBtn = screen.getByRole("button", { name: "Send" });
    fireEvent.click(sendBtn);

    expect(screen.getByText(/Thanks, Gaga!/i)).toBeTruthy();
    expect(screen.getByText(/"He built a giant wooden block tower!"/i)).toBeTruthy();
  });

  it("filters memories by chapter", () => {
    renderWithProviders(<ChronicleView />);
    const babyFilter = screen.getByRole("button", { name: /Baby Years/i });
    fireEvent.click(babyFilter);
    expect(screen.getByText(/knitted bear his grandfather made/i)).toBeTruthy();
  });
});
