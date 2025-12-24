# SCHOLESA Audit Scripts

This directory contains the automation tools required to enforce the `SCHOLESA_AUDIT_FIX_AND_REMEDIATION_VIBE.md` protocol. These scripts handle automated verification, report updating, and archiving.

## ⚙️ Setup

Before using these scripts, ensure they are executable:

```bash
chmod +x scripts/*.sh
```

## 🛠️ Tools

### 1. `run_phase1_checks.sh`
**Purpose:** Automates Phase 1 of the audit protocol.

*   Runs `flutter analyze`, `flutter test`, `dart pub audit`, and `dart format`.
*   **Automatically updates** `AUDIT_REPORT.md` with the results (Pass/Fail).
*   Use this locally before committing major changes.

**Usage:**
```bash
./scripts/run_phase1_checks.sh
```

### 2. `verify_audit_pass.sh`
**Purpose:** CI/CD Verification Gate.

*   Parses `AUDIT_REPORT.md` to ensure no checks are marked as `FAIL`.
*   Exits with an error code if failures are found, blocking the build.
*   Used primarily in GitHub Actions (`scholesa_phase1.yml`).

**Usage:**
```bash
./scripts/verify_audit_pass.sh
```

### 3. `archive_audit.sh`
**Purpose:** Lifecycle management.

*   Moves the current `AUDIT_REPORT.md` to `audit_archive/` with a timestamp.
*   Resets `AUDIT_REPORT.md` to the clean template.
*   Run this **after** a feature is merged and signed off, to prepare for the next task.

**Usage:**
```bash
./scripts/archive_audit.sh
```

## ⚓ Git Hooks

### `pre-commit`
**Purpose:** Enforces process compliance.

*   Blocks commits if `.dart` files are modified but `AUDIT_REPORT.md` is not.
*   Reminds developers to run the Phase 1 checks.

**Installation:**
Copy the hook to your git configuration:
```bash
cp scripts/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

**Bypass (Emergency only):** `SKIP_AUDIT=1 git commit ...`