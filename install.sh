#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

#   ██╗    ██╗██╗ ██████╗ ██████╗
#   ██║    ██║██║██╔═══██╗██╔══██╗
#   ██║ █╗ ██║██║██║   ██║██║  ██║
#   ██║███╗██║██║██║▄▄ ██║██║  ██║
#   ╚███╔███╔╝██║╚██████╔╝██████╔╝
#    ╚══╝╚══╝ ╚═╝ ╚══▀▀═╝ ╚═════╝
#
# wiqd Installer (macOS / Linux)
# Usage: curl -fsSL https://aka.ms/wiqd/install.sh | bash
#
# Or for safer review-before-run:
#   curl -fsSL https://aka.ms/wiqd/install.sh -o install.sh
#   cat install.sh   # review
#   bash install.sh  # run
#
# Installs the wiqd CLI and all dependencies:
#   1. Node.js LTS (if not already installed)
#   2. @microsoft/wiqd (npm global package — includes extension payloads;
#      Work IQ and eval install lazily when their related wiqd command first runs)
#   3. Verify installation (`wiqd doctor` may report those managed CLIs as
#      not-yet-used; run the related command to install its exact extension pin)
#   4. Work IQ VS Code extension (optional)
#   5. wiqd plugin — installed only for the plugin host(s) already on PATH
#      (Copilot CLI and/or Claude Code). Never installs a host; skipped
#      gracefully when neither is present. Skip entirely with --skip-plugin.
#
# Sources:
#   --source npm   Install from the npm registry (default)
#
# Requires: Internet access, curl or wget.

set -euo pipefail

# ─────────────────────────────────────────────
# Defaults
# ─────────────────────────────────────────────

SOURCE="npm"
VERSION="latest"
REPO="microsoft/wiqd"
SKIP_VSCODE=false
SKIP_PLUGIN=false
PLUGIN_NON_FATAL=false
INSIDERS=false
NODE_VERSION="24"
FORCE=false
MIN_NODE_VERSION="24.15.0"
WIQD_PACKAGE="@microsoft/wiqd"

# The canonical public npm registry. Named once so the probe and the install
# that must be pinned to it can never drift apart.
PUBLIC_NPM_REGISTRY="https://registry.npmjs.org/"

# Extra npm arguments appended to every global install. Empty by default, so a
# plain install honours whatever registry (corporate proxy, mirror) the machine
# is configured with. Declared here, in the shared area, so it is always an
# initialized empty array in the generated public installer where no setter
# ever runs — an unset read under `set -u` would otherwise be fatal.
NPM_REGISTRY_ARGS=()
LAST_NPM_ERROR_CODE=""
LAST_NPM_REGISTRY=""
LAST_NPM_MISSING_SPEC=""
NPM_INSTALL_REGISTRY=""
NPM_INSTALL_REGISTRY_SCOPE=""
NPM_SUPPRESS_FAILURE_DIAGNOSTICS=false
VSCODE_EXTENSION_ID="Microsoft.wiqd"
# Some install paths activate additional extensions as part of the same run,
# so the plugin-compose step below must force a rebuild even when `wiqd`
# itself is already up to date (a plain compose would otherwise leave the
# previously-composed skill set deployed). Declared here, in the shared area,
# so it evaluates to false in the 3P mirror where no setter ever runs.
plugin_force_recompose=false

# The plugin step is a loop over possibly-multiple hosts (copilot, claude), so
# "succeeded" (>=1 host installed cleanly) and "failed" (>=1 host errored) are
# tracked separately from install_success. A host being ABSENT is a graceful
# skip, never a failure; only an attempted-and-errored install trips failed.
# plugin_install_failed/succeeded/skipped/cancelled (+ failed_plugin_hosts)
# drive the summary banners, the skills-list gate, and the final exit code.
plugin_install_failed=false
plugin_install_succeeded=false
plugin_install_skipped=false
plugin_install_cancelled=false
failed_plugin_hosts=()

# Stamped by sync-version.ps1 — do not edit manually.
WIQD_INSTALLER_VERSION="0.13.1"

# ─────────────────────────────────────────────
# Parse arguments
# ─────────────────────────────────────────────

usage_error() {
    echo "ERROR: $1" >&2
    echo "Run with --help for usage information." >&2
}

require_option_value() {
    if [[ $# -lt 2 ]]; then
        usage_error "$1 requires a value"
        exit 1
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --source)
            require_option_value "$@"
            SOURCE="$2"
            if [[ "$SOURCE" != "npm" ]]; then
                echo "ERROR: --source must be 'npm'" >&2
                exit 1
            fi
            shift 2
            ;;
        --version)
            require_option_value "$@"
            VERSION="$2"
            shift 2
            ;;
        --repo)
            require_option_value "$@"
            REPO="$2"
            shift 2
            ;;
        --skip-vscode)
            SKIP_VSCODE=true
            shift
            ;;
        --skip-plugin)
            SKIP_PLUGIN=true
            shift
            ;;
        # internal: wiqd update passes this so a plugin-only failure is non-fatal
        --plugin-non-fatal)
            PLUGIN_NON_FATAL=true
            shift
            ;;
        --insiders)
            INSIDERS=true
            shift
            ;;
        --node-version)
            require_option_value "$@"
            NODE_VERSION="$2"
            shift 2
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --help|-h)
            echo "Usage: install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --source <npm>           Installation source (default: npm)"
            echo "  --version <version>      Specific version to install (default: latest)"
            echo "  --repo <owner/repo>      GitHub repository (default: microsoft/wiqd)"
            echo "  --skip-vscode            Skip VS Code extension installation"
            echo "  --skip-plugin            Skip Copilot CLI plugin installation"
            echo "  --insiders               Install extension in VS Code Insiders"
            echo "  --node-version <ver>     Node.js major version (default: 24)"
            echo "  --force                  Reinstall even if already present"
            echo "  --help                   Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Run with --help for usage information." >&2
            exit 1
            ;;
    esac
done

# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────

# ANSI color codes — disabled when stdout is not a TTY (e.g., piped or in CI)
if [ -t 1 ]; then
    YELLOW='\033[0;33m'
    GREEN='\033[0;32m'
    WHITE='\033[1;37m'
    RED='\033[0;31m'
    CYAN='\033[0;36m'
    DIM='\033[2m'
    GRAY='\033[0;90m'
    RESET='\033[0m'
else
    YELLOW=''
    GREEN=''
    WHITE=''
    RED=''
    CYAN=''
    DIM=''
    GRAY=''
    RESET=''
fi

write_step()  { printf "${YELLOW}[%s/%s] %s${RESET}\n" "$1" "$2" "$3"; }
write_ok()    { printf "${GREEN} %s${RESET}\n" "$1"; }
write_info()  { printf "${WHITE} %s${RESET}\n" "$1"; }
write_warn()  { printf "${YELLOW} %s${RESET}\n" "$1"; }
write_err()   { printf "${RED} ERROR: %s${RESET}\n" "$1"; }
write_hint()  { printf "${GRAY} %s${RESET}\n" "$1"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

# Sanitize captured subprocess output before echoing it to a terminal or CI
# log. npm relays arbitrary transitive lifecycle-script output verbatim, so a
# hostile or buggy package can embed ANSI/OSC escape sequences that retitle the
# window, move the cursor, clear the screen, or forge log lines in a watching
# console. Strip well-formed CSI escape sequences, then drop every remaining C0
# control byte (including any lone ESC/BEL, which neutralizes OSC sequences)
# while keeping tab/newline/carriage-return, and finally cap the volume so a
# pathological multi-megabyte error dump cannot flood the console. Uses only
# POSIX sed/tr so it behaves identically under BSD (macOS) and GNU tools and
# stays bash-3.2 safe.
sanitize_terminal_output() {
    local esc; esc=$(printf '\033')
    printf '%s' "$1" \
        | LC_ALL=C sed "s|${esc}\[[0-9;?]*[ -/]*[@-~]||g" \
        | LC_ALL=C tr -d '\000-\010\013\014\016-\037\177' \
        | tail -c 8192
}

safe_registry_label() {
    local sanitized origin
    sanitized=$(sanitize_terminal_output "${1:-}")
    origin=$(printf '%s' "$sanitized" \
        | LC_ALL=C sed -nE 's#^(https?://)([^/@]+@)?([A-Za-z0-9.-]+(:[0-9]+)?)(/.*)?$#\1\3#p')
    if [[ -n "$origin" ]]; then
        printf '%s' "$origin"
    else
        printf '%s' "configured npm registry"
    fi
}

sanitize_npm_output() {
    local redacted
    redacted=$(printf '%s' "$1" \
        | LC_ALL=C sed -E \
            -e 's#(https?://)[^/@[:space:]]+@#\1#g' \
            -e 's#([?&](access_token|token|auth|password|passwd|apikey|api_key)=)[^&[:space:]]+#\1[REDACTED]#g')
    sanitize_terminal_output "$redacted"
}


# Deprecated npm config keys (npm 10.x).
DEPRECATED_NPM_CONFIG_KEYS=(
    "always-auth"
    "cache-min" "cache-max"
    "cache-lock-stale" "cache-lock-wait" "cache-lock-retries"
    "production" "optional" "dev"
)

# Sentinel: empty = not yet checked, "none" = none found, otherwise space-
# separated list of detected deprecated keys. Cached to fire only once.
NPM_CONFIG_DEPRECATION_RESULT=""

# Reads ~/.npmrc directly (NOT `npm config list` — that command itself emits
# the deprecation warnings we're trying to surface, re-triggering the very
# stderr-noise class we're guarding against). Echoes the deprecated keys
# found, space-separated; empty when none.
test_npm_config_deprecation() {
    if [[ -n "$NPM_CONFIG_DEPRECATION_RESULT" ]]; then
        if [[ "$NPM_CONFIG_DEPRECATION_RESULT" == "none" ]]; then
            return 0
        fi
        echo "$NPM_CONFIG_DEPRECATION_RESULT"
        return 0
    fi

    local found=()
    local npmrc="${HOME}/.npmrc"
    if [[ -f "$npmrc" ]]; then
        local key
        while IFS='=' read -r raw_key _; do
            # Strip whitespace and comment lines.
            local trimmed="${raw_key#"${raw_key%%[![:space:]]*}"}"
            trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
            [[ -z "$trimmed" || "$trimmed" == \#* || "$trimmed" == \;* ]] && continue
            key="$trimmed"
            for deprecated in "${DEPRECATED_NPM_CONFIG_KEYS[@]}"; do
                if [[ "$key" == "$deprecated" ]]; then
                    # Avoid duplicates.
                    local already=false
                    local f
                    for f in "${found[@]:-}"; do
                        if [[ "$f" == "$key" ]]; then
                            already=true
                            break
                        fi
                    done
                    if ! $already; then
                        found+=("$key")
                    fi
                fi
            done
        done < "$npmrc"
    fi

    if [[ ${#found[@]} -eq 0 ]]; then
        NPM_CONFIG_DEPRECATION_RESULT="none"
        return 0
    fi

    NPM_CONFIG_DEPRECATION_RESULT="${found[*]}"
    echo "$NPM_CONFIG_DEPRECATION_RESULT"
}

# Surfaces the yellow warning about deprecated npmrc keys ONCE per script
# invocation, before any npm call runs. Non-fatal — the install proceeds
# regardless of cleanup.
show_npm_config_deprecation_warning() {
    local result
    result=$(test_npm_config_deprecation)
    [[ -z "$result" ]] && return 0

    echo ""
    write_warn "Deprecated npm config keys detected in ~/.npmrc:"
    local key
    for key in $result; do
        printf "${YELLOW}     %s${RESET}\n" "$key"
    done
    write_hint "  These trigger npm warnings that may clutter installer output."
    write_hint "  Cleanup (run for each key above): npm config delete <key>"
    echo ""
}


download_to_stdout() {
    local url="$1"
    if command_exists curl; then
        curl -fsSL "$url"
    elif command_exists wget; then
        wget -qO- "$url"
    else
        return 1
    fi
}

can_prompt_on_tty() {
    [[ -z "${CI:-}" && -r /dev/tty && -w /dev/tty ]]
}


# Compare semver versions: returns 0 if $1 >= $2
version_gte() {
    local IFS=.
    local i ver1=($1) ver2=($2)
    for ((i=0; i<${#ver2[@]}; i++)); do
        local v1="${ver1[i]:-0}"
        local v2="${ver2[i]:-0}"
        if ((v1 > v2)); then return 0; fi
        if ((v1 < v2)); then return 1; fi
    done
    return 0
}

get_node_version() {
    if command_exists node; then
        local raw
        raw=$(node --version 2>/dev/null || true)
        echo "${raw#v}"
    fi
    return 0
}

get_os() {
    local uname_s
    uname_s=$(uname -s)
    case "$uname_s" in
        Darwin) echo "macos" ;;
        Linux)  echo "linux" ;;
        *)      echo "unknown" ;;
    esac
}


# ─────────────────────────────────────────────
# Quick Start helpers
# ─────────────────────────────────────────────

# R32: npm's "already installed" decision is metadata-only — it never checksums
# the extracted tree, so an interrupted install can leave @microsoft/wiqd
# registered-but-incomplete while the version-skip gate still fires. This checks
# the two artifacts that MUST exist and be non-empty for the CLI to run: the bin
# launcher and the esbuild bundle. Transitive deps, seeded config, and
# package.json are deliberately excluded (pruned deps produce false positives;
# package.json is what npm already trusts). Prints one missing-or-empty artifact
# path per line and returns 1 when the install is incomplete; returns 0 (no
# output) when complete. Fails closed (reports incomplete) when the npm global
# root can't be resolved rather than passing blind.
test_wiqd_install_complete() {
    if ! command_exists npm; then
        echo "npm (could not resolve npm global root)"
        return 1
    fi

    local npm_root
    npm_root=$(npm root -g --loglevel=error 2>/dev/null || true)
    npm_root="${npm_root%$'\n'}"
    if [[ -z "$npm_root" ]]; then
        echo "npm (could not resolve npm global root)"
        return 1
    fi

    local incomplete=1
    local artifact
    for artifact in \
        "$npm_root/$WIQD_PACKAGE/bin/wiqd.js" \
        "$npm_root/$WIQD_PACKAGE/dist/wiqd-cli.cjs"; do
        if [[ ! -s "$artifact" ]]; then
            echo "$artifact"
            incomplete=0
        fi
    done

    [[ "$incomplete" == "1" ]]
}

get_wiqd_installed_skills() {
    # Reads installed skill names from the globally-installed wiqd package and
    # its bundled extensions. Skills live in two places:
    #   1. $npm_root/@microsoft/wiqd/plugin/skills/
    #   2. $npm_root/@microsoft/wiqd/extensions/wiqd-ext-*/skills/
    # We collect names from both locations (bundle first) and let `sort -u`
    # dedupe: since duplicates are exact-string basename matches, sort -u is
    # byte-identical to a first-wins map without needing a bash-4 associative
    # array (avoided for macOS's default bash 3.2 compatibility).
    if ! command_exists npm; then
        return 0
    fi

    local npm_root
    npm_root=$(npm root -g --loglevel=error 2>/dev/null || true)
    npm_root="${npm_root%$'\n'}"
    if [[ -z "$npm_root" ]]; then
        return 0
    fi

    local dir name
    local skill_names=()

    # 1. Bundle skills (wins on conflicts).
    local bundle_skills="$npm_root/@microsoft/wiqd/plugin/skills"
    if [[ -d "$bundle_skills" ]]; then
        for dir in "$bundle_skills"/*; do
            [[ -d "$dir" ]] || continue
            name="${dir##*/}"
            [[ "$name" == _* ]] && continue
            skill_names+=("$name")
        done
    fi

    # 2. Extension-contributed skills (alphabetic discovery order, first wins).
    local ext_root="$npm_root/@microsoft/wiqd/extensions"
    if [[ -d "$ext_root" ]]; then
        local ext_dir ext_skills
        for ext_dir in "$ext_root"/wiqd-ext-*; do
            [[ -d "$ext_dir" ]] || continue
            ext_skills="$ext_dir/skills"
            [[ -d "$ext_skills" ]] || continue
            for dir in "$ext_skills"/*; do
                [[ -d "$dir" ]] || continue
                name="${dir##*/}"
                [[ "$name" == _* ]] && continue
                skill_names+=("$name")
            done
        done
    fi

    if (( ${#skill_names[@]} > 0 )); then
        printf '%s\n' "${skill_names[@]}" | sort -u
    fi
}

# Renders the closing Quick Start block. Kept compact and helper-driven to
# minimize merge conflicts with in-flight installer edits. Must mirror
# the PowerShell installer's Write-WiqdQuickstart output character-for-character
# (diff between the two is shell-idiom only: printf vs Write-Host).
print_wiqd_quickstart() {
    local installed_skills=()
    while IFS= read -r skill; do
        [[ -n "$skill" ]] && installed_skills+=("$skill")
    done < <(get_wiqd_installed_skills)

    local copilot_present=false claude_present=false
    if command_exists copilot; then copilot_present=true; fi
    if command_exists claude; then claude_present=true; fi

    printf "${CYAN} Quick Start:${RESET}\n"
    printf "${WHITE}   wiqd agent create --name my-agent              Create a new agent${RESET}\n"
    printf "${WHITE}   wiqd agent validate                            Validate your agent${RESET}\n"
    printf "${WHITE}   wiqd agent provision --env local               Deploy locally${RESET}\n"
    echo ""
    if $copilot_present; then
        printf "${CYAN} Or with Copilot CLI (interactive mode):${RESET}\n"
        printf "${WHITE}   copilot -i \"create a new declarative agent\"${RESET}\n"
        printf "${WHITE}   copilot -i \"validate my agent\"${RESET}\n"
        printf "${WHITE}   copilot -i \"deploy my agent locally\"${RESET}\n"
        echo ""
    elif $claude_present; then
        printf "${CYAN} Or in Claude Code — the wiqd plugin's slash commands are available.${RESET}\n"
        echo ""
    fi
    if $copilot_present || $claude_present; then
        # Gate the skills list on the plugin step actually SUCCEEDING this run,
        # never on host presence alone — get_wiqd_installed_skills reads the npm
        # bundle on disk, which exists regardless of whether `wiqd component
        # plugin install` ever ran or failed, so host-presence-only gating
        # produced a phantom list. Require a CLEAN run (succeeded AND not
        # failed): in a multi-host loop one host can succeed while another
        # fails, and the bundle-derived list has no way to attribute skills to
        # a specific host, so ANY attempted failure must suppress the blanket
        # list rather than overstate success next to a partial-install banner.
        if $plugin_install_succeeded && ! $plugin_install_failed && ! $plugin_install_cancelled; then
            printf "${CYAN} Installed wiqd skills:${RESET}\n"
            local name
            if (( ${#installed_skills[@]} > 0 )); then
                for name in "${installed_skills[@]}"; do
                    printf "${WHITE}   /%s${RESET}\n" "$name"
                done
            else
                printf "${GRAY}   (No installed skills detected — see https://aka.ms/wiqd/docs)${RESET}\n"
            fi
            echo ""
        elif ! $plugin_install_skipped && ! $plugin_install_cancelled; then
            printf "${YELLOW} wiqd skills are not installed for this host yet.${RESET}\n"
            # Prefer a host we KNOW failed over the present-host fallback, so a
            # mixed-host run (one succeeded, one failed) points the retry hint
            # at the host that actually needs it instead of a working one.
            local retry_host="claude"
            if $copilot_present; then retry_host="copilot"; fi
            if (( ${#failed_plugin_hosts[@]} > 0 )); then retry_host="${failed_plugin_hosts[0]}"; fi
            printf "${WHITE}   Run 'wiqd component plugin install --cli %s' to install them${RESET}\n" "$retry_host"
            echo ""
        fi
    else
        printf "${CYAN} To use wiqd inside an agent, install Copilot CLI or Claude Code, then run:${RESET}\n"
        printf "${WHITE}   wiqd component plugin install    (add --cli claude for Claude Code)${RESET}\n"
        echo ""
    fi
    printf "${CYAN} Documentation:${RESET}\n"
    printf "${WHITE}   https://aka.ms/wiqd/docs${RESET}\n"
    echo ""
}

# Returns 0 (true) when the installer is allowed to prompt interactively.
# Falls closed: any failed test → not interactive. The
# probe MUST use /dev/tty (not [ -t 0 ]) because the most common public-
# installer invocation form `curl ... | bash` pipes the SCRIPT through
# stdin — so -t 0 is false even though the user has a controlling
# terminal. Mirrors can_prompt_on_tty. Public island: both 1P and 3P
# installers gate their EULA prompt on this function, so it must survive
# the mirror strip. NON_INTERACTIVE defaults to false under set -u since
# the 3P installer never defines it. The check below is a STRING compare,
# not a truth-value command execution: in the generated public installer the
# NON_INTERACTIVE=false default and the --non-interactive flag parser are
# both stripped out of the public build, so this value comes entirely from
# the caller's environment. Running it as a command (the old `if
# ${VAR:-false};` form) would execute whatever the caller set NON_INTERACTIVE
# to — e.g. the widespread `NON_INTERACTIVE=1` convention runs `1` (command
# not found, falls through to interactive) and an arbitrary string is
# outright eval'd.
is_installer_interactive() {
    if [[ "${NON_INTERACTIVE:-false}" == "true" ]]; then return 1; fi
    [[ -z "${CI:-}" ]] || return 1
    [[ -z "${WIQD_INSTALLER_NON_INTERACTIVE:-}" ]] || return 1
    [[ -r /dev/tty && -w /dev/tty ]]
}

# ─────────────────────────────────────────────
# Installation helpers
# ─────────────────────────────────────────────

install_npm_global_packages() {
    # The ONE `npm install -g` primitive for every install source: every
    # registry-name or local-tarball install funnels through here with an
    # ORDERED spec list. Call as:
    #   install_npm_global_packages <display_name> <spec1> [<spec2> ...]
    # When two specs are given, order matters — pass the host tarball/name FIRST
    # and any dependent tarball SECOND so the dependent's exact host-version pin
    # resolves from the co-installed local tarball instead of the registry.
    local display_name="${1:-wiqd}"
    shift || true
    local packages=("$@")

    # R35: reset the EEXIST file-conflict flag at the start of every install
    # attempt. It is reset here inside the shared primitive (not at top level)
    # so it always initializes even where top-level globals are stripped from
    # the generated public installer — under set -u an unset read in the
    # auto-mode guard would otherwise be fatal.
    NPM_INSTALL_CONFLICT=0
    # R35: same for the EACCES/EPERM permission flag — reset here so it is
    # always initialized under set -u in the stripped public installer.
    NPM_INSTALL_PERMISSION=0

    write_info "Installing $display_name..."

    if ! command_exists npm; then
        write_warn "npm not found on PATH"
        return 1
    fi

    # Single plain global install. The published @microsoft/wiqd tarball no
    # longer declares bundledDependencies (its bundled extension stubs ship as
    # plain files under extensions/), so npm 11 reifies the full transitive tree on
    # the first pass and runs every install/postinstall script — including
    # @azure/msal-node-runtime's copyBinaries.js. No --ignore-scripts, no
    # in-dir backfill, no npm rebuild — a single-pass npm install.
    #
    # 2>&1 (not 2>/dev/null) so npm warnings don't crash the script via set -e,
    # AND so the success-line grep below can see real npm output.
    # --loglevel=error suppresses npm's own deprecation warnings.
    # NPM_REGISTRY_ARGS pins every 1P npm call to public npm. The guarded
    # expansion stays compatible with macOS's default bash 3.2.
    local npm_args=(install -g "${packages[@]}" ${NPM_REGISTRY_ARGS[@]+"${NPM_REGISTRY_ARGS[@]}"} --loglevel=error)
    if [[ -n "$NPM_INSTALL_REGISTRY" ]]; then
        npm_args+=(--registry "$NPM_INSTALL_REGISTRY")
        # A scoped package resolves through its `@scope:registry` config, which
        # takes precedence over the generic --registry flag; pin the scope too so
        # the attempt can't silently resolve against the user's scoped registry.
        if [[ -n "$NPM_INSTALL_REGISTRY_SCOPE" ]]; then
            npm_args+=("--${NPM_INSTALL_REGISTRY_SCOPE}:registry=$NPM_INSTALL_REGISTRY")
        fi
    fi

    LAST_NPM_ERROR_CODE=""
    LAST_NPM_REGISTRY="$NPM_INSTALL_REGISTRY"
    LAST_NPM_MISSING_SPEC=""
    local npm_output
    if ! npm_output=$(npm "${npm_args[@]}" 2>&1); then
        # Capture the npm error code (e.g. E404) before any classification so the
        # auto-mode caller can offer an actionable registry-retry / recovery hint.
        LAST_NPM_ERROR_CODE=$(printf '%s\n' "$npm_output" \
            | grep -Eio 'npm (error|ERR!) code E[A-Z0-9]+' \
            | awk '{print toupper($NF)}' \
            | head -1 || true)
        # npm has used both legacy and current wording for the unresolved spec.
        # Capture either form so dependency failures are not blamed on the root.
        LAST_NPM_MISSING_SPEC=$(printf '%s\n' "$npm_output" \
            | LC_ALL=C sed -nE \
                -e "s/.*404[[:space:]]+'([^']+)'[[:space:]]+is not in this registry.*/\1/p" \
                -e "s/.*The requested resource[[:space:]]+'([^']+)'[[:space:]]+could not be found.*/\1/p" \
            | head -1 || true)
        # Classify an EEXIST file conflict distinctly from a network/registry
        # failure (R35). npm aborts the whole global install with EEXIST when a
        # launcher target already exists but isn't owned by the installing
        # package — a purely LOCAL problem the GitHub/EMU fallback can't fix (it
        # would hit the identical conflict). Name the exact conflicting file and
        # the removal command, raise the conflict flag so the auto-mode caller
        # skips the misleading network fallback, and stop. Delete nothing.
        if printf '%s' "$npm_output" | grep -q 'EEXIST'; then
            NPM_INSTALL_CONFLICT=1
            local conflict_path
            conflict_path=$(printf '%s' "$npm_output" | sed -n 's/^[[:space:]]*npm error path[[:space:]]*//p' | head -1 | tr -d '\r')
            write_err "npm install failed: a file already exists (EEXIST)."
            if [[ -n "$conflict_path" ]]; then
                write_hint "rm -f '$conflict_path'   (then re-run this installer)"
            fi
            return 1
        fi
        # Classify an EACCES/EPERM permission failure distinctly from a
        # network/registry failure (R35). npm aborts the global install when it
        # can't write to the global prefix — a purely LOCAL problem the
        # GitHub/EMU fallback can't fix. Lead with the npm-recommended remedy
        # (point npm at a user-writable prefix), offer elevation as the
        # alternative, and stop. Change nothing. npm itself discourages
        # `sudo npm install -g`, so re-running with sudo is the fallback, not
        # the headline.
        if printf '%s\n' "$npm_output" | grep -Eq 'npm (error|ERR!) code (EACCES|EPERM)' \
            && printf '%s\n' "$npm_output" | grep -Eq 'npm (error|ERR!) path .+'; then
            NPM_INSTALL_PERMISSION=1
            local npm_prefix
            npm_prefix=$(npm config get prefix --loglevel=error 2>/dev/null | head -1 | tr -d '\r' || true)
            write_err "npm install failed: permission denied on the npm global prefix (EACCES/EPERM)."
            write_hint "Point npm at a user-writable prefix, or re-run with sudo:"
            if [[ -n "$npm_prefix" ]]; then
                write_hint "  (current global prefix: $npm_prefix)"
            fi
            write_hint "  npm config set prefix <dir>   (then re-run this installer)"
            return 1
        fi
        if $NPM_SUPPRESS_FAILURE_DIAGNOSTICS; then
            return 1
        fi

        write_warn "npm install failed for $display_name"
        # Surface the captured npm output so the first failing run is
        # self-diagnosing; otherwise the real cause (e.g. an EACCES on the
        # global prefix) stays hidden behind the re-run hint. Route it through
        # sanitize_terminal_output first: npm relays untrusted transitive
        # lifecycle-script output, so strip terminal control sequences and cap
        # the volume before writing to stderr.
        [[ -n "$npm_output" ]] && sanitize_npm_output "$npm_output" >&2
        local registry_hint=""
        if [[ -n "$NPM_INSTALL_REGISTRY" \
            && "${NPM_INSTALL_REGISTRY%/}" == "${PUBLIC_NPM_REGISTRY%/}" ]]; then
            registry_hint=" --registry $PUBLIC_NPM_REGISTRY"
        fi
        write_hint "Re-run 'npm install -g ${packages[*]}${registry_hint}' to see the full npm error output."
        return 1
    fi

    local success_line
    success_line=$(echo "$npm_output" | grep -E "added|changed|up to date" | head -1 || true)

    if [[ -n "$success_line" ]]; then
        write_ok "$success_line"
    else
        write_ok "$display_name installed successfully"
    fi
    return 0
}

# Seed the default extension registrations at install time via the host's own
# hidden `wiqd ext seed-defaults` command. Activation is registration-only:
# mere presence on disk never activates an
# extension, so the install path registers the defaults. The command is
# idempotent (the seededDefaults ledger gates each id), so a re-run never
# resurrects a default the user removed and a second invocation is a no-op.
# Non-fatal: a hiccup leaves wiqd installed and recoverable via `wiqd doctor`.
seed_wiqd_defaults() {
    if wiqd ext seed-defaults >/dev/null 2>&1; then
        write_ok "Default extensions registered"
        return 0
    fi
    write_warn "Could not seed default extensions automatically."
    write_hint "Run 'wiqd doctor' to restore them, or 'wiqd ext add <id>' per default."
    return 1
}

extensions_check_has_id() {
    local status="$1" message="$2" list_name="$3" expected_id="$4"
    [[ "$list_name" != "active" || "$status" != "error" ]] || return 1

    local listed_ids candidate
    local -a candidates
    listed_ids=$(printf '%s\n' "$message" | sed -nE "s/(^|.*; )[0-9]+ ${list_name} \(([^)]*)\).*/\2/p")
    [[ -n "$listed_ids" ]] || return 1
    IFS=',' read -ra candidates <<< "$listed_ids"
    for candidate in "${candidates[@]}"; do
        candidate="${candidate#"${candidate%%[![:space:]]*}"}"
        candidate="${candidate%"${candidate##*[![:space:]]}"}"
        [[ "$candidate" == "$expected_id" ]] && return 0
    done
    return 1
}

# Renders the post-install dependency verdict for the downstream CLIs, sourced
# from `wiqd doctor --json` so the installer and doctor never disagree on presence.
# Severity is row-owned, NOT taken from doctor's status: a missing REQUIRED
# lifecycle backend is fatal and the caller must stop the install; a missing OPTIONAL dep
# (eval/workiq/EULA) degrades gracefully and only warns. Returns 0 to continue,
# 1 when a required dependency is missing (caller exits 1). Fails closed with
# the canonical reinstall hint when the probe is unavailable or its JSON can't
# be parsed. Node is guaranteed on PATH (Step 1) and wiqd is itself a
# node CLI, so it parses the envelope into TAB-separated name/status/message.
show_dependency_status() {
    local json checks
    json=$(WIQD_INSTALLER_PROBE=1 WIQD_TELEMETRY=0 wiqd doctor --json 2>/dev/null || true)
    if [[ -z "$json" ]]; then
        write_err "Could not verify required downstream components."
        write_hint "Re-run: npm install -g @microsoft/wiqd"
        return 1
    fi
    checks=$(printf '%s' "$json" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const c=((JSON.parse(s).data)||{}).checks||[];for(const x of c)process.stdout.write(`${x.name||""}\t${x.status||""}\t${x.message||""}\n`);}catch(e){}});' 2>/dev/null || true)
    if [[ -z "$checks" ]]; then
        write_err "Could not verify required downstream components."
        write_hint "Re-run: npm install -g @microsoft/wiqd"
        return 1
    fi

    # Materialize the checks as ordered arrays so rows can consume matches
    # positionally. This matters when workiq is MISSING: doctor collapses BOTH
    # the "workiq --json" and "workiq EULA" checks to the bare name "workiq", so
    # matching by name alone would assign one entry to both rows. Consuming in
    # declaration order (probe before EULA) assigns each to the right row.
    local -a c_name=() c_status=() c_msg=() consumed=()
    local nm st ms
    while IFS=$'\t' read -r nm st ms; do
        [[ -z "$nm" ]] && continue
        c_name+=("$nm"); c_status+=("$st"); c_msg+=("$ms"); consumed+=(0)
    done <<< "$checks"

    # Display rows: "candidates::label::required::ok-word::note::extension-id::rerun::first-use".
    # Candidates are '|'-separated; `required=1` makes a miss fatal. An empty
    # check uses the extension id to print a registration repair; an emitted
    # failure uses doctor's own trimmed message and reinstalls wiqd's pinned deps.
    local active_backend_count=0 active_backend_id="" k
    for ((k = 0; k < ${#c_name[@]}; k++)); do
        [[ "${c_name[$k]}" == "Extensions" ]] || continue
        if [[ "${c_status[$k]}" != "error" ]] && extensions_check_has_id "${c_status[$k]}" "${c_msg[$k]}" active "microsoft.atk"; then
            active_backend_count=$((active_backend_count + 1)); active_backend_id="microsoft.atk"
        fi
        if [[ "${c_status[$k]}" != "error" ]] && extensions_check_has_id "${c_status[$k]}" "${c_msg[$k]}" active "microsoft.wiqd.core"; then
            active_backend_count=$((active_backend_count + 1)); active_backend_id="microsoft.wiqd.core"
        fi
        local inactive_backend_count=0 inactive_backend_id=""
        if extensions_check_has_id "${c_status[$k]}" "${c_msg[$k]}" inactive "microsoft.atk"; then
            inactive_backend_count=$((inactive_backend_count + 1)); inactive_backend_id="microsoft.atk"
        fi
        if extensions_check_has_id "${c_status[$k]}" "${c_msg[$k]}" inactive "microsoft.wiqd.core"; then
            inactive_backend_count=$((inactive_backend_count + 1)); inactive_backend_id="microsoft.wiqd.core"
        fi
        break
    done
    if [[ $active_backend_count -ne 1 ]]; then
        if [[ $active_backend_count -eq 0 && ${inactive_backend_count:-0} -eq 1 ]]; then
            write_err "Lifecycle backend extension is inactive."
            write_hint "Re-run: wiqd ext add ${inactive_backend_id}"
            return 1
        fi
        write_err "Could not determine the active lifecycle backend from wiqd doctor."
        write_hint "Run 'wiqd doctor' and ensure exactly one of microsoft.atk or microsoft.wiqd.core is active."
        return 1
    fi

    local backend_row="atk::atk::1::Installed::(required for \`wiqd agent\` commands)::::1"
    if [[ "$active_backend_id" == "microsoft.wiqd.core" ]]; then
        backend_row="Extensions::fx-core::1::Active::(required for \`wiqd agent\` commands)::::1"
    elif ! printf '%s\n' "${c_name[@]}" | grep -qxF 'atk'; then
        write_err "Could not verify the active ATK backend from wiqd doctor."
        write_hint "Run 'wiqd doctor' and repair the reported extension state."
        return 1
    fi
    local rows=(
        "$backend_row"
        "runevals::runevals::0::Installed::(optional - needed for \`wiqd agent eval\`)::microsoft.eval::1::wiqd agent eval"
        "workiq --json|workiq::workiq::0::Installed::(optional - needed for \`wiqd agent\` commands)::microsoft.workiq::1::wiqd agent list"
        "workiq EULA|workiq::workiq EULA::0::Accepted::::microsoft.workiq::0"
    )

    # Widest label (+ colon) governs alignment.
    local label_width=0 row
    local -a parts
    for row in "${rows[@]}"; do
        IFS=$'\x1e' read -ra parts <<< "${row//::/$'\x1e'}"
        (( ${#parts[1]} + 1 > label_width )) && label_width=$(( ${#parts[1]} + 1 ))
    done
    local cont_indent
    printf -v cont_indent '%*s' $(( label_width + 6 )) ''

    local all_ok=true fatal=false
    local out=""
    local cands label required okword note extension_id rerun first_use status message padded idx k cc is_ok repair
    local -a cand_arr
    for row in "${rows[@]}"; do
        IFS=$'\x1e' read -ra parts <<< "${row//::/$'\x1e'}"
        cands=${parts[0]}; label=${parts[1]}; required=${parts[2]}
        okword=${parts[3]}; note=${parts[4]}; extension_id=${parts[5]}; rerun=${parts[6]}; first_use=${parts[7]:-}

        # First unconsumed check whose name matches any candidate.
        IFS='|' read -ra cand_arr <<< "$cands"
        idx=-1
        for ((k = 0; k < ${#c_name[@]}; k++)); do
            [[ ${consumed[$k]} == 1 ]] && continue
            for cc in "${cand_arr[@]}"; do
                if [[ "${c_name[$k]}" == "$cc" ]]; then idx=$k; break; fi
            done
            [[ $idx -ge 0 ]] && break
        done
        if [[ $idx -ge 0 ]]; then
            consumed[$idx]=1; status=${c_status[$idx]}; message=${c_msg[$idx]}
        else
            status=""; message=""
        fi
        is_ok=false
        if [[ "$label" == "fx-core" ]]; then
            extensions_check_has_id "$status" "$message" active "microsoft.wiqd.core" && is_ok=true
        else
            [[ "$status" == "ok" ]] && is_ok=true
        fi
        if ! $is_ok; then
            all_ok=false
            [[ "$required" == "1" ]] && fatal=true
        fi

        printf -v padded '%-*s' "$label_width" "${label}:"
        if $is_ok; then
            if [[ -n "$note" ]]; then
                out+="${GREEN}   ✓ ${padded} ${okword}  ${note}${RESET}\n"
            else
                out+="${GREEN}   ✓ ${padded} ${okword}${RESET}\n"
            fi
            continue
        fi

        # Missing: required rows are a red ✗, optional rows a yellow ⚠.
        if [[ $idx -lt 0 && -n "$extension_id" ]]; then
            lead="Extension check unavailable (${extension_id} is inactive)."
        elif [[ $idx -lt 0 ]]; then
            lead="Required doctor check unavailable."
        else
            # Trim doctor's message to its lead clause (em-dash / sentence).
            lead=${message%% — *}
            lead=${lead%%. *}
            [[ -z "$lead" ]] && lead="Not found"
        fi
        if [[ "$required" == "1" ]]; then
            out+="${RED}   ✗ ${padded} ${lead}${RESET}\n"
        else
            out+="${YELLOW}   ⚠ ${padded} ${lead}${RESET}\n"
        fi
        if [[ "$rerun" == "1" ]]; then
            # Missing managed CLIs are a normal lazy-first-use state. Only a
            # doctor error means the extension package or its metadata needs
            # reinstalling rather than invoking the owning command.
            if [[ $idx -ge 0 && "$status" != "error" && -n "$first_use" ]]; then
                repair="$first_use"
            elif [[ $idx -lt 0 && -n "$extension_id" ]]; then
                repair="wiqd ext add ${extension_id}"
            else
                repair="npm install -g @microsoft/wiqd"
            fi
            out+="${cont_indent}${GRAY}Re-run: ${CYAN}${repair}${RESET}\n"
        fi
    done

    printf "\n"
    if $all_ok; then
        printf "${GREEN} ✓ All required components are installed and ready.${RESET}\n"
    elif $fatal; then
        printf "${YELLOW} ⚠ Setup incomplete.${RESET}\n"
        printf "${YELLOW} Required components are missing; repair them before using wiqd.${RESET}\n"
    else
        printf "${YELLOW} ⚠ Optional components need attention.${RESET}\n"
        printf "${YELLOW} wiqd is installed; affected optional commands may be unavailable.${RESET}\n"
    fi
    printf "%b" "$out"
    printf "\n"

    if $fatal; then
        return 1
    fi
    return 0
}


install_from_npm_registry() {
    local package="$1"
    local resolved_version="${2:-}"
    local package_spec="$package"

    # Always pin an exact, already-resolved version (R29/R31) — a bare package name
    # or a floating dist-tag would silently resolve npm's 'latest' dist-tag, which
    # carries no prerelease during the preview period and would install the wrong
    # build. Callers resolve the version via get_target_version before calling this.
    if [[ -n "$resolved_version" ]]; then
        package_spec="${package}@${resolved_version#v}"
    fi

    local package_scope=""
    if [[ "$package_spec" == @*/* ]]; then package_scope="${package_spec%%/*}"; fi
    local configured_registry
    configured_registry=$(npm config get registry --loglevel=error 2>/dev/null || true)
    configured_registry="${configured_registry//$'\r'/}"
    configured_registry="${configured_registry//$'\n'/}"
    if [[ "$configured_registry" == "undefined" || "$configured_registry" == "null" ]]; then configured_registry=""; fi
    # A scoped package resolves through its `@scope:registry` mapping when set,
    # which overrides the generic registry — so the EFFECTIVE registry (used for
    # both the fallback decision and the retry) must consult the scope first.
    local scoped_registry=""
    if [[ -n "$package_scope" ]]; then
        scoped_registry=$(npm config get "${package_scope}:registry" --loglevel=error 2>/dev/null || true)
        scoped_registry="${scoped_registry//$'\r'/}"
        scoped_registry="${scoped_registry//$'\n'/}"
        if [[ "$scoped_registry" == "undefined" || "$scoped_registry" == "null" ]]; then scoped_registry=""; fi
    fi
    local effective_registry="$configured_registry"
    if [[ -n "$scoped_registry" ]]; then effective_registry="$scoped_registry"; fi
    # Registry configuration is untrusted display text. Show only its parsed,
    # credential-free origin and never place it in a copyable command.
    local safe_effective_registry
    safe_effective_registry=$(safe_registry_label "$effective_registry")
    local normalized_configured="${effective_registry%/}"
    local normalized_public="${PUBLIC_NPM_REGISTRY%/}"
    local has_fallback_registry=false
    if [[ -n "$normalized_configured" && "$normalized_configured" != "$normalized_public" ]]; then has_fallback_registry=true; fi
    local previous_registry="$NPM_INSTALL_REGISTRY"
    local previous_registry_scope="$NPM_INSTALL_REGISTRY_SCOPE"
    NPM_INSTALL_REGISTRY="$PUBLIC_NPM_REGISTRY"
    NPM_INSTALL_REGISTRY_SCOPE="$package_scope"
    NPM_SUPPRESS_FAILURE_DIAGNOSTICS=$has_fallback_registry
    if install_npm_global_packages "$package_spec from ${NPM_INSTALL_REGISTRY:-npm registry}" "$package_spec"; then
        NPM_SUPPRESS_FAILURE_DIAGNOSTICS=false
        NPM_INSTALL_REGISTRY="$previous_registry"
        NPM_INSTALL_REGISTRY_SCOPE="$previous_registry_scope"
        return 0
    fi
    NPM_SUPPRESS_FAILURE_DIAGNOSTICS=false
    if $has_fallback_registry && [[ "$NPM_INSTALL_CONFLICT" != 1 && "$NPM_INSTALL_PERMISSION" != 1 ]]; then
        write_warn "$package_spec could not be installed from $PUBLIC_NPM_REGISTRY."
        write_info "Retrying from configured npm registry $safe_effective_registry..."
        NPM_INSTALL_REGISTRY="$effective_registry"
        NPM_INSTALL_REGISTRY_SCOPE="$package_scope"
        local fallback_status=0
        install_npm_global_packages "$package_spec from $safe_effective_registry" "$package_spec" || fallback_status=$?
        NPM_INSTALL_REGISTRY="$previous_registry"
        NPM_INSTALL_REGISTRY_SCOPE="$previous_registry_scope"
        if [[ "$fallback_status" -ne 0 && "$LAST_NPM_ERROR_CODE" == "E404" ]]; then
            if [[ -n "$LAST_NPM_MISSING_SPEC" && "$LAST_NPM_MISSING_SPEC" != "$package_spec" ]]; then
                write_warn "A dependency ($LAST_NPM_MISSING_SPEC) of $package_spec was not found in $safe_effective_registry."
            else
                write_warn "$package_spec was not found in $safe_effective_registry."
            fi
        fi
        return "$fallback_status"
    fi
    NPM_INSTALL_REGISTRY="$previous_registry"
    NPM_INSTALL_REGISTRY_SCOPE="$previous_registry_scope"
    if [[ "$LAST_NPM_ERROR_CODE" == "E404" ]]; then
        if [[ -n "$LAST_NPM_MISSING_SPEC" && "$LAST_NPM_MISSING_SPEC" != "$package_spec" ]]; then
            write_warn "A dependency ($LAST_NPM_MISSING_SPEC) of $package_spec was not found in $PUBLIC_NPM_REGISTRY."
        else
            write_warn "$package_spec was not found in $PUBLIC_NPM_REGISTRY."
        fi
    fi
    return 1
}

get_npm_global_package_version() {
    local package="$1"
    if command_exists npm; then
        npm list -g "$package" --json --depth=0 2>/dev/null | \
            node -e '
                let d="";
                const pkg=process.argv[1];
                process.stdin.on("data",c=>d+=c);
                process.stdin.on("end",()=>{
                    try{
                        const j=JSON.parse(d);
                        if(j.dependencies&&j.dependencies[pkg])
                            console.log(j.dependencies[pkg].version);
                    }catch(e){}
                });
            ' "$package" 2>/dev/null || true
    fi
}

get_package_json_version() {
    local package_json="$1"
    if [[ -f "$package_json" ]]; then
        node -e 'try{const p=require(process.argv[1]); if(p.version) console.log(p.version);}catch(e){}' "$package_json" 2>/dev/null || true
    fi
}

get_bundled_cli_package_version() {
    local extension="$1"
    local dependency="$2"
    local npm_root
    npm_root=$(npm root -g 2>/dev/null || true)
    [[ -z "$npm_root" ]] && return 0

    local wiqd_root="$npm_root/@microsoft/wiqd"
    local candidates=(
        "$wiqd_root/extensions/$extension/node_modules/$dependency/package.json"
        "$npm_root/@microsoft/$extension/node_modules/$dependency/package.json"
        "$npm_root/$dependency/package.json"
    )

    local candidate version
    for candidate in "${candidates[@]}"; do
        version=$(get_package_json_version "$candidate")
        if [[ -n "$version" ]]; then
            echo "$version"
            return 0
        fi
    done
}

get_target_version() {
    local source="$1"
    local repo="$2"
    local version="$3"
    local package="$4"

    # Explicit version or dist-tag requested — resolve it to a concrete version via
    # the registry (R30) so the up-to-date comparison never diffs a moving tag
    # (e.g. "preview") against an already-installed concrete version. Falls back to
    # the literal (leading 'v' stripped) if the registry can't be reached.
    if [[ -n "$version" && "$version" != "latest" ]]; then
        if [[ "$source" == "npm" || "$source" == "auto" ]]; then
            local resolved
            resolved=$(npm view "${package}@${version}" version 2>/dev/null || true)
            if [[ -n "$resolved" ]]; then
                echo "$resolved"
                return
            fi
        fi
        echo "${version#v}"
        return
    fi


    # No explicit version, npm source — pin to the exact version stamped into this
    # installer at release time (R29) rather than querying the registry: during the
    # preview period the 'latest' dist-tag carries no prerelease, so resolving it
    # here would silently skip the preview build this installer was published for.
    if [[ "$source" == "npm" || "$source" == "auto" ]]; then
        echo "$WIQD_INSTALLER_VERSION"
        return
    fi
}

# Test-mode hook: when WIQD_INSTALLER_TEST_MODE is set, stop right after
# function definitions so a test harness can source this script without
# triggering any imperative install behavior. Tests then mock the helpers
# (command, realpath, etc.) and assert on individual functions in
# isolation. This hook MUST
# stay below every helper definition so tests can introspect every
# helper the installer defines.
#
# A real install is always EXECUTED (curl … | bash), never sourced — only this
# repo's test harness sources this file to load its functions in isolation. Gate
# test-mode on BOTH the explicit opt-in AND sourced execution context, so an
# externally-set WIQD_INSTALLER_TEST_MODE on a real (executed) install is inert.
# There is deliberately no shippable sentinel value to discover or abuse.
if [ -n "${WIQD_INSTALLER_TEST_MODE:-}" ] && (return 0 2>/dev/null); then
    return
fi

# ─────────────────────────────────────────────
# Banner — Witch hat + gradient WIQD block letters
# Matches the CLI's Banner.cs output using ANSI true-color
# ─────────────────────────────────────────────

show_wiqd_banner() {
    if [[ ! -t 1 ]]; then
        return 0
    fi

    local e=$'\033'

    # ANSI true-color foreground helper
    fg() { printf '%s[38;2;%d;%d;%dm' "$e" "$1" "$2" "$3"; }
    local reset="${e}[0m"

    # M365 Copilot brand palette (same RGB values as Banner.cs)
    local lime; lime=$(fg 192 200 40)
    local green; green=$(fg 72 168 96)
    local teal; teal=$(fg 24 168 200)
    local blue; blue=$(fg 0 144 216)
    local purple; purple=$(fg 168 72 192)
    local magenta; magenta=$(fg 216 72 144)
    local pink; pink=$(fg 240 72 120)
    local coral; coral=$(fg 240 120 96)
    local orange; orange=$(fg 240 144 72)
    local dim; dim=$(fg 110 116 130)

    echo ""

    # Hat (per-row color matching Banner.cs)
    printf " %s               ╱╲              %s\n" "$lime" "$reset"
    printf " %s         %s✦%s    ╱  ╲     %s✧%s       %s\n" "$green" "$pink" "$green" "$lime" "$green" "$reset"
    printf " %s             ╱    ╲        %s✧%s   %s\n" "$teal" "$blue" "$teal" "$reset"
    printf " %s            ╱══════╲           %s\n" "$magenta" "$reset"
    printf " %s     %s·%s     ╱        ╲      %s·%s   %s\n" "$blue" "$purple" "$blue" "$coral" "$blue" "$reset"
    printf " %s          ╱          ╲         %s\n" "$purple" "$reset"
    printf " %s     ____╱____________╲____    %s\n" "$coral" "$reset"
    printf " %s    ╱______________________╲   %s\n" "$orange" "$reset"
    echo ""

    # WIQD block letters — simplified solid-color rendering
    # (True per-character gradient would require complex math in bash;
    #  use a multi-stop approach with segments instead)
    local wiqd_lines=(
        "  ██╗    ██╗██╗ ██████╗ ██████╗ "
        "  ██║    ██║██║██╔═══██╗██╔══██╗"
        "  ██║ █╗ ██║██║██║   ██║██║  ██║"
        "  ██║███╗██║██║██║▄▄ ██║██║  ██║"
        "  ╚███╔███╔╝██║╚██████╔╝██████╔╝"
        "   ╚══╝╚══╝ ╚═╝ ╚══▀▀═╝ ╚═════╝ "
    )

    # 7-stop gradient colors (LIME → GREEN → TEAL → BLUE → PURPLE → MAGENTA → CORAL)
    local -a stop_r=(192  72  24   0 168 216 240)
    local -a stop_g=(200 168 168 144  72  72 120)
    local -a stop_b=( 40  96 200 216 192 144  96)

    # Bash 3.2 on macOS slices UTF-8 strings by byte, which garbles the Unicode
    # block letters. Fall back to plain whole-line output there instead of per-char gradients.
    if (( ${BASH_VERSINFO[0]:-0} < 4 )); then
        for line in "${wiqd_lines[@]}"; do
            printf " %s%s%s\n" "$purple" "$line" "$reset"
        done
    else
        for line in "${wiqd_lines[@]}"; do
            printf " "
            local len=${#line}
            for ((c=0; c<len; c++)); do
                local ch="${line:$c:1}"
                if [[ "$ch" == " " ]]; then
                    printf " "
                else
                    # Linearly interpolate between gradient stops using integer math.
                    # Multiply by 1000 to avoid floating-point (bash has no floats).
                    local num_stops=${#stop_r[@]}
                    if ((len > 1)); then
                        local pos_x1000 idx frac_x1000 r g b
                        pos_x1000=$(( c * (num_stops - 1) * 1000 / (len - 1) ))
                        idx=$(( pos_x1000 / 1000 ))
                        frac_x1000=$(( pos_x1000 - idx * 1000 ))
                        if ((idx >= num_stops - 1)); then
                            idx=$((num_stops - 2))
                            frac_x1000=1000
                        fi
                        local next=$((idx + 1))
                        r=$(( stop_r[idx] + (stop_r[next] - stop_r[idx]) * frac_x1000 / 1000 ))
                        g=$(( stop_g[idx] + (stop_g[next] - stop_g[idx]) * frac_x1000 / 1000 ))
                        b=$(( stop_b[idx] + (stop_b[next] - stop_b[idx]) * frac_x1000 / 1000 ))
                    else
                        r=${stop_r[0]}
                        g=${stop_g[0]}
                        b=${stop_b[0]}
                    fi
                    printf '%s[38;2;%d;%d;%dm%s' "$e" "$r" "$g" "$b" "$ch"
                fi
            done
            printf "%s\n" "$reset"
        done
    fi

    echo ""
    printf " %s       wiqd installer v%s%s\n" "$dim" "$WIQD_INSTALLER_VERSION" "$reset"
    echo ""
}

show_wiqd_banner

# ─────────────────────────────────────────────
# EULA acceptance prompt — before any real work
# ─────────────────────────────────────────────
# On a fresh install the user hasn't accepted wiqd's EULA yet. We fold the
# acceptance into the installer's interactive flow: show the pre-release notice,
# prompt accept/decline, and (after a successful install) persist via the
# hidden --installer-stamp flag. On upgrade with current version already accepted
# we skip the prompt.

read_eula_acceptance() {
    # Check whether an existing wiqd already has the EULA accepted.
    if command -v wiqd >/dev/null 2>&1; then
        local status_json
        status_json=$(wiqd eula status --json 2>/dev/null) || true
        if [ -n "$status_json" ]; then
            # Parse JSON properly — grep on unstructured JSON risks matching
            # another tool's state. Use node (guaranteed present if wiqd is
            # installed) for reliable field-level access.
            local wiqd_accepted
            wiqd_accepted=$(echo "$status_json" | node -e "
                let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
                  try{const j=JSON.parse(d);const w=j.data&&j.data.wiqd;
                    console.log(w&&w.tool==='wiqd'&&w.state==='accepted'?'yes':'no');
                  }catch{console.log('no')}
                })
            " 2>/dev/null) || true
            if [ "$wiqd_accepted" = "yes" ]; then
                echo "already-accepted"
                return
            fi
        fi
    fi

    if ! is_installer_interactive; then
        write_warn "EULA acceptance required but installer is running non-interactively." >&2
        write_hint "Re-run the installer in an interactive terminal to accept the EULA." >&2
        echo "non-interactive"
        return
    fi

    # Double-check /dev/tty is actually usable (is_installer_interactive checks
    # -r/-w but the device may still fail on open in some environments).
    if ! echo "" > /dev/tty 2>/dev/null; then
        write_warn "EULA acceptance required but /dev/tty is not available." >&2
        write_hint "Re-run the installer in an interactive terminal to accept the EULA." >&2
        echo "non-interactive"
        return
    fi

    echo "" > /dev/tty
    printf "${YELLOW} Pre-release notice${RESET}\n" > /dev/tty
    printf "${WHITE}   wiqd is experimental software shared for experimentation${RESET}\n" > /dev/tty
    printf "${WHITE}   purposes only. It is not production-ready and is not${RESET}\n" > /dev/tty
    printf "${WHITE}   officially supported. Expect breaking changes.${RESET}\n" > /dev/tty
    echo "" > /dev/tty
    printf "${CYAN}   EULA: https://aka.ms/wiqd/eula${RESET}\n" > /dev/tty
    echo "" > /dev/tty
    printf "${WHITE} Choose how to proceed:${RESET}\n" > /dev/tty
    printf "${WHITE}   [a] Accept the EULA and continue installing${RESET}\n" > /dev/tty
    printf "${WHITE}   [c] Cancel and exit${RESET}\n" > /dev/tty
    echo "" > /dev/tty

    printf " Your choice [default: a]: " > /dev/tty
    local reply
    IFS= read -r reply < /dev/tty || true
    reply=$(echo "$reply" | tr '[:upper:]' '[:lower:]' | xargs)
    if [ -z "$reply" ]; then reply="a"; fi

    case "$reply" in
        a) echo "accepted" ;;
        *) echo "declined" ;;
    esac
}

EULA_CHOICE=$(read_eula_acceptance)

if [ "$EULA_CHOICE" = "declined" ]; then
    echo ""
    write_warn "Cancelled — EULA not accepted. Nothing was installed."
    exit 1
fi

if [ "$EULA_CHOICE" = "non-interactive" ]; then
    echo ""
    write_warn "Cannot proceed without EULA acceptance in non-interactive mode."
    exit 1
fi

# EULA_CHOICE is 'accepted' or 'already-accepted' — continue with install.

# Determine total steps
TOTAL_STEPS=3
if ! $SKIP_VSCODE; then TOTAL_STEPS=$((TOTAL_STEPS + 1)); fi
if ! $SKIP_PLUGIN; then TOTAL_STEPS=$((TOTAL_STEPS + 1)); fi

# ─────────────────────────────────────────────
# Step 1: Ensure Node.js (coexisting Node manager detection)
# ─────────────────────────────────────────────

write_step 1 "$TOTAL_STEPS" "Checking Node.js..."

# The 3P installer never installs or manages Node — it only checks that a
# compatible Node + npm are already present and blocks with guidance if not.
node_ver=$(get_node_version)
if [[ -z "$node_ver" ]]; then
    write_err "Node.js v${MIN_NODE_VERSION}+ is required but was not found."
    write_hint "Install Node.js v${NODE_VERSION} from https://nodejs.org/ (or via your package manager), then re-run this installer."
    exit 1
fi
if ! version_gte "$node_ver" "$MIN_NODE_VERSION"; then
    write_err "Node.js v$node_ver found but v${MIN_NODE_VERSION}+ is required."
    write_hint "Upgrade Node.js to v${NODE_VERSION}+ from https://nodejs.org/ (or via your package manager), then re-run this installer."
    exit 1
fi
write_ok "Node.js v$node_ver detected"

if ! command_exists npm; then
    write_err "npm not found despite Node.js being installed."
    write_hint "Restart your terminal and re-run this installer."
    exit 1
fi
npm_ver=$(npm --version 2>/dev/null || echo "unknown")
write_ok "npm v$npm_ver ready"

# Surface stale ~/.npmrc keys before the npm install runs.
show_npm_config_deprecation_warning

# ─────────────────────────────────────────────
# Step 2: Install wiqd (npm global)
# ─────────────────────────────────────────────

write_step 2 "$TOTAL_STEPS" "Installing wiqd CLI..."

current_version=$(get_npm_global_package_version "$WIQD_PACKAGE")
# Resolved unconditionally (not just when something is already installed) because
# the actual install call below also needs a concrete, pinned version (R29/R30) —
# never a bare package name or a floating dist-tag.
target_version=$(get_target_version "$SOURCE" "$REPO" "$VERSION" "$WIQD_PACKAGE")

# Determine whether the installed version is already the target.
skip_install=false
if [[ -n "$current_version" ]] && ! $FORCE; then
    if [[ -n "$target_version" && "$current_version" == "$target_version" ]]; then
        skip_install=true
    fi
fi

if $skip_install; then
    write_info "Found wiqd v$current_version — verifying..."
    write_hint "Use --force to reinstall"
else
    if [[ -n "$current_version" ]]; then
        write_info "Updating wiqd (current: v$current_version)..."
    fi
    
    if ! install_from_npm_registry "$WIQD_PACKAGE" "$target_version"; then
        if [[ "$NPM_INSTALL_CONFLICT" == 1 ]]; then
            # EEXIST advisory already printed by the install primitive (R35);
            # a local file conflict is not a network problem.
            exit 1
        fi
        if [[ "$NPM_INSTALL_PERMISSION" == 1 ]]; then
            # EACCES/EPERM advisory already printed by the install primitive
            # (R35); a local permission failure is not a network problem.
            exit 1
        fi
        write_err "wiqd installation failed."
        echo ""
        if [[ "$LAST_NPM_ERROR_CODE" == "E404" ]]; then
            safe_last_registry=$(safe_registry_label "$LAST_NPM_REGISTRY")
            is_public_registry=false
            if [[ "${LAST_NPM_REGISTRY%/}" == "${PUBLIC_NPM_REGISTRY%/}" ]]; then is_public_registry=true; fi
            if [[ -n "$LAST_NPM_MISSING_SPEC" && "$LAST_NPM_MISSING_SPEC" != "$WIQD_PACKAGE@${target_version#v}" ]]; then
                write_hint "A dependency ($LAST_NPM_MISSING_SPEC) was not found in $safe_last_registry."
            else
                write_hint "$WIQD_PACKAGE@${target_version#v} was not found in $safe_last_registry."
            fi
            if $is_public_registry; then
                write_hint "After it is published, run 'npm install -g $WIQD_PACKAGE@${target_version#v} --registry $PUBLIC_NPM_REGISTRY'."
            else
                write_hint "After it becomes available, re-run this installer to use your configured registry."
            fi
        else
            write_hint "Make sure npm can reach the public registry, then re-run this installer."
        fi
        exit 1
    fi
    
    # Verify
    wiqd_ver=""
    if command_exists wiqd; then
        wiqd_ver=$(WIQD_INSTALLER_PROBE=1 WIQD_TELEMETRY=0 wiqd --version 2>/dev/null || true)
    fi
    
    if [[ -n "$wiqd_ver" ]]; then
        write_ok "wiqd installed: $(echo "$wiqd_ver" | tr -d '[:space:]')"
    else
        npm_bin=$(npm config get prefix 2>/dev/null || true)
        if [[ -n "$npm_bin" ]]; then
            write_warn "wiqd installed but not in PATH"
            write_hint "Add to PATH: $npm_bin/bin"
        else
            write_err "wiqd installation could not be verified"
        fi
    fi
fi


# ─────────────────────────────────────────────
# Step 3: Verify installation
# ─────────────────────────────────────────────
#
# ATK remains a host dependency. Eval and Work IQ are managed by their extension
# payloads and intentionally stay off PATH. Their missing doctor rows are a normal
# lazy state: run `wiqd agent eval` or a Work IQ command to install the exact pin.

write_step 3 "$TOTAL_STEPS" "Verifying installation..."

install_success=false

# R32: verify on-disk completeness BEFORE trusting a runtime probe. npm reports
# "already installed" on version metadata alone, so an interrupted install can
# leave the package registered-but-incomplete. A missing/empty required artifact
# is a fatal verdict with an uninstall-first repair (a plain re-run or --force is
# an npm no-op on same-version corruption — only `npm uninstall -g` re-extracts).
if ! test_wiqd_install_complete >/dev/null; then
    write_err "installation incomplete. Repair:"
    write_hint "  npm uninstall -g $WIQD_PACKAGE, then re-run this installer."
    exit 1
fi

wiqd_check=""
if command_exists wiqd; then
    wiqd_check=$(WIQD_INSTALLER_PROBE=1 WIQD_TELEMETRY=0 wiqd --version 2>/dev/null || true)
fi

if [[ -n "$wiqd_check" ]]; then
    write_ok "wiqd CLI: $(echo "$wiqd_check" | tr -d '\n')"
    install_success=true
    # Seed the default extension registrations now that the host is on PATH.
    # Registration-only activation means the defaults are inert until the
    # install path registers them; do it before the plugin step. Non-fatal.
    seed_wiqd_defaults || true
else
    # R32: files are present (completeness passed above) but the CLI didn't run —
    # a PATH problem, not a broken install. Fatal so the exit code is honest,
    # with the uninstall-first repair as the fallback.
    write_err "wiqd installed, but not yet on PATH. Restart your terminal."
    write_hint "  Still failing? npm uninstall -g $WIQD_PACKAGE, then re-run this installer."
    exit 1
fi

# A missing REQUIRED dependency (atk) is fatal: stop before the VS Code /
# plugin steps so the user fixes the broken install first.
if ! show_dependency_status; then
    exit 1
fi

# Persist EULA acceptance now that the wiqd CLI is verified on PATH — BEFORE the
# host-integration steps (VS Code, plugin) that themselves invoke EULA-gated
# wiqd commands. The human already accepted at the top-of-script prompt; this
# only records the version-stamped acceptance so those steps run un-gated.
# Non-fatal: the user can still accept manually if this write fails.
if [ "$EULA_CHOICE" = "accepted" ]; then
    wiqd eula accept wiqd --installer-stamp >/dev/null 2>&1 || true
fi

# ─────────────────────────────────────────────
# Step 4: VS Code Extension (optional)
# ─────────────────────────────────────────────

if ! $SKIP_VSCODE; then
    step_num=4

    if $INSIDERS; then
        code_cmd="code-insiders"
        code_name="VS Code Insiders"
    else
        code_cmd="code"
        code_name="VS Code"
    fi

    write_step "$step_num" "$TOTAL_STEPS" "Installing $code_name extension..."

    if command_exists "$code_cmd"; then
        # Check if already installed
        extensions=$("$code_cmd" --list-extensions 2>/dev/null || true)
        if echo "$extensions" | grep -qi "$VSCODE_EXTENSION_ID"; then
            write_ok "Work IQ extension already installed in $code_name"
        else
            if "$code_cmd" --install-extension "$VSCODE_EXTENSION_ID" --force >/dev/null 2>&1; then
                write_ok "Work IQ extension installed in $code_name"
            else
                write_warn "Could not install extension"
                write_hint "Install manually: $code_cmd --install-extension $VSCODE_EXTENSION_ID"
            fi
        fi
    else
        write_warn "$code_name not found — skipping extension install"
        write_hint "Install $code_name from https://code.visualstudio.com/"
    fi
fi

# ─────────────────────────────────────────────
# Step N: Copilot CLI Plugin (automatic)
# ─────────────────────────────────────────────

if $SKIP_PLUGIN; then
    plugin_install_skipped=true
fi

if ! $SKIP_PLUGIN; then
    plugin_step_num=4
    if ! $SKIP_VSCODE; then plugin_step_num=5; fi

    write_step "$plugin_step_num" "$TOTAL_STEPS" "Installing wiqd plugin..."

    if $install_success; then
        # We NEVER install a plugin host. Installing a third-party agent CLI
        # (Copilot CLI / Claude Code) without consent is out of scope for the
        # wiqd install — the host is the plugin host, not a wiqd dependency.
        # Detect which supported host(s) are already on PATH and
        # compose the plugin only for those; `wiqd component plugin install --cli <host>`
        # resolves the same binary, so a PATH hit here matches the command's own
        # host check. If neither host is present, skip gracefully and
        # non-fatally — the wiqd CLI install itself is already complete.
        plugin_hosts=()
        if command_exists copilot; then plugin_hosts+=(copilot); fi
        if command_exists claude; then plugin_hosts+=(claude); fi

        if [[ ${#plugin_hosts[@]} -eq 0 ]]; then
            write_info "No Copilot CLI or Claude Code detected — skipping plugin install."
            write_hint "Install one, then run 'wiqd component plugin install' (add '--cli claude' for Claude Code)."
        else
            for plugin_host in "${plugin_hosts[@]}"; do
                # Every `wiqd component plugin install` is a clean reinstall (it wipes the
                # target plugin dir before copying the bundle), so no --force is
                # needed to refresh an existing install. --force IS needed when an
                # install path activated additional extensions in this same run: a
                # plain compose treats an unchanged wiqd version as already up to
                # date and would leave the prior toggle's skill set deployed, so
                # --force forces the uninstall-then-reinstall that rebuilds the
                # plugin tree from the freshly-composed source.
                plugin_install_args=(component plugin install --cli "$plugin_host")
                if [[ "$plugin_force_recompose" == "true" ]]; then
                    plugin_install_args+=(--force)
                fi
                if plugin_output=$(wiqd "${plugin_install_args[@]}" 2>&1); then
                    write_ok "wiqd plugin installed for $plugin_host"
                    plugin_install_succeeded=true
                else
                    # Capture the command's own rc immediately — anything evaluated
                    # between the failed substitution and this point (even a failed
                    # `[[ ]]` test) would otherwise clobber $? before it's read.
                    rc=$?
                    if [[ "$rc" -eq 130 ]]; then
                        write_warn "wiqd plugin install cancelled for $plugin_host (exit code 130)"
                        if [[ -n "$plugin_output" ]]; then
                            write_warn "  $plugin_output"
                        fi
                        plugin_install_cancelled=true
                        break
                    fi
                    write_warn "Could not install wiqd plugin for $plugin_host (exit code $rc)"
                    if [[ -n "$plugin_output" ]]; then
                        write_warn "  $plugin_output"
                    fi
                    write_hint "Run 'wiqd component plugin install --cli $plugin_host' to retry"
                    plugin_install_failed=true
                    failed_plugin_hosts+=("$plugin_host")
                fi
            done
        fi
    else
        write_warn "Skipping plugin install — wiqd CLI not verified on PATH"
        write_hint "Restart your terminal and run: wiqd component plugin install"
    fi
fi

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────

echo ""
# The full-success banner requires BOTH the CLI-on-PATH probe AND a clean
# plugin step — a plugin failure must never be masked by "success" text, even
# though the CLI itself is fully usable (see the elif branch below).
if $install_success && ! $plugin_install_failed && ! $plugin_install_cancelled; then
    printf "${GREEN} ╔══════════════════════════════════════╗${RESET}\n"
    printf "${GREEN} ║    ✓ wiqd installed successfully!    ║${RESET}\n"
    printf "${GREEN} ╚══════════════════════════════════════╝${RESET}\n"
    echo ""


    print_wiqd_quickstart
elif $install_success && $plugin_install_cancelled; then
    printf "${YELLOW} ╔══════════════════════════════════════╗${RESET}\n"
    printf "${YELLOW} ║ ⚠ wiqd installed — plugin cancelled  ║${RESET}\n"
    printf "${YELLOW} ╚══════════════════════════════════════╝${RESET}\n"
    echo ""

    printf "${YELLOW} ⚠  wiqd plugin install was cancelled by the user.${RESET}\n"
    echo ""

    print_wiqd_quickstart
elif $install_success && $plugin_install_failed; then
    # The wiqd CLI installed and is fully usable — a failed plugin step is a
    # partial, not a fatal, outcome. Say so honestly instead of the full-success
    # banner, and repeat the per-host retry hint here (in the FINAL summary),
    # not only at the point of failure a screen-full of output ago.
    printf "${YELLOW} ╔══════════════════════════════════════╗${RESET}\n"
    printf "${YELLOW} ║ ⚠ wiqd installed — plugin incomplete ║${RESET}\n"
    printf "${YELLOW} ╚══════════════════════════════════════╝${RESET}\n"
    echo ""

    printf "${YELLOW} ⚠  wiqd plugin install did not complete for:${RESET}\n"
    for failed_host in "${failed_plugin_hosts[@]}"; do
        printf "${WHITE}   - %s${RESET}\n" "$failed_host"
        printf "${GRAY}     Run 'wiqd component plugin install --cli %s' to retry${RESET}\n" "$failed_host"
    done
    echo ""

    print_wiqd_quickstart
else
    printf "${YELLOW} ╔══════════════════════════════════════╗${RESET}\n"
    printf "${YELLOW} ║  ⚠  wiqd installed — restart shell   ║${RESET}\n"
    printf "${YELLOW} ╚══════════════════════════════════════╝${RESET}\n"
    echo ""
    printf "${WHITE} Close and reopen your terminal, then run:${RESET}\n"
    printf "${CYAN}   wiqd --version${RESET}\n"
    if [ "$EULA_CHOICE" = "accepted" ]; then
        echo ""
        printf "${GRAY} Note: you accepted the EULA during install but wiqd is not yet on PATH.${RESET}\n"
        printf "${GRAY} After restarting, run: wiqd eula accept wiqd${RESET}\n"
    fi
    echo ""
fi

if $plugin_install_cancelled; then
    exit 130
fi

# A partial install (CLI on PATH, plugin step attempted-and-failed) must exit
# non-zero so CI and scripted installs can detect and act on it, even though
# nothing here aborts the run early — the CLI install itself always completes
# and the summary above already gave the user the full retry story.
if $plugin_install_failed; then
    # See the PowerShell installer's -PluginNonFatal flag: it makes a
    # plugin-only failure exit 75 (CLI ok, plugin deferred) so wiqd update
    # reports success with a close-your-agents warning; bootstrap/CI keep 1.
    if $PLUGIN_NON_FATAL; then exit 75; fi
    exit 1
fi
