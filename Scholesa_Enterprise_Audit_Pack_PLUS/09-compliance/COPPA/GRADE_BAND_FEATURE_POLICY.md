# Grade-Band Feature Policy (Enforcement Spec)

## K–5 (Under-13 emphasis)
- No open-ended free chat by default (guided interactions only)
- Stronger moderation thresholds
- Limited external link generation
- Limited uploads (type and size)
- Teacher-visible logs by default

## 6–8
- Guided tutoring with checkpoints
- More autonomy but bounded tool use
- Reflection required for mission completion

## 9–12
- Expanded coaching support
- Explain-back and citation/verification prompts
- Portfolio artifact + rubric alignment

## Enforcement mechanism
- Firebase custom claims: gradeBand, role, siteId
- API middleware + AI policy engine enforce feature gating
