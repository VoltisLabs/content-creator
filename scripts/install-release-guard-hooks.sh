#!/bin/bash
# Install a pre-commit hook that blocks commits regressing release-critical wiring.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="${PROJECT_ROOT}/.git/hooks"
HOOK="${HOOKS_DIR}/pre-commit"

if [[ ! -d "${PROJECT_ROOT}/.git" ]]; then
  echo "❌ Not a git repository: ${PROJECT_ROOT}"
  exit 1
fi

mkdir -p "${HOOKS_DIR}"

cat >"${HOOK}" <<'EOF'
#!/bin/bash
# Content Calendar — block commits that break release-critical wiring.
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
CRITICAL='lib/main.dart|lib/widgets/settings_sheet.dart|lib/widgets/settings_account_page.dart|lib/widgets/settings_plans_page.dart|lib/screens/auth_gate.dart|pubspec.yaml'

if git diff --cached --name-only | grep -qE "^(${CRITICAL})$"; then
  echo "🔒 Release guard: checking critical files in this commit…"
  python3 "${ROOT}/scripts/verify-release-readiness.py" || {
    echo ""
    echo "Commit blocked. Fix release regressions before committing."
    exit 1
  }
  "${ROOT}/scripts/run-release-integrity-test.sh" || exit 1
fi
EOF

chmod +x "${HOOK}"
echo "✅ Installed pre-commit release guard: ${HOOK}"
