import { render, screen, fireEvent } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { InviteClaimView } from "./InviteClaimView";
import { NavigationProvider } from "../context/NavigationContext";
import { ThemeProvider } from "../context/ThemeContext";

function renderWithProviders(ui: React.ReactElement) {
  return render(
    <ThemeProvider>
      <NavigationProvider>{ui}</NavigationProvider>
    </ThemeProvider>,
  );
}

describe("InviteClaimView", () => {
  it("renders welcome banner and claim steps", () => {
    renderWithProviders(<InviteClaimView />);
    expect(screen.getByText(/You've been invited to Leo's Chronicle/i)).toBeTruthy();
    expect(screen.getByText(/What should Leo call you/i)).toBeTruthy();
    expect(screen.getByText(/How often should Agent 1 prompt you/i)).toBeTruthy();
  });

  it("allows setting alias and cadence", () => {
    renderWithProviders(<InviteClaimView />);
    const aliasInput = screen.getByDisplayValue("Gaga");
    fireEvent.change(aliasInput, { target: { value: "Nana" } });
    expect(screen.getByText(/✓ "Nana" is available/i)).toBeTruthy();

    const monthlyRadio = screen.getByRole("radio", { name: /Monthly Digest/i }) as HTMLInputElement;
    fireEvent.click(monthlyRadio);
    expect(monthlyRadio.checked).toBe(true);
  });
});
