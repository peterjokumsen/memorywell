import { render } from "@testing-library/react";
import { describe, it } from "vitest";
import { Timeline } from "./Timeline";

describe("Timeline", () => {
  it("renders", () => {
    render(<Timeline />);
  });
});
