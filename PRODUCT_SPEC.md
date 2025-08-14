# Duru Notes — Product Specification (MVP → V2)
Platform: iOS + Android (tablet-friendly) • Backend: Supabase • Pricing: $4.99 one-time
Principles: 3-sec capture • Local-first • E2EE • Simple UI

MUST (V1)
- Supabase Auth only (no custom auth).
- Local DB (SQLite/Drift) + E2EE (XChaCha20-Poly1305; HKDF). Supabase stores *_enc bytea only.
- Block editor: text/heading/todo/quote/code/table + inline Markdown.
- Links & tags: [[backlinks]], #tags (supertag-light).
- Capture: Share-sheet target; Camera Scan + on-device OCR; Voice note + live transcript (timeline).
- Tasks & Reminders: time/location (local notifications).
- Search: instant over title/body/tags + OCR cache; lite on-device semantic suggestions.
- Attachments & Export: Supabase Storage (private), export to PDF/Markdown.
- Import: Markdown/ENEX/Obsidian folder (on-device).
SLOs: App launch < 400ms; search < 150ms on 10k notes; share-sheet → saved ≤ 3.0s avg.

WON’T (V1)
- Web/PWA, email-in, browser clipper, real-time multi-user editing, server-side LLM/embeddings.
