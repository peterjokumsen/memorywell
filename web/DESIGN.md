# Web design

## Design System & Visual Architecture

### 1. Layout Structure & Grid

- **Container Width**: Mobile-first portrait layout (390px to 430px base viewport width) with safe-area top/bottom padding for dynamic island / notch displays.
- **Layout Hierarchy**:
  - **Header Bar**: Top bar housing app title (`Circle of Care` / `{Child}'s Chronicle`), navigation context, and profile/notification badges.
  - **Tab Navigation Sub-header**: Segmented pills (`Timeline`, `Contributors`, `Chapters`) pinned beneath the primary header.
  - **Primary Content Stream**: Single-column vertical scroll container with a **16px** horizontal edge padding.
  - **Card Stacking**: Direct visual separation between conversational agent prompt cards, memory timeline items, and owner queue actions via consistent **12px–16px** vertical grid gaps.

---

### 2. Color Palette & Dark Mode Strategy

| Palette Role          | Light Mode Value                    | Dark Mode Value                  | Usage / Context                        |
| :-------------------- | :---------------------------------- | :------------------------------- | :------------------------------------- |
| **App Background**    | `#F4F3EE` (Warm Off-White)          | `#121413` (Deep Charcoal)        | Main viewport canvas background        |
| **Surface Base**      | `#FFFFFF` (Pure White)              | `#1C1F1D` (Dark Olive-Slate)     | Cards, modals, containers              |
| **Surface Secondary** | `#EBE8DF` (Muted Warm Gray)         | `#262A27` (Elevated Card Base)   | Secondary containers, input surfaces   |
| **Primary Accent**    | `#4A6048` (Deep Sage Green)         | `#7CA17A` (Luminous Sage)        | Headers, primary buttons, active tabs  |
| **Secondary Accent**  | `#869784` (Soft Muted Sage)         | `#3D493C` (Subdued Olive)        | Secondary buttons, pill filters        |
| **Milestone Accent**  | `#B86B43` (Terracotta / Warm Amber) | `#D18057` (Warm Amber Accent)    | Special occasion tags, chapter headers |
| **Text Primary**      | `#1C201D` (Dark Charcoal)           | `#EAECE8` (Soft Parchment White) | Main titles, user input, body text     |
| **Text Muted**        | `#666E65` (Olive Gray)              | `#9CA39B` (Sage Gray)            | Timestamps, metadata, relation labels  |
| **Border / Divider**  | `#DCD8CD` (Light Sand)              | `#2E332F` (Dark Slate Border)    | Card outlines, horizontal dividers     |

---

### 3. Typography Hierarchy

- **Font Family**: System Sans-Serif (`SF Pro Text` / `Inter` / `Roboto`) with serif display options (`Georgia` / `New York`) for brand title.
- **Scale**:
  - **Display Header**: `22px` / Line Height `28px` / Bold — App bar title (`Circle of Care`).
  - **Section Heading**: `18px` / Line Height `24px` / SemiBold — Section titles (`Our Children's Chronicles`, `Agent Guardian Review Queue`).
  - **Card Title**: `15px` / Line Height `20px` / SemiBold — Contributor name & relation (`Gaga (Grandmother)`).
  - **Body Text**: `14px` / Line Height `20px` / Regular — Prompt cards, transcribed memory snippets, user replies.
  - **Caption & Metadata**: `12px` / Line Height `16px` / Medium — Dates, tags, audio duration indicators.

---

### 4. Spacing & Radius Scale

- **Base Unit**: `4px` grid scale
- **Spacing Scale**:
  - `xs` (4px), `sm` (8px), `md` (12px), `lg` (16px), `xl` (24px)
- **Corner Radius**:
  - **Cards & Containers**: `16px` (`rounded-2xl`) for a soft, warm aesthetic.
  - **Buttons & Pills**: `20px` (`rounded-full`) for interactive tags and call-to-actions.
  - **Input Bars**: `24px` rounded capsule edges.

---

### 5. Key Component Structures

1. **Agent 1 Prompter Card**: Card with an agent bot avatar, current contributor alias greeting (`Hi Gaga!`), text box, action pills (`Voice Note`, `Add Photo`), and text response input bar with send button.
2. **Agent 2 Memory Timeline Card**: Author avatar + alias header, playable voice note widget with audio waveform indicator, transcribed text block, photo preview, and footer metadata (Date + Topic tag).
3. **Agent 3 Guardian Review Queue Card**: Badge notification header (`1 flagged item`), card detailing the rationale (`Review duplicate/unclear memory`), and action buttons (`Approve`, `Edit / Hide`).

---

### Design Tokens Export (W3C DTCG Format)

```json
{
  "color": {
    "primitive": {
      "sage": {
        "100": { "$value": "#EAEFEA", "$type": "color" },
        "300": { "$value": "#A8BBA6", "$type": "color" },
        "500": { "$value": "#7CA17A", "$type": "color" },
        "700": { "$value": "#4A6048", "$type": "color" },
        "900": { "$value": "#243123", "$type": "color" }
      },
      "amber": {
        "400": { "$value": "#D18057", "$type": "color" },
        "600": { "$value": "#B86B43", "$type": "color" }
      },
      "neutral": {
        "0": { "$value": "#FFFFFF", "$type": "color" },
        "50": { "$value": "#F4F3EE", "$type": "color" },
        "100": { "$value": "#EBE8DF", "$type": "color" },
        "200": { "$value": "#DCD8CD", "$type": "color" },
        "700": { "$value": "#2E332F", "$type": "color" },
        "800": { "$value": "#1C1F1D", "$type": "color" },
        "900": { "$value": "#121413", "$type": "color" }
      }
    },
    "theme": {
      "light": {
        "background": { "$value": "{color.primitive.neutral.50}", "$type": "color" },
        "surface": { "$value": "{color.primitive.neutral.0}", "$type": "color" },
        "surfaceVariant": { "$value": "{color.primitive.neutral.100}", "$type": "color" },
        "primary": { "$value": "{color.primitive.sage.700}", "$type": "color" },
        "textPrimary": { "$value": "{color.primitive.neutral.800}", "$type": "color" },
        "textMuted": { "$value": "#666E65", "$type": "color" },
        "border": { "$value": "{color.primitive.neutral.200}", "$type": "color" },
        "milestone": { "$value": "{color.primitive.amber.600}", "$type": "color" }
      },
      "dark": {
        "background": { "$value": "{color.primitive.neutral.900}", "$type": "color" },
        "surface": { "$value": "{color.primitive.neutral.800}", "$type": "color" },
        "surfaceVariant": { "$value": "#262A27", "$type": "color" },
        "primary": { "$value": "{color.primitive.sage.500}", "$type": "color" },
        "textPrimary": { "$value": "#EAECE8", "$type": "color" },
        "textMuted": { "$value": "#9CA39B", "$type": "color" },
        "border": { "$value": "{color.primitive.neutral.700}", "$type": "color" },
        "milestone": { "$value": "{color.primitive.amber.400}", "$type": "color" }
      }
    }
  },
  "dimension": {
    "spacing": {
      "xs": { "$value": "4px", "$type": "dimension" },
      "sm": { "$value": "8px", "$type": "dimension" },
      "md": { "$value": "12px", "$type": "dimension" },
      "lg": { "$value": "16px", "$type": "dimension" },
      "xl": { "$value": "24px", "$type": "dimension" }
    },
    "borderRadius": {
      "card": { "$value": "16px", "$type": "dimension" },
      "pill": { "$value": "20px", "$type": "dimension" },
      "input": { "$value": "24px", "$type": "dimension" }
    }
  },
  "typography": {
    "titleDisplay": {
      "$value": {
        "fontFamily": "Georgia, serif",
        "fontSize": "22px",
        "fontWeight": "700",
        "lineHeight": "28px"
      },
      "$type": "typography"
    },
    "headingSection": {
      "$value": {
        "fontFamily": "SF Pro Text, -apple-system, sans-serif",
        "fontSize": "18px",
        "fontWeight": "600",
        "lineHeight": "24px"
      },
      "$type": "typography"
    },
    "bodyRegular": {
      "$value": {
        "fontFamily": "SF Pro Text, -apple-system, sans-serif",
        "fontSize": "14px",
        "fontWeight": "400",
        "lineHeight": "20px"
      },
      "$type": "typography"
    }
  }
}
```

## Unauthenticated Landing Page Specification (`/welcome`)

The landing page for unauthenticated visitors serves two primary user journeys:

1. **Prospective Household Owners**: Parents seeking a meaningful, structured way to capture family memories and involve extended family without friction.
2. **Invited Contributors with an Invite Token**: Grandparents or relatives who received a link via WhatsApp or iMessage and need to claim their display alias and contribute.

---

### 1. Page Visual Layout Diagram

```plaintext
┌────────────────────────────────────────────────────────────────────────────┐
│ Header: Logo ("Circle of Care")                 [ Claim Code ]  [ Sign In ]│
├────────────────────────────────────────────────────────────────────────────┤
│ HERO SECTION                                                               │
│  ├── Headline: "Preserve every milestone, together."                       │
│  ├── Subheadline: Frictionless family memory capsules guided by AI.        │
│  ├── Primary CTAs: [ Start Your Family Chronicle ]  [ Enter Invite Code]   │
│  └── Interactive Mobile App Preview (Light / Dark Mode Toggle)             │
├────────────────────────────────────────────────────────────────────────────┤
│ HOW IT WORKS (3-Step Feature Arc)                                          │
│  ├── 1. Invite without friction (WhatsApp/iMessage magic links)            │
│  ├── 2. Gentle AI Prompts (Cadence-aware questions tailored to aliases)    │
│  ├── 3. A Legacy to Hear & Read (Timeline with audio transcripts)          │
├────────────────────────────────────────────────────────────────────────────┤
│ THREE AGENTS DEMO (Interactive Preview)                                    │
│  ├── Agent 1 (Prompter): "Hi Granny! How has Leo's walking been?"          │
│  ├── Agent 2 (Curator): Auto-transcribes voice notes + extracts tags       │
│  └── Agent 3 (Guardian): Safety checks & duplicate review for parents      │
├────────────────────────────────────────────────────────────────────────────┤
│ TRUST, PRIVACY & GOVERNANCE                                                │
│  ├── Private & Ad-Free Household Data Vault                                │
│  ├── Granular Role Permissions (Owner / Contributor / Observer)            │
│  └── Audit-Logged Alias & Content Changes                                  │
├────────────────────────────────────────────────────────────────────────────┤
│ FOOTER CTA & AUTHENTICATION                                                │
│  ├── Large Call-to-Action: "Start Building Your Children's Chronicle"      │
│  └── Quick Auth: [ Sign in with Microsoft ]                                │
└────────────────────────────────────────────────────────────────────────────┘
```

---

### 2. Key Landing Page Sections & Content Structure

#### A. Hero Section

- **Headline**: "Capture childhood before it fades. Effortless family chronicles for the whole circle."
- **Subheadline**: "Invite grandparents, aunts, and uncles via WhatsApp or iMessage—no account setup required. Gentle AI prompts them for stories, transcribes audio, and creates a gift your child will cherish forever."
- **Primary Calls-to-Action**:
  - **Primary CTA**: `[ Start Household Chronicle ]` — Initiates Microsoft Easy Auth sign-in flow.
  - **Secondary CTA**: `[ Have an Invite Link? ]` — Focuses an inline text field to enter an invite code or token.
- **Hero Visual**: Dual floating device mockups displaying the app interface in light (`#F4F3EE`) and dark (`#121413`) theme variants.

#### B. Feature Arc: "Frictionless Family Bridge"

1. **Zero-Friction Invites**: Contributors (e.g., grandmothers, uncles) join via a single click on a messaging link—no password creation or heavy app downloads required.
2. **Custom Display Aliases**: Every family member is recognized by their preferred name (_Gaga_, _Nana_, _Uncle Ben_), maintained across all prompt interactions and timeline records.
3. **Voice & Photo First**: Contributors can record voice notes directly in the browser; Agent 2 automatically transcribes and links audio in the chronicle feed.

#### C. Agent Architecture Interactive Showcase

An interactive preview demonstrating the three asynchronous background agents:

- **Agent 1 (Prompter / Nudger)**: Demonstrates how cadence-aware prompts arrive as text-only question cards using the contributor's personal alias (_"Hi Granny..."_).
- **Agent 2 (Curator / Memory Keeper)**: Demonstrates real-time audio transcription, metadata extraction (topic, tags, dates), and vector embedding generation.
- **Agent 3 (Guardian / Reviewer)**: Highlights safety scoring, duplicate detection, and the owner review queue for human-in-the-loop oversight.

#### D. Privacy, Safety & Data Ownership

- **Private Household Vault**: Data is stored securely in dedicated Cosmos DB instances without ad tracking or public discovery.
- **Child Access Locks (`Locked Recipient`)**: Children unlock access as they grow older to experience their personal "listen when older" audio feed.
- **Enterprise Identity & Audit Logging**: Built with Microsoft accounts (Easy Auth) and immutable audit logging for role or alias changes.

---

### 3. Component Specifications

| Component Name              | Visual Styling                                                                                        | UX & Interaction Expectation                                                              |
| :-------------------------- | :---------------------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------- |
| **Hero Invite Input**       | Capsule input (`rounded-full`) with `#EBE8DF` surface and `#4A6048` focus ring.                       | Validates invite token syntax on keyup; redirects directly to `/invite/claim?token=...`.  |
| **Mode Preview Switcher**   | Segmented pill toggle (`Light Mode` / `Dark Mode`).                                                   | Switches hero mockups between `#F4F3EE` light surface and `#121413` dark slate canvas.    |
| **Interactive Agent Cards** | Horizontal tabbed cards with `#FFFFFF` background, `16px` border radius, and `#DCD8CD` subtle border. | Users can click between Agent 1, Agent 2, and Agent 3 to view live simulated event flows. |
| **Auth CTA Button**         | Primary button in `#4A6048` (Sage Green) with hover scale transition (`scale-105`).                   | Launches Microsoft OAuth flow via Azure App Service Easy Auth.                            |

## Page Structure & Component Architecture

### 1. Household Dashboard (`/dashboard`)

Serves as the high-level entry point for Household Owners, providing an overview of all managed child chronicles, contributor activity, and system flags requiring review.

**Page Structure**:

```plaintext
┌─────────────────────────────────────────────────────────┐
│ Top Bar: Household Switcher | Profile & Notification    │
├─────────────────────────────────────────────────────────┤
│ Children's Chronicles (Horizontal / Grid Cards)         │
│  ├── [ Leo (Age 3) ]  ├── [ Maya (Age 1) ]             │
├─────────────────────────────────────────────────────────┤
│ Quick Actions & Circle Overview                         │
│  ├── Invite Contributor Button                          │
│  └── Contributor Avatar Strip (Roles & Aliases)         │
├─────────────────────────────────────────────────────────┤
│ Guardian Review Queue Widget (Owner Only)               │
│  └── Flagged Memory / Alias Change Alert Cards          │
└─────────────────────────────────────────────────────────┘

```

**Components & Expectations**:

| Component Name            | Description & Key Specs                                                                                               | UX & Behavioral Expectation                                                                                |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| **Household Bar**         | Header showing current household name with dropdown selector for multi-household navigation.                          | Instant switching between households without full page reloads; reflects Easy Auth identity.               |
| **Chronicle Card**        | Card displaying child photo, age, memory count, and last activity timestamp.                                          | Tapping navigates directly to that child's timeline (`/chronicle/:id`).                                    |
| **Contributor Strip**     | Horizontal scrollable list showing active contributors with role tags (Owner, Full Contributor, Observer, Recipient). | Visual indicator of who is active; tapping opens Contributor Management panel.                             |
| **Guardian Queue Banner** | Highlighted card section displaying count of pending flags or unreviewed alias change requests.                       | Visible only to Owners. Provides one-tap access to approve/dismiss items inline or open full review queue. |

---

### 2. Chronicle Timeline & Memory Feed (`/chronicle/:childId`)

The central surface where memories live, reactive and proactive agent cards appear, and historical content can be filterable by chapters or contributors.

**Page Structure**:

```plaintext
┌─────────────────────────────────────────────────────────┐
│ Header: Back | Child Name | Chapter & Filter Pill Bar    │
├─────────────────────────────────────────────────────────┤
│ Tab Bar: [ Timeline (Active) ] [ Contributors ] [ Chapters ]│
├─────────────────────────────────────────────────────────┤
│ Agent 1: Dynamic Prompter / Question Card (Pinned/Top)  │
│  ├── Contextual Prompt text ("Hi Gaga, ...")            │
│  ├── Reply Input Bar (Text / Voice / Photo buttons)     │
├─────────────────────────────────────────────────────────┤
│ Memory Feed (Reverse Chronological / Grouped)           │
│  ├── Memory Item 1 (Voice note player + Transcript)     │
│  ├── Memory Item 2 (Photo grid + Caption)               │
│  └── Milestone Banner ("First Words" / "Baby Years")    │
└─────────────────────────────────────────────────────────┘

```

**Components & Expectations**:

| Component Name                | Description & Key Specs                                                                                                            | UX & Behavioral Expectation                                                                                                         |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| **Segmented Navigation Pill** | Sub-header tabs toggling between `Timeline`, `Contributors`, and `Milestone Chapters`.                                             | Smooth transition without breaking scroll state; updates URL query params for deep linking.                                         |
| **Agent 1 Prompter Card**     | Floating prompt box displaying a persona-aware question card personalized with the current user's display alias.                   | Displays check-in questions based on contributor cadence. Disappears or collapses into "Responded" state once a reply is submitted. |
| **Media Recorder Widget**     | In-browser audio recording modal/inline trigger using native `MediaRecorder` API.                                                  | Real-time waveform visualizer, pause/resume/delete buttons, and compressed blob upload indicator.                                   |
| **Timeline Memory Card**      | Card containing author avatar, snapped alias (`Gaga`), relative/absolute date, audio player, image previews, and transcribed text. | Audio plays inline with dynamic transcript highlighting. Includes subtle overflow menu for flag/edit actions.                       |
| **Milestone Chapter Marker**  | Distinct thematic divider breaking the feed into chapters (e.g., _Baby Years_, _First Steps_).                                     | Allows quick jump/filter by milestone category; provides visual delight for long-term archiving.                                    |

---

### 3. Contributor & Circle Management (`/chronicle/:childId/circle`)

The control panel for managing contributors, magic links, roles, and customized aliases.

**Page Structure**:

```plaintext
┌─────────────────────────────────────────────────────────┐
│ Header: Circle of Care Management                        │
├─────────────────────────────────────────────────────────┤
│ Active Contributor Roster (List View)                   │
│  ├── Contributor Name | Canonical Relation | Current Alias │
│  └── Role Badge | Cadence Badge | Options Menu           │
├─────────────────────────────────────────────────────────┤
│ Invite Generator Panel                                  │
│  ├── Name & Canonical Relation Input Form               │
│  ├── Role Dropdown Selection                            │
│  └── "Generate Magic Link" Button (WhatsApp/iMessage)   │
└─────────────────────────────────────────────────────────┘

```

**Components & Expectations**:

| Component Name           | Description & Key Specs                                                                                                     | UX & Behavioral Expectation                                                                                                    |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| **Magic Link Generator** | Modal/Card allowing Owners to specify canonical name, relation, and initial role before generating an invite URL.           | Produces a zero-friction deep-link URL ready to paste directly into WhatsApp or iMessage.                                      |
| **Alias Manager Row**    | List item showcasing canonical relation (e.g., _Maternal Grandmother_) alongside user-chosen `displayAlias` (e.g., _Gaga_). | Owners can edit or lock aliases; updates reflect immediately across new prompts while retaining historical snapshot integrity. |
| **Cadence Selector**     | Dropdown component for check-in frequency (`none`, `special-occasions`, `monthly`, `weekly`).                               | Sets the cadence filter for Agent 1 timer sweeps; accessible to both the contributor and the owner.                            |

---

### 4. Guardian Review Queue & Audit Log (`/guardian/review`)

The human-in-the-loop review hub powered by Agent 3 to safeguard content quality, privacy, and alias validation.

**Page Structure**:

```plaintext
┌─────────────────────────────────────────────────────────┐
│ Header: Guardian Safety & Audit Queue                   │
├─────────────────────────────────────────────────────────┤
│ Filter Pills: [ All (1) ] [ Flags ] [ Alias Requests ]  │
├─────────────────────────────────────────────────────────┤
│ Review Cards List                                       │
│  ├── Flag Reason & Score Metric                         │
│  ├── Memory / Alias Preview Snippet                     │
│  └── Action Bar: [ Approve ] [ Edit ] [ Hide ] [ Dismiss]│
├─────────────────────────────────────────────────────────┤
│ Audit History Log (Expandable Table)                    │
└─────────────────────────────────────────────────────────┘

```

**Components & Expectations**:

| Component Name         | Description & Key Specs                                                                                                                          | UX & Behavioral Expectation                                                                                                            |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------- |
| **Flag Review Card**   | Card highlighting memory content, flagged reason (e.g., duplicate detection, sensitive topic, low quality score), and Agent 3 confidence metric. | Owners can resolve flags in one click (`Approve`, `Edit`, `Hide`, `Dismiss`). Action automatically updates Cosmos state and audit log. |
| **Alias Request Card** | Specialized review item triggered when Agent 3 flags an alias change request that failed automated validation.                                   | Shows requested vs current alias; owner approval updates the database and triggers `alias.updated` event.                              |
| **Audit Trail Table**  | Chronological log displaying all past flag resolutions, role updates, and alias modifications with timestamps and actor IDs.                     | Read-only compliance view providing transparent history of household curation actions.                                                 |

---

### 5. Frictionless Invite Claim Flow (`/invite/claim?token=...`)

The onboarding screen experienced by invited contributors when clicking a magic link via messaging apps.

**Page Structure**:

```plaintext
┌─────────────────────────────────────────────────────────┐
│ Top Banner: Child Avatar & Welcome Greeting             │
│ "You've been invited to Leo's Chronicle!"              │
├─────────────────────────────────────────────────────────┤
│ Step 1: Confirm Your Display Name                       │
│  └── Input: "What should Leo call you?" (e.g., Gaga)    │
├─────────────────────────────────────────────────────────┤
│ Step 2: Choose Prompt Cadence                           │
│  └── Radio Options: Monthly / Weekly / Special Occasions│
├─────────────────────────────────────────────────────────┤
│ Primary CTA Button: [ Enter Chronicle ]                 │
└─────────────────────────────────────────────────────────┘

```

**Components & Expectations**:

| Component Name          | Description & Key Specs                                                                                                     | UX & Behavioral Expectation                                                                            |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| **Welcome Header**      | Personalized welcome banner showing inviting owner's name and child's profile photo.                                        | Immediately establishes trust and context without requiring password creation.                         |
| **Alias Input Field**   | Pre-filled text input defaulting to canonical relation (e.g. _Grandmother_), customizable to preferred alias (e.g. _Gaga_). | Real-time feedback validating uniqueness within that child's chronicle.                                |
| **Cadence Radio Cards** | Simple, visual selection cards for check-in frequency with plain-language descriptions.                                     | Gives contributors immediate control over outbound prompter frequency before entering the application. |
