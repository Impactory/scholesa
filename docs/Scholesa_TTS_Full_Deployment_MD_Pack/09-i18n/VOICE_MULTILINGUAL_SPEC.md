# Voice Multilingual Spec (en, zh-CN, zh-TW, th)

## Requirements
- STT locale set from UI + user profile + Accept-Language
- TTS voice model selection by locale
- Tokenization/segmentation per locale:
  - Thai: segmentation required
  - Chinese: segmentation + polyphonic handling where needed

## Tests
- Smoke transcripts in each locale
- Pronunciation regression for STEM terms per locale
- UTF-8 integrity export/import tests
