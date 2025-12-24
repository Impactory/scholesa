#!/bin/bash

AUDIT_REPORT="AUDIT_REPORT.md"

echo "🚀 Starting SCHOLESA Phase 1 Automated Verification..."
echo "-----------------------------------------------------"

# Initialize status variables
STATUS_ANALYSIS="Pass"
STATUS_TEST="Pass"
STATUS_DEPS="Pass"
STATUS_FORMAT="Pass"

# 1. Static Analysis
echo "1️⃣  Running Static Analysis..."
if ! flutter analyze --fatal-warnings; then
  STATUS_ANALYSIS="FAIL"
fi

# 2. Unit Tests
echo "2️⃣  Running Unit Tests..."
if ! flutter test; then
  STATUS_TEST="FAIL"
fi

# 3. Dependency Check
echo "3️⃣  Running Dependency Audit..."
if ! dart pub audit; then
  STATUS_DEPS="FAIL"
fi

# 4. Formatting
echo "4️⃣  Checking Formatting..."
if ! dart format --output=none --set-exit-if-changed .; then
  STATUS_FORMAT="FAIL"
fi

echo "-----------------------------------------------------"
echo "✅ Verification Complete."

if [ -f "$AUDIT_REPORT" ]; then
  echo "📝 Updating $AUDIT_REPORT..."

  # Use a temporary file to handle sed in-place editing portably
  TMP_FILE="${AUDIT_REPORT}.tmp"

  # Update each check row
  sed "s/| Static Analysis | \`flutter analyze\` | .* |/| Static Analysis | \`flutter analyze\` | $STATUS_ANALYSIS | |/" "$AUDIT_REPORT" > "$TMP_FILE"
  mv "$TMP_FILE" "$AUDIT_REPORT"

  sed "s/| Unit Tests | \`flutter test\` | .* |/| Unit Tests | \`flutter test\` | $STATUS_TEST | |/" "$AUDIT_REPORT" > "$TMP_FILE"
  mv "$TMP_FILE" "$AUDIT_REPORT"

  sed "s/| Dependency Check | \`dart pub audit\` | .* |/| Dependency Check | \`dart pub audit\` | $STATUS_DEPS | |/" "$AUDIT_REPORT" > "$TMP_FILE"
  mv "$TMP_FILE" "$AUDIT_REPORT"

  sed "s/| Formatting | \`dart format .\` | .* |/| Formatting | \`dart format .\` | $STATUS_FORMAT | |/" "$AUDIT_REPORT" > "$TMP_FILE"
  mv "$TMP_FILE" "$AUDIT_REPORT"

  echo "✅ $AUDIT_REPORT updated with Phase 1 results."
else
  echo "⚠️  $AUDIT_REPORT not found. Could not update results automatically."
fi