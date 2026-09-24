#!/bin/zsh

set -euo pipefail

repo_root="${0:A:h:h}"
cd "$repo_root"

command -v git >/dev/null || { print -u2 "Brak wymaganego narzędzia: git"; exit 1; }
command -v rg >/dev/null || { print -u2 "Brak wymaganego narzędzia: rg"; exit 1; }
command -v plutil >/dev/null || { print -u2 "Brak wymaganego narzędzia: plutil"; exit 1; }

project_file="$repo_root/NetScope.xcodeproj/project.pbxproj"
info_plist="$repo_root/NetScope/Info.plist"

marketing_values=($(rg -o 'MARKETING_VERSION = [^;]+' "$project_file" | sed 's/.* = //'))
build_values=($(rg -o 'CURRENT_PROJECT_VERSION = [^;]+' "$project_file" | sed 's/.* = //'))

(( ${#marketing_values[@]} >= 2 )) || { print -u2 "Brak wersji marketingowej dla obu konfiguracji."; exit 1; }
(( ${#build_values[@]} >= 2 )) || { print -u2 "Brak numeru buildu dla obu konfiguracji."; exit 1; }

marketing_unique=($(printf '%s\n' $marketing_values | sort -u))
build_unique=($(printf '%s\n' $build_values | sort -u))
(( ${#marketing_unique[@]} == 1 )) || { print -u2 "Developer i App Store mają różne MARKETING_VERSION."; exit 1; }
(( ${#build_unique[@]} == 1 )) || { print -u2 "Developer i App Store mają różny CURRENT_PROJECT_VERSION."; exit 1; }

marketing_version="${marketing_unique[1]}"
current_build="${build_unique[1]}"
[[ "$marketing_version" =~ '^[0-9]+\.[0-9]+(\.[0-9]+)?$' ]] || { print -u2 "Nieprawidłowy MARKETING_VERSION: $marketing_version"; exit 1; }
[[ "$current_build" =~ '^[0-9]+$' ]] || { print -u2 "Nieprawidłowy CURRENT_PROJECT_VERSION: $current_build"; exit 1; }

plutil -extract CFBundleShortVersionString raw -o - "$info_plist" | grep -qx '\$(MARKETING_VERSION)' || { print -u2 "Info.plist nie używa MARKETING_VERSION."; exit 1; }
plutil -extract CFBundleVersion raw -o - "$info_plist" | grep -qx '\$(CURRENT_PROJECT_VERSION)' || { print -u2 "Info.plist nie używa CURRENT_PROJECT_VERSION."; exit 1; }

grep -q "^## $marketing_version$" CHANGELOG.md || { print -u2 "CHANGELOG.md nie zawiera sekcji dla wersji $marketing_version."; exit 1; }
grep -q '^## Unreleased$' CHANGELOG.md || { print -u2 "CHANGELOG.md musi zawierać sekcję Unreleased."; exit 1; }

head_build="$(git show HEAD:NetScope.xcodeproj/project.pbxproj 2>/dev/null | rg -o -m1 'CURRENT_PROJECT_VERSION = [^;]+' | sed 's/.* = //')"
source_changed=0
if git status --short --untracked-files=all -- NetScope | rg -q '(\.swift|Info\.plist|PrivacyInfo\.xcprivacy)$'; then source_changed=1; fi

if (( source_changed == 1 )); then
  [[ "$current_build" -gt "$head_build" ]] || { print -u2 "Zmiana aplikacji wymaga zwiększenia CURRENT_PROJECT_VERSION (HEAD: $head_build, bieżący: $current_build)."; exit 1; }
  git diff --name-only HEAD -- CHANGELOG.md | grep -qx 'CHANGELOG.md' || { print -u2 "Zmiana aplikacji wymaga aktualizacji CHANGELOG.md."; exit 1; }
fi

print "Wersjonowanie: OK — $marketing_version (build $current_build), konfiguracje spójne."
