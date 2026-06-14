#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)"

PLATFORM="all"
DRY_RUN="0"
ANDROID_CODE_PREFIX="24"
ANDROID_VERSION_CODE=""
FLUTTER_VERSION_CODE=""
REACT_NATIVE_VERSION_CODE=""
VERSION=""

usage() {
    cat <<'EOF'
Usage:
  scripts/set_version.sh [options] VERSION

Options:
  -p, --platform PLATFORM          Platform to update: all, android, linux, flutter, react-native
      --dry-run                    Print planned changes without writing files
      --android-version-code CODE  Override Android versionCode
      --android-code-prefix PREFIX Prefix used for derived Android versionCode (default: 24)
      --flutter-version-code CODE  Override Flutter flutterVersionCode
      --react-native-version-code CODE
                                   Override React Native Android versionCode
  -h, --help                       Show this help

Examples:
  scripts/set_version.sh 6.1.3
  scripts/set_version.sh --platform flutter 6.1.4
  scripts/set_version.sh -p android --android-version-code 240614 6.1.4

Default version-code derivation:
  Flutter / React Native: 6.1.3 -> 613
  Android:                6.1.3 -> 240613
EOF
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

is_positive_integer() {
    case "$1" in
        ''|*[!0-9]*)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

validate_version() {
    printf '%s\n' "$1" | grep -Eq '^[0-9]+(\.[0-9]+){1,2}$' || \
        die "version must be numeric X.Y or X.Y.Z, got: $1"
}

normalize_platform() {
    case "$1" in
        all|android|linux|flutter|react-native)
            printf '%s\n' "$1"
            ;;
        react_native|reactnative|rn)
            printf '%s\n' "react-native"
            ;;
        *)
            die "unknown platform '$1' (expected all, android, linux, flutter, react-native)"
            ;;
    esac
}

compact_version_code() {
    printf '%s\n' "$1" | awk -F. '
        NF == 2 { printf "%d%d0\n", $1, $2; next }
        NF == 3 { printf "%d%d%d\n", $1, $2, $3; next }
        { exit 1 }
    '
}

derive_android_version_code() {
    compact="$(compact_version_code "$1")"
    printf '%s%04d\n' "$ANDROID_CODE_PREFIX" "$compact"
}

should_update_platform() {
    [ "$PLATFORM" = "all" ] || [ "$PLATFORM" = "$1" ]
}

print_change() {
    platform="$1"
    file="$2"
    field="$3"
    old="$4"
    new="$5"
    printf '%-13s %-58s %-26s %s -> %s\n' "$platform" "$file" "$field" "$old" "$new"
}

write_temp_file() {
    file="$1"
    tmp="${file}.tmp.$$"
    cat > "$tmp"
    mv "$tmp" "$file"
}

update_android_gradle_file() {
    file="$1"
    version_code="$2"
    version_name="$3"

    old_code="$(awk '/^[[:space:]]*versionCode[[:space:]]+[0-9]+[[:space:]]*$/ { print $2; exit }' "${REPO_ROOT}/${file}")"
    old_name="$(awk 'match($0, /^[[:space:]]*versionName[[:space:]]+"[^"]+"/) { line=$0; sub(/^.*versionName[[:space:]]+"/, "", line); sub(/".*$/, "", line); print line; exit }' "${REPO_ROOT}/${file}")"

    [ -n "$old_code" ] || die "could not find versionCode in $file"
    [ -n "$old_name" ] || die "could not find versionName in $file"

    print_change "android" "$file" "versionCode" "$old_code" "$version_code"
    print_change "android" "$file" "versionName" "$old_name" "$version_name"

    if [ "$DRY_RUN" = "0" ]; then
        awk -v code="$version_code" -v name="$version_name" '
            /^[[:space:]]*versionCode[[:space:]]+[0-9]+[[:space:]]*$/ && !done_code {
                sub(/versionCode[[:space:]]+[0-9]+/, "versionCode " code)
                done_code=1
            }
            /^[[:space:]]*versionName[[:space:]]+"[^"]+"/ && !done_name {
                sub(/versionName[[:space:]]+"[^"]+"/, "versionName \"" name "\"")
                done_name=1
            }
            { print }
            END {
                if (!done_code || !done_name) {
                    exit 42
                }
            }
        ' "${REPO_ROOT}/${file}" | write_temp_file "${REPO_ROOT}/${file}"
    fi
}

update_linux_cmake_file() {
    file="$1"
    version="$2"

    old_project="$(awk 'match($0, /project\(ffmpeg-kit-linux-test VERSION [^)]+\)/) { line=$0; sub(/^.*VERSION /, "", line); sub(/\).*$/, "", line); print line; exit }' "${REPO_ROOT}/${file}")"
    old_pkg="$(awk 'match($0, /ffmpeg-kit=[^)[:space:]]+/) { line=$0; sub(/^.*ffmpeg-kit=/, "", line); sub(/[)[:space:]].*$/, "", line); print line; exit }' "${REPO_ROOT}/${file}")"

    [ -n "$old_project" ] || die "could not find project VERSION in $file"
    [ -n "$old_pkg" ] || die "could not find ffmpeg-kit pkg version in $file"

    print_change "linux" "$file" "project VERSION" "$old_project" "$version"
    print_change "linux" "$file" "ffmpeg-kit pkg version" "$old_pkg" "$version"

    if [ "$DRY_RUN" = "0" ]; then
        awk -v version="$version" '
            /project\(ffmpeg-kit-linux-test VERSION [^)]+\)/ && !done_project {
                sub(/project\(ffmpeg-kit-linux-test VERSION [^)]+\)/, "project(ffmpeg-kit-linux-test VERSION " version ")")
                done_project=1
            }
            /ffmpeg-kit=[^)[:space:]]+/ && !done_pkg {
                sub(/ffmpeg-kit=[^)[:space:]]+/, "ffmpeg-kit=" version)
                done_pkg=1
            }
            { print }
            END {
                if (!done_project || !done_pkg) {
                    exit 42
                }
            }
        ' "${REPO_ROOT}/${file}" | write_temp_file "${REPO_ROOT}/${file}"
    fi
}

update_flutter_pubspec_file() {
    file="$1"
    version="$2"

    old_version="$(awk '/^version:[[:space:]]*[0-9]+(\.[0-9]+){1,2}[[:space:]]*$/ { print $2; exit }' "${REPO_ROOT}/${file}")"
    [ -n "$old_version" ] || die "could not find version in $file"

    print_change "flutter" "$file" "version" "$old_version" "$version"

    if [ "$DRY_RUN" = "0" ]; then
        awk -v version="$version" '
            /^version:[[:space:]]*[0-9]+(\.[0-9]+){1,2}[[:space:]]*$/ && !done_version {
                print "version: " version
                done_version=1
                next
            }
            { print }
            END {
                if (!done_version) {
                    exit 42
                }
            }
        ' "${REPO_ROOT}/${file}" | write_temp_file "${REPO_ROOT}/${file}"
    fi
}

update_flutter_gradle_file() {
    file="$1"
    version_code="$2"
    version_name="$3"

    old_code="$(awk -F"'" '/^[[:space:]]*flutterVersionCode[[:space:]]*=/ { print $2; exit }' "${REPO_ROOT}/${file}")"
    old_name="$(awk -F"'" '/^[[:space:]]*flutterVersionName[[:space:]]*=/ { print $2; exit }' "${REPO_ROOT}/${file}")"

    [ -n "$old_code" ] || die "could not find flutterVersionCode in $file"
    [ -n "$old_name" ] || die "could not find flutterVersionName in $file"

    print_change "flutter" "$file" "flutterVersionCode" "$old_code" "$version_code"
    print_change "flutter" "$file" "flutterVersionName" "$old_name" "$version_name"

    if [ "$DRY_RUN" = "0" ]; then
        awk -v code="$version_code" -v name="$version_name" '
            /^[[:space:]]*flutterVersionCode[[:space:]]*=/ && !done_code {
                indent=$0
                sub(/[^[:space:]].*$/, "", indent)
                print indent "flutterVersionCode = \047" code "\047"
                done_code=1
                next
            }
            /^[[:space:]]*flutterVersionName[[:space:]]*=/ && !done_name {
                indent=$0
                sub(/[^[:space:]].*$/, "", indent)
                print indent "flutterVersionName = \047" name "\047"
                done_name=1
                next
            }
            { print }
            END {
                if (!done_code || !done_name) {
                    exit 42
                }
            }
        ' "${REPO_ROOT}/${file}" | write_temp_file "${REPO_ROOT}/${file}"
    fi
}

update_react_native_package_file() {
    file="$1"
    version="$2"

    old_version="$(awk 'match($0, /^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"[^"]+"/) { line=$0; sub(/^.*"version"[[:space:]]*:[[:space:]]*"/, "", line); sub(/".*$/, "", line); print line; exit }' "${REPO_ROOT}/${file}")"
    [ -n "$old_version" ] || die "could not find package version in $file"

    print_change "react-native" "$file" "package version" "$old_version" "$version"

    if [ "$DRY_RUN" = "0" ]; then
        awk -v version="$version" '
            /^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"[^"]+"/ && !done_version {
                sub(/"version"[[:space:]]*:[[:space:]]*"[^"]+"/, "\"version\": \"" version "\"")
                done_version=1
            }
            { print }
            END {
                if (!done_version) {
                    exit 42
                }
            }
        ' "${REPO_ROOT}/${file}" | write_temp_file "${REPO_ROOT}/${file}"
    fi
}

update_react_native_gradle_file() {
    file="$1"
    version_code="$2"
    version_name="$3"

    old_code="$(awk '/^[[:space:]]*versionCode[[:space:]]+[0-9]+[[:space:]]*$/ { print $2; exit }' "${REPO_ROOT}/${file}")"
    old_name="$(awk 'match($0, /^[[:space:]]*versionName[[:space:]]+"[^"]+"/) { line=$0; sub(/^.*versionName[[:space:]]+"/, "", line); sub(/".*$/, "", line); print line; exit }' "${REPO_ROOT}/${file}")"

    [ -n "$old_code" ] || die "could not find versionCode in $file"
    [ -n "$old_name" ] || die "could not find versionName in $file"

    print_change "react-native" "$file" "versionCode" "$old_code" "$version_code"
    print_change "react-native" "$file" "versionName" "$old_name" "$version_name"

    if [ "$DRY_RUN" = "0" ]; then
        awk -v code="$version_code" -v name="$version_name" '
            /^[[:space:]]*versionCode[[:space:]]+[0-9]+[[:space:]]*$/ && !done_code {
                sub(/versionCode[[:space:]]+[0-9]+/, "versionCode " code)
                done_code=1
            }
            /^[[:space:]]*versionName[[:space:]]+"[^"]+"/ && !done_name {
                sub(/versionName[[:space:]]+"[^"]+"/, "versionName \"" name "\"")
                done_name=1
            }
            { print }
            END {
                if (!done_code || !done_name) {
                    exit 42
                }
            }
        ' "${REPO_ROOT}/${file}" | write_temp_file "${REPO_ROOT}/${file}"
    fi
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -p|--platform)
            [ "$#" -ge 2 ] || die "--platform requires a value"
            PLATFORM="$(normalize_platform "$2")"
            shift 2
            ;;
        --platform=*)
            PLATFORM="$(normalize_platform "${1#*=}")"
            shift
            ;;
        --dry-run)
            DRY_RUN="1"
            shift
            ;;
        --android-version-code)
            [ "$#" -ge 2 ] || die "--android-version-code requires a value"
            ANDROID_VERSION_CODE="$2"
            shift 2
            ;;
        --android-version-code=*)
            ANDROID_VERSION_CODE="${1#*=}"
            shift
            ;;
        --android-code-prefix)
            [ "$#" -ge 2 ] || die "--android-code-prefix requires a value"
            ANDROID_CODE_PREFIX="$2"
            shift 2
            ;;
        --android-code-prefix=*)
            ANDROID_CODE_PREFIX="${1#*=}"
            shift
            ;;
        --flutter-version-code)
            [ "$#" -ge 2 ] || die "--flutter-version-code requires a value"
            FLUTTER_VERSION_CODE="$2"
            shift 2
            ;;
        --flutter-version-code=*)
            FLUTTER_VERSION_CODE="${1#*=}"
            shift
            ;;
        --react-native-version-code)
            [ "$#" -ge 2 ] || die "--react-native-version-code requires a value"
            REACT_NATIVE_VERSION_CODE="$2"
            shift 2
            ;;
        --react-native-version-code=*)
            REACT_NATIVE_VERSION_CODE="${1#*=}"
            shift
            ;;
        --)
            shift
            break
            ;;
        -*)
            die "unknown option: $1"
            ;;
        *)
            [ -z "$VERSION" ] || die "unexpected extra argument: $1"
            VERSION="$1"
            shift
            ;;
    esac
done

while [ "$#" -gt 0 ]; do
    [ -z "$VERSION" ] || die "unexpected extra argument: $1"
    VERSION="$1"
    shift
done

[ -n "$VERSION" ] || {
    usage >&2
    exit 1
}

validate_version "$VERSION"
is_positive_integer "$ANDROID_CODE_PREFIX" || die "--android-code-prefix must contain only digits"

COMPACT_CODE="$(compact_version_code "$VERSION")"

if [ -z "$ANDROID_VERSION_CODE" ]; then
    ANDROID_VERSION_CODE="$(derive_android_version_code "$VERSION")"
fi
if [ -z "$FLUTTER_VERSION_CODE" ]; then
    FLUTTER_VERSION_CODE="$COMPACT_CODE"
fi
if [ -z "$REACT_NATIVE_VERSION_CODE" ]; then
    REACT_NATIVE_VERSION_CODE="$COMPACT_CODE"
fi

is_positive_integer "$ANDROID_VERSION_CODE" || die "--android-version-code must contain only digits"
is_positive_integer "$FLUTTER_VERSION_CODE" || die "--flutter-version-code must contain only digits"
is_positive_integer "$REACT_NATIVE_VERSION_CODE" || die "--react-native-version-code must contain only digits"

printf 'Version update%s\n' "$([ "$DRY_RUN" = "1" ] && printf ' (dry run)' || printf '')"
printf '  repository: %s\n' "$REPO_ROOT"
printf '  platform:   %s\n' "$PLATFORM"
printf '  version:    %s\n' "$VERSION"

if should_update_platform "android"; then
    printf '  android versionCode:      %s\n' "$ANDROID_VERSION_CODE"
fi
if should_update_platform "flutter"; then
    printf '  flutterVersionCode:       %s\n' "$FLUTTER_VERSION_CODE"
fi
if should_update_platform "react-native"; then
    printf '  react-native versionCode: %s\n' "$REACT_NATIVE_VERSION_CODE"
fi

printf '\n%-13s %-58s %-26s %s\n' "platform" "file" "field" "old -> new"
printf '%-13s %-58s %-26s %s\n' "--------" "----" "-----" "----------"

if should_update_platform "android"; then
    update_android_gradle_file "android/test-app-java/build.gradle" "$ANDROID_VERSION_CODE" "$VERSION"
    update_android_gradle_file "android/test-app-kotlin/build.gradle" "$ANDROID_VERSION_CODE" "$VERSION"
fi

if should_update_platform "linux"; then
    update_linux_cmake_file "linux/CMakeLists.txt" "$VERSION"
fi

if should_update_platform "flutter"; then
    update_flutter_pubspec_file "flutter/test-app-podspec/pubspec.yaml" "$VERSION"
    update_flutter_gradle_file "flutter/test-app-podspec/android/app/build.gradle" "$FLUTTER_VERSION_CODE" "$VERSION"
    update_flutter_gradle_file "flutter/test-app-spm/android/app/build.gradle" "$FLUTTER_VERSION_CODE" "$VERSION"
    update_flutter_pubspec_file "flutter/test-app-spm/pubspec.yaml" "$VERSION"
fi

if should_update_platform "react-native"; then
    update_react_native_package_file "react-native/package.json" "$VERSION"
    update_react_native_gradle_file "react-native/android/app/build.gradle" "$REACT_NATIVE_VERSION_CODE" "$VERSION"
fi
