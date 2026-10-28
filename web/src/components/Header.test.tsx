import { render, screen, fireEvent } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { Header } from "./Header";
import { NavigationProvider } from "../context/NavigationContext";
import { ThemeProvider } from "../context/ThemeContext";

function renderWithProviders(ui: React.ReactElement) {
  return render(
    <ThemeProvider>
      <NavigationProvider>{ui}</NavigationProvider>
    </ThemeProvider>,
  );
}

describe("Header", () => {
  it("renders branding and navigation pills", () => {
    renderWithProviders(<Header />);
    expect(screen.getByRole("heading", { level: 1 }).textContent).toContain("Circle of Care");
    expect(screen.getByRole("button", { name: "🏠 Dashboard" })).toBeTruthy();
    expect(screen.getByRole("button", { name: "📖 Chronicle" })).toBeTruthy();
    expect(screen.getByRole("button", { name: "👥 Circle of Care" })).toBeTruthy();
    expect(screen.getByRole("button", { name: "🛡️ Guardian Review" })).toBeTruthy();
  });

  it("toggles theme", () => {
    renderWithProviders(<Header />);
    const themeBtn = screen.getByLabelText(/Toggle theme/i);
    expect(themeBtn).toBeTruthy();
    fireEvent.click(themeBtn);
  });
});
