# Phase 6 Brief — Voice/photo pipeline

> Status: in progress (2026-10-28). Phase 5 merged.

## Goal

Implement the voice/photo pipeline: Blob storage (tiering, compressed formats) ->
Service Bus -> Speech-to-Text -> transcript back to Cosmos.

## AI-200 concepts

- Blob Storage (tiering, open formats)
- Service Bus queue for transcription jobs
- Azure OpenAI / Speech STT
- Cosmos DB update with transcript

## Ordered steps

1. Implement sb_transcription: parse job, call STT, write transcript to Cosmos.
2. Add blob upload endpoint in API (voice/photo) + Service Bus enqueue.
3. Blob lifecycle/tiering Bicep + containers.
4. Tests.

## Review gate

- Voice note upload -> transcription -> transcript in timeline
- Empty DLQ
