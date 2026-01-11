# 40_GITHUB_APP_PERMISSIONS_MATRIX_AND_OAUTH_FALLBACK.md
GitHub App permissions matrix + OAuth fallback scopes (Scholesa)

Objective:
- Default to a **GitHub App** (least privilege, installable by org admin)
- Use **OAuth fallback** only when an operation cannot be performed with an installation token (or requires acting on behalf of a user)

GitHub’s guidance:
- GitHub Apps use **fine-grained permissions** and are recommended over OAuth where possible. citeturn4view2  
- GitHub provides a definitive mapping of REST endpoints ↔ required GitHub App permissions, and the REST API returns an `X-Accepted-GitHub-Permissions` header to tell you what is required. citeturn4view1turn4view0  

---

## A) Permission sets (choose based on features)

### A0 — Link-based only (recommended baseline)
**Feature**: Teacher stores a GitHub Classroom assignment link; Scholesa does not call GitHub APIs.
**GitHub App needed**: No
**OAuth needed**: No

---

### A1 — Read-only progress signals (webhooks + read)
**Feature**: Show progress hints (push/PR activity), but do not create repos/issues.
**GitHub App repository permissions (minimum)**
- `Metadata`: Read (repo identity, basic info) citeturn5view2turn4view1  
- `Pull requests`: Read (PR status, titles, merged state) citeturn5view2turn4view1  
- `Checks`: Read (optional, if you surface CI signals) citeturn5view2turn4view1  
- `Webhooks`: Read/Write if you auto-create hooks; otherwise none and hooks are configured manually. citeturn5view2turn4view1  

**Notes**
- Prefer receiving webhooks via GitHub App subscriptions rather than polling.
- Verify every webhook signature and log delivery IDs.

---

### A2 — Managed provisioning (repos + issues + optional PR workflow)
**Feature**: Scholesa provisions repos and issues for learners/teams.

**GitHub App repository permissions (typical)**
- `Administration`: Write (if creating repos, managing settings, or installing hooks programmatically) citeturn5view2turn4view1  
- `Contents`: Write (seed files, create/update content when necessary) citeturn5view2turn4view1  
- `Issues`: Write (create issues/checklists) citeturn5view2turn4view1  
- `Pull requests`: Read (or Write only if Scholesa posts PR review comments) citeturn5view2turn4view1  
- `Metadata`: Read citeturn5view2turn4view1  
- `Webhooks`: Write (if creating webhooks programmatically) citeturn5view2turn4view1  

**Organization permissions (only if needed)**
- `Members`: Read (only if you need to map org members to users for provisioning UX) citeturn1view0turn5view2  

**Hard rule**
- Start with the smallest set; validate required permissions by checking `X-Accepted-GitHub-Permissions` headers during integration testing. citeturn4view0turn4view1  

---

## B) OAuth fallback scopes (only if required)
Some operations may require acting on behalf of a user.

### Create repos using template via OAuth (common fallback)
GitHub’s official REST docs indicate OAuth app tokens (and classic PATs) need:
- `public_repo` or `repo` to create a public repository
- `repo` to create a private repository citeturn6search12  

### Modify GitHub Actions workflow files
If your integration edits workflow files, GitHub notes you must authenticate on behalf of the user with an OAuth token that includes the `workflow` scope. citeturn4view3turn0search2  

### General OAuth scope source of truth
Use GitHub’s official OAuth scope reference. citeturn0search2turn4view2  

---

## C) Recommended strategy for Scholesa
### Default (schools)
- A0 link-based OR A1 read-only signals
- no OAuth for students
- GitHub App installed at org level by partner/school IT

### Advanced (selected partners)
- A2 managed provisioning enabled only for approved sites/partners
- OAuth fallback only for specific endpoints that cannot be done via installation token
- record in AuditLog when OAuth fallback is used

---

## D) Implementation requirements (must-follow)
1) Support **two auth modes** in code:
   - GitHub App installation token
   - GitHub OAuth user token (fallback)
2) Every GitHub REST call logs:
   - request id/correlation id
   - endpoint
   - token type (IAT vs UAT)
   - resulting `X-Accepted-GitHub-Permissions` header (when present)
3) If a call fails with permissions, surface a “Fix permissions” UI for admins, not for students.
