export type Role = "Owner" | "Full Contributor" | "Observer" | "Recipient";

export type Cadence = "none" | "special-occasions" | "monthly" | "weekly";

export interface Contributor {
  id: string;
  name: string;
  canonicalRelation: string;
  displayAlias: string;
  role: Role;
  cadence: Cadence;
  avatar?: string;
}

export interface Memory {
  id: string;
  chronicleId: string;
  authorName: string;
  authorAlias: string;
  authorRelation: string;
  date: string;
  text: string;
  audioDuration?: string;
  hasAudio?: boolean;
  photoUrl?: string;
  tags?: string[];
  milestoneChapter?: string;
  flagged?: boolean;
}

export interface ChildChronicle {
  id: string;
  name: string;
  age: string;
  avatar: string;
  memoryCount: number;
  lastActivity: string;
}

export interface ReviewFlag {
  id: string;
  type: "memory" | "alias";
  reason: string;
  score: number; // e.g. 0.92
  authorAlias: string;
  contentPreview: string;
  requestedAlias?: string;
  status: "pending" | "approved" | "hidden" | "dismissed";
  timestamp: string;
}

export interface AuditEntry {
  id: string;
  timestamp: string;
  actor: string;
  action: string;
  target: string;
  details: string;
}
