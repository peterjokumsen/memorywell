import { render } from "@testing-library/react";
import { describe, it } from "vitest";
import { ReviewQueue } from "./ReviewQueue";

describe("ReviewQueue", () => {
  it("renders", () => {
    render(<ReviewQueue />);
  });
});
