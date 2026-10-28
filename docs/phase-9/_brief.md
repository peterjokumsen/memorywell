# Phase 9 Brief — Cheap, always-on hosting

> Status: in progress.

## Goal

Reduce hosting cost to near-zero while keeping the app always-on: free SWA for web, drop Redis in prod, scale-to-zero API, Flex Consumption Functions, Log Analytics cap, cheapest OpenAI model, budget alert.

## Ordered steps

1. Web on Azure Static Web Apps (free tier) — replace App Service.
2. Drop Redis in prod — remove redis module usage / conditional.
3. Scale-to-zero Container App API (min replicas 0).
4. Ensure Functions on Flex Consumption (no always-ready).
5. Log Analytics daily cap.
6. Cheapest OpenAI model in params.
7. Budget alert module.

## Review gate

- Bicep builds
- Cost estimate reduced
