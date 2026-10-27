import { render } from "@testing-library/react";
import { describe, it } from "vitest";
import { Chat } from "./Chat";

describe("Chat", () => {
  it("renders", () => {
    render(<Chat />);
  });
});
