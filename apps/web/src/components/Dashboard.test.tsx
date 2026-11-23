import { render, screen, fireEvent } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { Dashboard } from "./Dashboard";
import { NavigationProvider } from "../context/NavigationContext";
import { ThemeProvider } from "../context/ThemeContext";

function renderWithProviders(ui: React.ReactElement) {
  return render(
    <ThemeProvider>
      <NavigationProvider>{ui}</NavigationProvider>
    </ThemeProvider>,
  );
}

describe("Dashboard", () => {
  it("renders children chronicles and circle of care", () => {
    renderWithProviders(<Dashboard />);
    expect(screen.getByText("Our Children's Chronicles")).toBeTruthy();
    expect(screen.getAllByText("Leo").length).toBeGreaterThanOrEqual(1);
    expect(screen.getByText("Maya")).toBeTruthy();
    expect(screen.getByText("Circle of Care")).toBeTruthy();
  });

  it("handles approving guardian banner flag", () => {
    renderWithProviders(<Dashboard />);
    expect(screen.getByText(/1 Item Requiring Review/i)).toBeTruthy();
    const approveBtn = screen.getByRole("button", { name: /Approve/i });
    fireEvent.click(approveBtn);
    expect(screen.getByText(/Guardian review queue is clear/i)).toBeTruthy();
  });
});
