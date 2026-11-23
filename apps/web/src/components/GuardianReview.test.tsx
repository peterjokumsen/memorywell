import { render, screen, fireEvent } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { GuardianReview } from "./GuardianReview";
import { NavigationProvider } from "../context/NavigationContext";
import { ThemeProvider } from "../context/ThemeContext";

function renderWithProviders(ui: React.ReactElement) {
  return render(
    <ThemeProvider>
      <NavigationProvider>{ui}</NavigationProvider>
    </ThemeProvider>,
  );
}

describe("GuardianReview", () => {
  it("renders pending flags and confidence scores", () => {
    renderWithProviders(<GuardianReview />);
    expect(screen.getByText("Guardian Safety & Audit Queue")).toBeTruthy();
    expect(screen.getByText(/Potential duplicate memory detected/i)).toBeTruthy();
    expect(screen.getByText(/Confidence: 92%/i)).toBeTruthy();
  });

  it("resolves flag on approve and records in audit log", () => {
    renderWithProviders(<GuardianReview />);
    const approveButtons = screen.getAllByRole("button", { name: /Approve/i });
    fireEvent.click(approveButtons[0]);

    expect(screen.getByText(/guardian\.approved/i)).toBeTruthy();
  });

  it("filters flags by type", () => {
    renderWithProviders(<GuardianReview />);
    const aliasFilter = screen.getByRole("button", { name: /Alias Requests/i });
    fireEvent.click(aliasFilter);

    expect(screen.getByText(/Requested alias change validation/i)).toBeTruthy();
  });
});
