import { render } from "@testing-library/react";
import { describe, it, expect } from "vitest";
import { AliasCadence } from "./AliasCadence";
import { Capture } from "./Capture";
import { Chat } from "./Chat";
import { InviteClaim } from "./InviteClaim";
import { ReviewQueue } from "./ReviewQueue";
import { Timeline } from "./Timeline";

describe("components", () => {
  it("render", () => {
    render(<AliasCadence />);
    render(<Capture />);
    render(<Chat />);
    render(<InviteClaim />);
    render(<ReviewQueue />);
    render(<Timeline />);
    expect(true).toBe(true);
  });
});
