# Release Gate — Voice System

Block release if:
- voice:egress-none fails
- voice:tenant-isolation fails
- tts:prosody-policy fails (K–5)
- stt locale smoke fails for enabled locales
- utf8 integrity fails

Required artifacts per release:
- audit-pack voice reports JSON
- dashboard screenshots/links
- confirmation of GCS lifecycle TTL
