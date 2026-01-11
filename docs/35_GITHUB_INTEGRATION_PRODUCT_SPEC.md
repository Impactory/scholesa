# 35_GITHUB_INTEGRATION_PRODUCT_SPEC.md
GitHub integration inside the Scholesa Classroom Add-on

Objective:
- Let teachers include authentic “real-world coding workflow” tasks as part of a Scholesa mission
- Keep Scholesa as the evidence/reflection/review system (pillars + accountability)
- Support both:
  A) link-based GitHub Classroom assignments (recommended)
  B) managed provisioning (advanced, optional)

GitHub capabilities used: OAuth scopes, REST API for repos, and webhooks. citeturn1search2turn1search1turn1search3

---

## 1) Recommended: Link-based GitHub Classroom tasks
Teacher attaches a GitHub Classroom assignment link to a Scholesa mission step.

Pros:
- simplest for schools
- GitHub Classroom remains the repo provisioning engine
- Scholesa focuses on coaching + rubric + portfolio evidence

Scholesa stores:
- assignment URL
- expected deliverables (repo URL, PR link, screenshots)
- rubric mapping to pillars/skills

---

## 2) Advanced: Managed provisioning (optional)
Scholesa provisions repos and tracks progress.

### Auth model
Prefer a **GitHub App** installed on an organization for org-level permissions and clean lifecycle,
but note: some repo generation actions (like creating a repo from a template) can require user-to-server requests depending on GitHub capability availability for Apps.
Plan for:
- GitHub App (server-to-server) for webhooks + org repos
- GitHub OAuth (user) only if a required action can’t be performed via App permissions

OAuth scopes are documented by GitHub. citeturn1search2

### Repo creation / provisioning
Use GitHub REST API “repositories” endpoints, including “Create a repository using a template” where appropriate. citeturn1search1turn1search15

Typical provisioning:
1. Create repo for student/team (from template OR from baseline repo)
2. Add collaborators/team
3. Create issues (mission steps)
4. Optional: seed PR checklist and labels

### Progress signals
- Webhook events for push, pull_request, issues, check_suite, etc. citeturn1search9turn1search6
- Convert signals into Scholesa:
  - “evidence suggestion” prompts
  - teacher dashboard insights
  - student habit nudges (timely)

---

## 3) Data model (additive)
Store provider links, never secrets:
- `GitHubConnection` (tokenRef, status)
- `ExternalRepoLink` (repo full_name, html_url, installationId?)
- `ExternalPullRequestLink` (pr url/id)
- `GitHubEventCursor` (last delivery id, last seen sha)

(Concrete interfaces are added to schema in docs/02A_SCHEMA_V3.ts.)

---

## 4) Safety and boundaries
- No student secrets stored
- Webhook signature verification required
- Parent access: view-only summaries; never show private repo data unless explicitly permitted and policy-approved
