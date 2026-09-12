#!/bin/zsh

set -euo pipefail

repo_root="${0:A:h:h}"
cd "$repo_root"

check_log="$(mktemp /private/tmp/netscope-pre-push.XXXXXX)"
trap 'rm -f -- "$check_log"' EXIT

command -v git >/dev/null || {
  print -u2 "Brak wymaganego narzędzia: git"
  exit 1
}

[[ "$(git rev-parse --show-toplevel)" == "$repo_root" ]] || {
  print -u2 "Skrypt uruchomiono poza repozytorium NetScope"
  exit 1
}

print "=== Stan Git ==="
git status --short --branch

print "\n=== Poprawność diffu ==="
git diff --check
git diff --cached --check
print "Diff: OK"

print "\n=== Kontrola nazw plików w Git ==="
suspicious_pattern='(^|/)(\.env($|\.)|id_(rsa|dsa|ecdsa|ed25519)(\.|$)|.*\.(pem|p12|pfx|key)$)'
if git ls-files | grep -E "$suspicious_pattern" >/dev/null; then
  print -u2 "Wykryto potencjalny sekret lub klucz w śledzonych plikach:"
  git ls-files | grep -E "$suspicious_pattern" | sed 's/^/  - /'
  exit 1
fi
print "Nazwy plików: OK"

print "\n=== Integralność projektu ==="
if "$repo_root/scripts/test-project-integrity.sh" >"$check_log" 2>&1; then
  grep -E '\*\* BUILD SUCCEEDED \*\*|Integralność bundle: OK' "$check_log"
else
  cat "$check_log"
  exit 1
fi

print "\nKontrola przed push: OK"
