import { render, screen, fireEvent } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { LandingPage } from "./LandingPage";
import { NavigationProvider } from "../context/NavigationContext";
import { ThemeProvider } from "../context/ThemeContext";

function renderWithProviders(ui: React.ReactElement) {
  return render(
    <ThemeProvider>
      <NavigationProvider>{ui}</NavigationProvider>
    </ThemeProvider>,
  );
}

describe("LandingPage", () => {
  it("renders hero headline and CTAs", () => {
    renderWithProviders(<LandingPage />);
    expect(screen.getByText(/Capture childhood before it fades/i)).toBeTruthy();
    expect(screen.getByRole("button", { name: /Start Household Chronicle/i })).toBeTruthy();
    expect(screen.getByRole("button", { name: /Have an Invite Link/i })).toBeTruthy();
  });

  it("switches theme mode preview", () => {
    renderWithProviders(<LandingPage />);
    const darkBtn = screen.getByRole("button", { name: /Dark Mode/i });
    fireEvent.click(darkBtn);
    expect(darkBtn.className).toContain("active");
  });

  it("switches agent tabs in interactive showcase", () => {
    renderWithProviders(<LandingPage />);
    const curatorTab = screen.getByRole("button", { name: /Agent 2: Curator/i });
    fireEvent.click(curatorTab);
    expect(screen.getByText(/Agent 2: Curator & Memory Keeper/i)).toBeTruthy();

    const guardianTab = screen.getByRole("button", { name: /Agent 3: Guardian/i });
    fireEvent.click(guardianTab);
    expect(screen.getByText(/Agent 3: Guardian & Safety Reviewer/i)).toBeTruthy();
  });
});
