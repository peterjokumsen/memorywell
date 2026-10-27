import { render } from "@testing-library/react";
import { describe, it } from "vitest";
import { InviteClaim } from "./InviteClaim";

describe("InviteClaim", () => {
  it("renders", () => {
    render(<InviteClaim />);
  });
});
