#!/bin/zsh
set -euo pipefail
repo_root="${0:A:h:h}"
cd "$repo_root"
for f in AGENTS.md SPEC.md ROADMAP.md TASKS.md; do
  [[ -s "$f" ]] || { print -u2 "Brak lub pusty plik: $f"; exit 1; }
done
git diff --check
git diff --cached --check
if git ls-files | grep -E '(^|/)(\.env($|\.)|id_(rsa|dsa|ecdsa|ed25519)(\.|$)|.*\.(pem|p12|pfx|key)$)' >/dev/null; then
  print -u2 'Podejrzana nazwa sekretu/klucza w śledzonych plikach'; exit 1
fi
print 'Workflow harness: OK'
