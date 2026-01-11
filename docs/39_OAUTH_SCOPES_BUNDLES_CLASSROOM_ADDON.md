# 39_OAUTH_SCOPES_BUNDLES_CLASSROOM_ADDON.md
OAuth Scope Bundles — Google Classroom Add-on (Scholesa)

Purpose: give Codex a **non-ambiguous** set of OAuth scopes to request for Scholesa’s Google Classroom Add-on (Option 2), while keeping least-privilege and your policy constraints (no guardian auto-linking).

Google’s official Classroom scope list defines what each scope allows. citeturn2view0turn2view1  
Google’s add-on walkthrough for external attachments explicitly calls out the **minimum add-on/assignment scopes** for attachment management. citeturn1view2  

---

## Golden rules
1) **Never** request guardian scopes (`classroom.guardianlinks.*`). Parent↔Learner linking stays admin-only in Scholesa. citeturn2view2  
2) Keep scope prompts minimal and explain “why” on the consent screen.
3) Grade writes must use the **same Google Cloud project OAuth client** that created the CourseWork/submission you’re modifying. citeturn0search12  

---

## Bundle A — “Add-on Only (Phase 1)”
Use this if you only:
- load Classroom add-on iframes
- create/manage Scholesa **AddOnAttachments** on stream items
- do NOT roster sync and do NOT write grades yet

**Scopes**
- `https://www.googleapis.com/auth/classroom.addons.teacher` citeturn2view0  
- `https://www.googleapis.com/auth/classroom.addons.student` citeturn2view0  

**When used**
- Iframe entrypoints:
  - `/classroom/iframe/discovery`
  - `/classroom/iframe/teacher`
  - `/classroom/iframe/student`

---

## Bundle B — “Add-on + Assignment Management (Phase 1+)”
Use this if you:
- programmatically create/modify the parent stream items that hold your add-on attachment
- manage assignment lifecycle around attachments
- plan to “turn in / return” via API patterns

**Scopes**
- `https://www.googleapis.com/auth/classroom.addons.teacher` citeturn1view2  
- `https://www.googleapis.com/auth/classroom.addons.student` citeturn1view2  
- `https://www.googleapis.com/auth/classroom.coursework.students` citeturn1view2turn2view2  

**Notes**
- The add-ons walkthrough lists `classroom.coursework.students` alongside the add-on scopes for “assignment management” patterns. citeturn1view2  

---

## Bundle C — “Roster Sync + Course Discovery (Physical school ops)”
Use this if you:
- sync Classroom rosters → Scholesa enrollments
- map Classroom course → Scholesa Site/Session
- need course browsing for teacher selection UI

**Scopes (minimal)**
- `https://www.googleapis.com/auth/classroom.courses.readonly` citeturn2view2  
- `https://www.googleapis.com/auth/classroom.rosters.readonly` citeturn2view1  
- `https://www.googleapis.com/auth/classroom.profile.emails` (recommended for reliable matching by email) citeturn2view1  

**Optional (only if you truly need it)**
- `https://www.googleapis.com/auth/classroom.profile.photos` (display avatars) citeturn2view1  

**Explicitly avoid**
- `classroom.rosters` (write) unless you are actually editing rosters.
- any guardian scopes (see Golden rules).

---

## Bundle D — “Phase 2 Grade Sync (Add-on grading)”
Use this if you:
- push grade summary from Scholesa back into Classroom for **add-on attachment submissions**

**Scopes**
- (Everything from Bundle B) plus:
  - typically no additional scopes beyond `classroom.coursework.students` for teacher-side grade actions,
  - but confirm per endpoint access and app review requirements.

**Implementation check**
- For every write to CourseWork/submissions, validate the OAuth client project binding. citeturn0search12  

---

## Recommended configuration for Scholesa (Option 2)
### Phase 1
- Bundle B + Bundle C  
(Attachments + roster sync, no grades yet)

### Phase 2
- Bundle B + Bundle C (already)  
(Enable grade push/return paths)

---

## Consent UX requirement (must include in implementation)
In Scholesa “Connect Classroom”, show a checkbox list:
- “Attach missions inside Classroom” (Bundle B)
- “Sync roster from Classroom” (Bundle C)
- “Send grade summaries back to Classroom” (Phase 2 toggle; uses Bundle B)

Only request the scopes needed for the toggles the user selects.
