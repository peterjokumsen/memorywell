import { render, screen, fireEvent } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { CircleManagement } from "./CircleManagement";
import { NavigationProvider } from "../context/NavigationContext";
import { ThemeProvider } from "../context/ThemeContext";

function renderWithProviders(ui: React.ReactElement) {
  return render(
    <ThemeProvider>
      <NavigationProvider>{ui}</NavigationProvider>
    </ThemeProvider>,
  );
}

describe("CircleManagement", () => {
  it("renders active contributor roster", () => {
    renderWithProviders(<CircleManagement />);
    expect(screen.getByText("Circle of Care Management")).toBeTruthy();
    expect(screen.getByText("Active Contributor Roster")).toBeTruthy();
    expect(screen.getByText("Gaga")).toBeTruthy();
  });

  it("allows updating display alias and cadence", () => {
    renderWithProviders(<CircleManagement />);
    const aliasInput = screen.getByDisplayValue("Gaga");
    fireEvent.change(aliasInput, { target: { value: "Grammy" } });
    expect(screen.getAllByText("Grammy").length).toBeGreaterThanOrEqual(1);
  });

  it("generates magic link for invitation", () => {
    renderWithProviders(<CircleManagement />);
    const nameInput = screen.getByPlaceholderText(/Grandma Eleanor/i);
    const relationInput = screen.getByPlaceholderText(/Maternal Grandmother/i);

    fireEvent.change(nameInput, { target: { value: "Uncle Joe" } });
    fireEvent.change(relationInput, { target: { value: "Paternal Uncle" } });

    const genBtn = screen.getByRole("button", { name: /Generate Magic Link/i });
    fireEvent.click(genBtn);

    expect(screen.getByText(/Shareable Invite Link Created/i)).toBeTruthy();
  });
});
