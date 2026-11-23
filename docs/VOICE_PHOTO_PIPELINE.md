# Voice/Photo Pipeline

Consolidated from Phase 6.

## Overview

- Blob storage (tiering, compressed formats) -> Service Bus -> Speech-to-Text -> transcript back to Cosmos.
- `sb_transcription`: parse job, call STT, write transcript to Cosmos.
- Blob upload endpoint in API (voice/photo) + Service Bus enqueue.
  "
