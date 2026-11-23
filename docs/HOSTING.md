# Hosting & Cost (Phase 9)

## Goal

Reduce hosting cost to near-zero while keeping app always-on.

## Changes

- Web on Azure Static Web Apps (free tier) — replaces App Service.
- Drop Redis in prod (remove redis module usage / conditional).
- Scale-to-zero Container App API (min replicas 0).
- Functions on Flex Consumption (no always-ready).
- Log Analytics daily cap.
- Cheapest OpenAI model in params.
- Budget alert module.
  "
