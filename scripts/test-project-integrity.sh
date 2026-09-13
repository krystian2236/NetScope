#!/bin/zsh

set -euo pipefail

for dependency in xcodebuild plutil mktemp grep cat rm; do
  command -v "$dependency" >/dev/null || {
    print -u2 "Brak wymaganego narzędzia: $dependency"
    exit 1
  }
done

repo_root="${0:A:h:h}"
derived_data="$(mktemp -d /private/tmp/netscope-integrity.XXXXXX)"
build_log="$derived_data/xcodebuild.log"
trap 'rm -rf -- "$derived_data"' EXIT

if grep -q 'Text("Szybkie działania")' "$repo_root/NetScope/DashboardView.swift"; then
  print -u2 "Dashboard nadal dubluje dolną nawigację"
  exit 1
fi

for required_source in NmapCatalog NucleiCatalog ToolLearningView; do
  grep -q "$required_source.swift" "$repo_root/NetScope.xcodeproj/project.pbxproj" || {
    print -u2 "Brak $required_source.swift w projekcie Xcode"
    exit 1
  }
done

grep -q 'tool: NmapCatalog.definition' "$repo_root/NetScope/ToolboxView.swift"
grep -q 'tool: NucleiCatalog.definition' "$repo_root/NetScope/ToolboxView.swift"

build_bundle() {
  xcodebuild \
    -project "$repo_root/NetScope.xcodeproj" \
    -scheme NetScope \
    -configuration Release \
    -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$derived_data" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    "$@" \
    build
}

if build_bundle >"$build_log" 2>&1; then
  cat "$build_log"
elif grep -q "swift-plugin-server.*produced malformed response" "$build_log"; then
  cat "$build_log"
  print -u2 "Uwaga: ponawiam build z -disable-sandbox z powodu błędu Xcode beta."
  build_bundle OTHER_SWIFT_FLAGS=-disable-sandbox
else
  cat "$build_log"
  exit 1
fi

app_bundle="$derived_data/Build/Products/Release-iphoneos/NetScope.app"
info_plist="$app_bundle/Info.plist"

[[ -f "$info_plist" ]] || {
  print -u2 "Brak wygenerowanego Info.plist: $info_plist"
  exit 1
}

assert_plist_value() {
  local key="$1"
  local expected="$2"
  local actual

  actual="$(plutil -extract "$key" raw -o - "$info_plist")"
  [[ "$actual" == "$expected" ]] || {
    print -u2 "$key: oczekiwano '$expected', otrzymano '$actual'"
    exit 1
  }
}

assert_plist_value CFBundleIdentifier pl.krystian.NetScope
assert_plist_value CFBundleShortVersionString 1.3
assert_plist_value ITSAppUsesNonExemptEncryption false

local_network_description="$(
  plutil -extract NSLocalNetworkUsageDescription raw -o - "$info_plist"
)"
[[ -n "$local_network_description" ]] || {
  print -u2 "NSLocalNetworkUsageDescription nie może być pusty"
  exit 1
}

assert_plist_value CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconName AppIcon
[[ -f "$app_bundle/Assets.car" ]] || {
  print -u2 "Brak skompilowanego katalogu zasobów Assets.car"
  exit 1
}

privacy_manifest="$app_bundle/PrivacyInfo.xcprivacy"
[[ -f "$privacy_manifest" ]] || {
  print -u2 "Brak PrivacyInfo.xcprivacy w bundle aplikacji"
  exit 1
}

assert_privacy_value() {
  local key="$1"
  local expected="$2"
  local actual

  actual="$(plutil -extract "$key" raw -o - "$privacy_manifest")"
  [[ "$actual" == "$expected" ]] || {
    print -u2 "PrivacyInfo $key: oczekiwano '$expected', otrzymano '$actual'"
    exit 1
  }
}

assert_privacy_value NSPrivacyTracking false
assert_privacy_value NSPrivacyAccessedAPITypes.0.NSPrivacyAccessedAPIType \
  NSPrivacyAccessedAPICategoryUserDefaults
assert_privacy_value NSPrivacyAccessedAPITypes.0.NSPrivacyAccessedAPITypeReasons.0 \
  CA92.1

print "Integralność bundle: OK"
