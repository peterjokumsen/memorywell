import { render } from "@testing-library/react";
import { describe, it } from "vitest";
import { Capture } from "./Capture";

describe("Capture", () => {
  it("renders", () => {
    render(<Capture />);
  });
});
