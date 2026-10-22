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
#   2. @microsoft/wiqd (npm global package — includes extension payloads)
#   3. Verify installation (`wiqd doctor` reconciles active managed Work IQ
#      and Eval generations; related commands retry if verification was incomplete)
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
VERSION_EXPLICIT=false
REPO="microsoft/wiqd"
SKIP_VSCODE=false
SKIP_PLUGIN=false
PLUGIN_NON_FATAL=false
INSIDERS=false
UPDATE_RESULT_PATH="${WIQD_UPDATE_RESULT_PATH:-}"
NODE_VERSION="24"
FORCE=false
MIN_NODE_VERSION="24.15.0"
WIQD_PACKAGE="@microsoft/wiqd"

# The canonical public npm registry used only by explicit recovery paths and
# trusted copyable hints. Normal installer flows do not pin registry selection.
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

# The plugin step is a loop over possibly-multiple hosts (copilot, claude), so
# "succeeded" (>=1 host installed cleanly) and "failed" (>=1 host errored) are
# tracked separately from install_success. A host being ABSENT is a graceful
# skip, never a failure; only an attempted-and-errored install trips failed.
# plugin_install_failed/succeeded/skipped/cancelled (+ failed_plugin_hosts)
# drive the summary banners, the skills-list gate, and the final exit code.
plugin_install_failed=false
plugin_install_succeeded=false
plugin_notices=''
plugin_install_skipped=false
plugin_install_cancelled=false
failed_plugin_hosts=()

# Stamped by sync-version.ps1 — do not edit manually.
WIQD_INSTALLER_VERSION="0.20.0"

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
            VERSION_EXPLICIT=true
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
            echo "  --repo <host/owner/repo> GitHub repository (default: microsoft/wiqd)"
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
strip_terminal_controls() {
    local esc; esc=$(printf '\033')
    printf '%s' "$1" \
        | LC_ALL=C sed "s|${esc}\[[0-9;?]*[ -/]*[@-~]||g" \
        | LC_ALL=C tr -d '\000-\010\013\014\016-\037\177'
}

sanitize_terminal_output() {
    strip_terminal_controls "$1" | tail -c 8192
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

sanitize_installer_output() {
    local sanitized redacted
    sanitized=$(strip_terminal_controls "${1:-}")
    redacted=$(printf '%s' "$sanitized" \
        | LC_ALL=C sed -E \
            -e 's#(Authorization[[:space:]]*[:=][[:space:]]*(Bearer|Basic)[[:space:]]+)[^[:space:]]+#\1<REDACTED>#gI' \
            -e 's#((access[_-]?token|token|auth|password|passwd|secret|apikey|api_key)[[:space:]]*[:=][[:space:]]*)[^[:space:],;]+#\1<REDACTED>#gI' \
            -e "s#https?://[^[:space:]<>\"']+#<URL>#g" \
            -e 's#[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}#[EMAIL]#g' \
            -e 's#[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}#[GUID]#g' \
            -e 's#[A-Za-z]:\\([^\\[:space:]<>:"|?*]+\\?)+#<PATH>#g' \
            -e "s#(^|[^:/[:alnum:]_])/(home|Users|root|var|tmp|etc)/[^[:space:]:;'\"]+#\1<PATH>#g")
    printf '%s' "$redacted" | tail -c 4096
}

quote_shell_literal() {
    local value="${1:-}" sanitized
    # CR/LF is literal inside single quotes, but printing it would forge extra
    # recovery-log lines. Refuse the command instead of changing the path.
    case "$value" in
        *$'\r'*|*$'\n'*) return 1 ;;
    esac
    sanitized=$(sanitize_terminal_output "$value")
    printf "'"
    printf '%s' "$sanitized" | LC_ALL=C sed "s/'/'\\\\''/g"
    printf "'"
}

is_wiqd_updater_process() {
    local process_name="${1:-}" command_line="${2:-}"
    process_name="${process_name##*/}"
    [[ "$process_name" == "node" || "$process_name" == "node.exe" ]] || return 1
    case "$command_line" in
        *"/bin/wiqd.js"*|*"/dist/wiqd-cli.cjs"*|*"\\bin\\wiqd.js"*|*"\\dist\\wiqd-cli.cjs"*) ;;
        *) return 1 ;;
    esac
    [[ "$command_line" =~ (^|[[:space:]])update([[:space:]]|$) ]]
}

is_legacy_wiqd_updater_invocation() {
    [[ "$FORCE" == true && "$VERSION_EXPLICIT" == true && -z "$UPDATE_RESULT_PATH" ]] || return 1

    if [[ $# -eq 2 ]]; then
        is_wiqd_updater_process "$1" "$2"
        return
    fi

    local process_id="$PPID" depth parent_id process_name command_line
    for ((depth = 0; depth < 4 && process_id > 0; depth++)); do
        process_name=$(ps -o comm= -p "$process_id" 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//') || break
        command_line=$(ps -o command= -p "$process_id" 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//') || break
        if is_wiqd_updater_process "$process_name" "$command_line"; then return 0; fi
        parent_id=$(ps -o ppid= -p "$process_id" 2>/dev/null | tr -d '[:space:]') || break
        [[ "$parent_id" =~ ^[0-9]+$ ]] || break
        process_id="$parent_id"
    done
    return 1
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

# Renders the closing Quick Start block. Kept compact and helper-driven to
# minimize merge conflicts with in-flight installer edits. Must mirror
# the PowerShell installer's Write-WiqdQuickstart output character-for-character
# (diff between the two is shell-idiom only: printf vs Write-Host).
print_wiqd_quickstart() {
    local copilot_present=false claude_present=false plugin_ready=false
    if command_exists copilot; then copilot_present=true; fi
    if command_exists claude; then claude_present=true; fi
    if $plugin_install_succeeded && ! $plugin_install_failed && ! $plugin_install_cancelled && ! $plugin_install_skipped; then plugin_ready=true; fi

    printf "${CYAN} Quick Start:${RESET}\n"
    printf "${WHITE}   wiqd plugin create --name my-plugin            Create a new plugin${RESET}\n"
    printf "${WHITE}   cd my-plugin                                  Enter the plugin project${RESET}\n"
    printf "${WHITE}   wiqd plugin validate                          Validate your plugin${RESET}\n"
    printf "${WHITE}   wiqd plugin provision --env local              Provision to your tenant (local env)${RESET}\n"
    echo ""
    if [[ -n "${plugin_notices:-}" ]]; then printf '%s\n' "$plugin_notices"; fi
    if $plugin_ready && { $copilot_present || $claude_present; }; then
        printf "${CYAN} Start a new host session to use the WIQD plugin.${RESET}\n"
        if $copilot_present; then
            printf "${CYAN} Or with Copilot CLI (interactive mode):${RESET}\n"
            printf "${WHITE}   copilot -i \"create a new standalone plugin\"${RESET}\n"
            printf "${WHITE}   copilot -i \"validate my plugin\"${RESET}\n"
            printf "${WHITE}   copilot -i \"provision my plugin in the local environment\"${RESET}\n"
            echo ""
        else
            printf "${CYAN} Open Claude Code to use the WIQD plugin.${RESET}\n"
            echo ""
        fi
    elif ! $plugin_install_cancelled; then
        if ! $copilot_present && ! $claude_present; then
            printf "${CYAN} First install Copilot CLI or Claude Code.${RESET}\n"
        fi
        printf "${CYAN} Manual plugin setup (choose the host needing setup):${RESET}\n"
        printf "${YELLOW} Resolve any reported errors or source conflicts first.${RESET}\n"
        printf "${CYAN} Copilot (Awesome Copilot):${RESET}\n"
        printf "${WHITE}   copilot plugin install wiqd@awesome-copilot${RESET}\n"
        printf "${CYAN} Copilot alternative:${RESET}\n"
        printf "${WHITE}   copilot plugin marketplace add microsoft/wiqd${RESET}\n"
        printf "${WHITE}   copilot plugin install wiqd@wiqd${RESET}\n"
        printf "${CYAN} Claude Code:${RESET}\n"
        printf "${WHITE}   claude plugin marketplace add microsoft/wiqd${RESET}\n"
        printf "${WHITE}   claude plugin install wiqd@wiqd${RESET}\n"
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

# native-plugin:start
wiqd_plugin_json() {
    node -e '
const fs = require("node:fs");
const { isDeepStrictEqual } = require("node:util");
const [operation, ...args] = process.argv.slice(1);
const text = () => fs.readFileSync(0, "utf8").replace(/^\uFEFF/, "");
const input = () => JSON.parse(text());
const output = (value) => console.log(JSON.stringify(value));
const check = (value) => { if (!value) process.exitCode = 1; };
const fail = (message) => { throw new Error(message); };
const object = (value) => value !== null && typeof value === "object" && !Array.isArray(value);
const nonempty = (value) => typeof value === "string" && value.trim().length > 0;
const identifier = (value) => nonempty(value) && !/[\s@]/.test(value);
const targetForHost = (cli) => {
    if (cli === "copilot") return { marketplace: "awesome-copilot", repository: "github/awesome-copilot", id: "wiqd@awesome-copilot" };
    if (cli === "claude") return { marketplace: "wiqd", repository: "microsoft/wiqd", id: "wiqd@wiqd" };
    fail("Unknown plugin host");
};
const recovery = (current, afterUninstall = false) => {
    const { cli, plugins: allPlugins, marketplaces } = current;
    const destination = targetForHost(cli);
    const wiqd = allPlugins.filter((entry) => entry.id === "wiqd" || entry.id.startsWith("wiqd@"));
    const markets = marketplaces.filter((entry) => entry.name === "wiqd" || entry.name === destination.marketplace || entry.publicSource || entry.localSource || wiqd.some((plugin) => plugin.id === "wiqd@" + entry.name));
    const plugins = allPlugins.filter((entry) => wiqd.includes(entry) || markets.some((market) => entry.id.endsWith("@" + market.name)));
    const lines = markets.map((entry) => `Marketplace: ${JSON.stringify(entry.name)} (${JSON.stringify(entry.source)})`);
    lines.push(`Affected plugins: ${plugins.length ? plugins.map((entry) => JSON.stringify(entry.id)).join(", ") : "none"}`);
    lines.push("Inspect the current setup:", `  ${cli} plugin list --json`, `  ${cli} plugin marketplace list --json`,
        "Only the verified WIQD-owned local marketplace with WIQD as its sole plugin can be migrated.",
        "Other plugins and marketplaces are preserved. Keep your local source files.",
        "Resolve the reported ownership or binding issue, then retry; use --skip-plugin to install only the CLI.");
    return lines.join("\n");
};
try {
    switch (operation) {
        case "manifest": check(input()?.name === "wiqd"); break;
        case "target": output(targetForHost(args[0])); break;
        case "unsupported": {
            const diagnostic = text().trim();
            check(args[0] === "claude-list"
                ? /^(?:error:\s*)?unknown (?:command ["\u0027]list["\u0027]|option ["\u0027]--json["\u0027])\s*$/i.test(diagnostic)
                : /^(?:error:\s*)?unknown option ["\u0027]--json["\u0027]\s*$/i.test(diagnostic));
            break;
        }
        case "legacy": {
            const raw = text();
            const clean = raw.replace(/\x1b\[[0-9;]*m/g, "");
            const lines = clean.split(/\r?\n/).filter((line) => line.trim());
            const allowNoMatch = args[1] !== "markets" && args[2] === "true";
            if (!lines.length && !allowNoMatch) fail("Blank legacy inventory");
            const entries = [];
            if (args[1] === "markets") {
                let pending = "";
                for (const line of lines) {
                    const entry = line.trim().replace(/^[•·❯*>-]\s+/, "");
                    let match;
                    if ((match = entry.match(/^([A-Za-z0-9_.-]+)\s+\(Local:\s*(.+)\)$/i))) {
                        entries.push({ name: match[1], kind: "Local", source: match[2], inventorySource: "text-local" });
                        pending = "";
                    } else if ((match = entry.match(/^([A-Za-z0-9_.-]+)$/))) {
                        pending = match[1];
                    } else if (pending && (match = entry.match(/^Source\s*:\s*Directory\s*\((.+)\)$/i))) {
                        entries.push({ name: pending, kind: "Directory", source: match[1], inventorySource: "text-local" });
                        pending = "";
                    } else if (entry) pending = "";
                }
                if (entries.some((entry) => /[\x00-\x1f]/.test(entry.source))) fail("Invalid local marketplace source");
                for (const source of ["microsoft/wiqd", "github/awesome-copilot"]) {
                    const repository = source.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
                    const pattern = new RegExp("(?<![A-Za-z0-9_./:@\\\\+-])(?:(?:git\\+)?https?://github\\.com/|git@github\\.com:)?" + repository + "(?:\\.git)?/?(?=$|[\\s\\x22\\x27()<>,;])", "i");
                    if (pattern.test(clean)) {
                        const name = source === "microsoft/wiqd" ? "wiqd" : "awesome-copilot";
                        entries.push({ name, kind: "GitHub", source, inventorySource: "text-presence" });
                    }
                }
                if (!entries.length && !/^No marketplaces configured\.?$/i.test(clean.trim())) fail("No known WIQD marketplace repository found in text inventory");
            } else {
                let current;
                for (const line of lines) {
                    const entry = line.trim().replace(/^[•·❯*>-]\s+/, "");
                    const match = entry.match(/^([A-Za-z0-9_.-]+@[A-Za-z0-9_.-]+|wiqd)(?=\s|$)/);
                    if (match) {
                        current = { id: match[1], inventorySource: "text-presence" };
                        entries.push(current);
                    } else if (/@wiqd(?=$|[^A-Za-z0-9_.-])/i.test(entry)) fail("Ambiguous marketplace consumer in text inventory");
                    else if (args[0] === "claude" && current) {
                        const scope = entry.match(/^Scope\s*:\s*(\S+)\s*$/i);
                        if (scope) {
                            if (current.scope && current.scope !== scope[1]) fail("Conflicting Claude plugin scopes in text inventory");
                            current.scope = scope[1];
                        } else if (!/^\s+\S[^:]*:\s*.*$/.test(line)) current = undefined;
                    }
                }
                if (!entries.length && !allowNoMatch && !/^No plugins installed\.?$/i.test(clean.trim())) fail("No plugin identities found in text inventory");
            }
            output(entries);
            break;
        }
        case "markets": {
            const entries = input();
            if (!Array.isArray(entries)) fail("Expected JSON marketplace array");
            output(entries.map((entry) => {
                if (!object(entry) || !identifier(entry.name)) fail("Invalid JSON marketplace entry");
                let kind, source;
                if (args[0] === "copilot") {
                    const match = typeof entry.source === "string" && entry.source.match(/^([^:\s]+): (.*)$/);
                    if (!nonempty(entry.source)) fail("Invalid Copilot JSON marketplace entry");
                    if (match) [, kind, source] = match;
                    else { kind = "Unknown"; source = entry.source; }
                } else if (args[0] === "claude") {
                    const fields = { github: ["GitHub", "repo"], directory: ["Directory", "path"], url: ["URL", "url"] };
                    if (Object.hasOwn(fields, entry.source)) {
                        const [sourceKind, field] = fields[entry.source];
                        kind = sourceKind; source = entry[field];
                    } else {
                        const values = ["repo", "path", "url"].filter((field) => Object.hasOwn(entry, field));
                        if (!nonempty(entry.source) || values.length !== 1) fail("Unreadable Claude JSON marketplace source");
                        kind = entry.source; source = entry[values[0]];
                    }
                } else fail("Unknown inventory host");
                if (!nonempty(source) || /[\r\n\0]/.test(source)) fail("Invalid JSON marketplace source");
                return { name: entry.name, kind, source };
            }));
            break;
        }
        case "copilot-list": {
            const entries = input();
            if (!Array.isArray(entries)) fail("Expected Copilot JSON plugin array");
            output(entries.map((entry) => {
                if (!object(entry) || !identifier(entry.name) ||
                    !(entry.marketplace === "" || identifier(entry.marketplace)) ||
                    !nonempty(entry.version) || typeof entry.enabled !== "boolean" ||
                    !["installed", "live", "builtin", "external"].includes(entry.source)) fail("Invalid Copilot JSON plugin entry");
                return { id: entry.name + (entry.marketplace ? "@" + entry.marketplace : ""),
                    version: entry.version, localMarketplace: entry.source === "live", enabled: entry.enabled };
            }));
            break;
        }
        case "claude-list": {
            const entries = input();
            if (!Array.isArray(entries)) fail("Expected Claude JSON plugin array");
            for (const entry of entries) {
                if (!object(entry) || typeof entry.id !== "string" || !entry.id.trim() ||
                    typeof entry.version !== "string" || !entry.version.trim() ||
                    (Object.hasOwn(entry, "scope") && typeof entry.scope !== "string") ||
                    (Object.hasOwn(entry, "enabled") && typeof entry.enabled !== "boolean")) fail("Invalid Claude plugin entry");
            }
            output(entries);
            break;
        }
        case "claude-registry": {
            const registry = input();
            if (!object(registry?.plugins)) fail("Invalid Claude registry");
            const entries = [];
            for (const [id, versions] of Object.entries(registry.plugins)) {
                if (!Array.isArray(versions) || !versions.length) fail("Incomplete Claude registry");
                for (const entry of versions) {
                    if (!object(entry) || typeof entry.version !== "string" || typeof entry.scope !== "string") fail("Incomplete Claude registry");
                    entries.push({ id, version: entry.version, scope: entry.scope });
                }
            }
            output(entries);
            break;
        }
        case "copilot-registry": {
            let entries;
            try {
                const file = fs.statSync(args[0]);
                if (!file.isFile() || file.size > 1048576) fail("Invalid registry file");
                const registry = JSON.parse(fs.readFileSync(args[0], "utf8").replace(/^\uFEFF/, ""));
                if (!object(registry) || !Array.isArray(registry.installed_plugins)) fail("Missing installed_plugins array");
                const ids = new Set();
                entries = registry.installed_plugins.map((record) => {
                    if (!object(record) || !identifier(record.name) || typeof record.marketplace !== "string" ||
                        /[\s@]/.test(record.marketplace) || typeof record.enabled !== "boolean") fail("Invalid registry entry");
                    const id = record.name + (record.marketplace ? "@" + record.marketplace : "");
                    if (ids.has(id)) fail("Duplicate registry identity");
                    ids.add(id);
                    const entry = { id, enabled: record.enabled, inventorySource: "config" };
                    if (Object.hasOwn(record, "version")) {
                        if (!nonempty(record.version)) fail("Invalid registry version");
                        entry.version = record.version;
                    }
                    return entry;
                });
            } catch {
                // JSON parser diagnostics can contain authentication state from this file.
                fail("Plugin setup failed: Cannot read a valid Copilot installed_plugins array from config.json. Check the Copilot configuration, then retry, or use --skip-plugin to install only the CLI.");
            }
            output(entries);
            break;
        }
        case "entries": for (const entry of input()) output(entry); break;
        case "field": {
            if (!["source", "cli", "state", "publicState", "marketplace", "repository", "id"].includes(args[0])) fail("Invalid inventory field");
            const value = input()[args[0]];
            if (typeof value !== "string") fail("Missing inventory field");
            console.log(value);
            break;
        }
        case "market-add": {
            const entries = input();
            const entry = JSON.parse(args[0]);
            entries.push({ ...entry, ownedSource: args[1] === "true", localSource: args[2] === "true", publicSource: args[3] === "true", targetSource: args[4] === "true" });
            output(entries);
            break;
        }
        case "partial-inventory": {
            const [cli, marketJson, pluginJson] = args;
            output({ cli, marketplaces: JSON.parse(marketJson), plugins: JSON.parse(pluginJson), state: "unknown", publicState: "unknown", publicError: "", inventoryUnknown: true });
            break;
        }
        case "inventory-unknown": check(input().inventoryUnknown === true); break;
        case "public-plugin-shortcut": {
            const plugins = input();
            check((args[0] === "copilot" && plugins.some((entry) => entry.id === "wiqd@awesome-copilot")) || !plugins.some((entry) => entry.id === "wiqd@wiqd"));
            break;
        }
        case "fresh-public-host": {
            const cli = args[0], plugins = input();
            const wiqd = plugins.filter((entry) => entry.id === "wiqd" || entry.id.startsWith("wiqd@"));
            const duplicate = wiqd.filter((entry) => entry.id === targetForHost(cli).id).length > 1;
            output([{ cli, state: "absent", publicState: "absent", publicError: duplicate ? "Requested WIQD plugin identity is duplicated." : "", marketplaces: [], plugins, skipMarketplace: cli === "copilot", inventoryUnknown: wiqd.some((entry) => entry.id === "wiqd"), warnCoexistence: cli === "copilot" && wiqd.some((entry) => entry.id !== "wiqd@awesome-copilot") }]);
            break;
        }
        case "any-inventory-unknown": check(input().some((entry) => entry.inventoryUnknown === true)); break;
        case "fallback-duplicates": check(input().plugins.filter((entry) => entry.id === targetForHost(args[0]).id).length > 1); break;
        case "fallback-scope-conflict": check(input().plugins.some((entry) => entry.id === "wiqd@wiqd" && entry.scope && entry.scope !== "user")); break;
        case "claude-unverified-binding": {
            const current = input();
            check(current.plugins.filter((entry) => entry.id === "wiqd@wiqd").length === 1 && current.state !== "local" && current.publicState !== "preserve" && (current.state !== "selected" || current.publicError));
            break;
        }
        case "claude-remote-update": {
            const current = input();
            check(current.publicState === "preserve" || (current.state === "selected" && !current.publicError && current.plugins.filter((entry) => entry.id === "wiqd@wiqd").length === 1));
            break;
        }
        case "inventory-entry": {
            const [cli, marketJson, pluginJson] = args;
            const marketplaces = JSON.parse(marketJson);
            const plugins = JSON.parse(pluginJson);
            const destination = targetForHost(cli);
            const wiqd = plugins.filter((entry) => entry.id === "wiqd" || entry.id.startsWith("wiqd@"));
            const relevant = marketplaces.filter((entry) => entry.name === "wiqd" || entry.name === destination.marketplace || entry.publicSource || entry.localSource || wiqd.some((plugin) => plugin.id === "wiqd@" + entry.name));
            const binding = marketplaces.filter((entry) => entry.name === destination.marketplace);
            const target = wiqd.filter((entry) => entry.id === destination.id);
            const legacyBinding = marketplaces.filter((entry) => entry.name === "wiqd");
            const legacyTarget = wiqd.filter((entry) => entry.id === "wiqd@wiqd");
            const presenceOnly = marketplaces.some((entry) => entry.inventorySource === "text-presence");
            const local = relevant.filter((entry) => ["Local", "Directory"].includes(entry.kind) || entry.localSource);
            let state = "absent", reason = "", targetError = "";
            if (binding.length > 1 || target.length > 1) targetError = "Requested WIQD plugin or marketplace identity is duplicated.";
            else if (binding.length === 1) {
                if (binding[0].kind === "GitHub" && binding[0].targetSource) state = "selected";
                else targetError = `marketplace \u0027${destination.marketplace}\u0027 points to ${JSON.stringify(binding[0].source)}.`;
            }
            if (local.length) {
                state = "conflict"; reason = "Local WIQD plugin ownership cannot be verified.";
                if (local.length === 1 && legacyBinding.length === 1 && local[0].name === "wiqd" && ["Local", "Directory"].includes(local[0].kind) && legacyTarget.length === 1 && local[0].ownedSource) {
                    if (plugins.some((entry) => entry.id.endsWith("@wiqd") && entry.id !== "wiqd@wiqd")) reason = "Other plugins also use marketplace \u0027wiqd\u0027.";
                    else if (plugins.some((entry) => entry.inventorySource === "config")) reason = "Stored plugin inventory cannot verify all consumers; native inventory is required for local migration.";
                    else { state = "local"; if (cli === "claude") targetError = ""; }
                }
            }
            if (wiqd.some((entry) => entry.id === "wiqd" || !marketplaces.some((market) => entry.id === "wiqd@" + market.name))) {
                state = "conflict"; reason = "WIQD plugin marketplace identity is missing or ambiguous.";
            }
            if (cli === "claude" && target.some((entry) => entry.scope !== "user")) {
                targetError = "Claude WIQD scope is not user or cannot be determined.";
                if (state === "local") { state = "conflict"; reason = targetError; }
            }
            let publicState = state, publicError = targetError;
            if (cli === "claude" && !local.length && target.length === 1 && target[0].inventorySource === "text-presence" && !target[0].scope && binding.length === 1 && binding[0].kind === "GitHub" && binding[0].targetSource) publicError = "";
            if (cli === "copilot") {
                publicError = "";
                if (state === "conflict" && local.length === 1 && local[0].name === destination.marketplace) publicState = "coexist";
            }
            if (legacyTarget.length > 1 || (cli === "claude" && legacyBinding.length > 1)) publicError = "Requested WIQD plugin or marketplace identity is duplicated.";
            const remote = legacyBinding.length === 1 && legacyBinding[0].kind === "GitHub" && legacyBinding[0].publicSource && !legacyBinding[0].targetSource;
            if (cli === "copilot" && (legacyBinding.length || legacyTarget.length) && state !== "local") {
                publicState = "coexist";
                if (remote && legacyTarget.length === 1 && !target.length) publicState = "preserve";
            } else if (cli === "claude" && legacyBinding.length === 1 && legacyBinding[0].kind === "GitHub" && legacyBinding[0].targetSource && legacyTarget.length === 1 && legacyTarget[0].scope === "user" && !publicError) publicState = "preserve";
            const identityUnknown = wiqd.some((entry) => entry.id === "wiqd" || (entry.id !== "wiqd@wiqd" && !marketplaces.some((market) => entry.id === "wiqd@" + market.name)));
            if (identityUnknown) publicState = "conflict";
            let inventoryUnknown = args[3] === "true" && identityUnknown && !publicError;
            if (wiqd.length && presenceOnly && !binding.length && state !== "local" && !["preserve", "conflict"].includes(publicState) && !publicError) {
                if (args[3] !== "true") fail(`Cannot establish absence of the requested ${cli} marketplace from presence-only text inventory`);
                inventoryUnknown = true;
            }
            const warnCoexistence = publicState === "coexist" && !(cli === "copilot" && (target.length === 1 || remote));
            output({ cli, marketplaces, plugins, state, publicState, publicError, warnCoexistence, reason, targetError, inventoryUnknown });
            break;
        }
        case "append": output([...input(), JSON.parse(args[0])]); break;
        case "guard": {
            const conflict = input().find((entry) => args[0] === "true" ? entry.state === "conflict" : entry.cli === args[2] && (entry.publicState === "conflict" || entry.publicError));
            if (conflict && args[1] === "explain") {
                if (args[0] !== "true" && conflict.publicError) {
                    console.error(`Cannot install WIQD: ${conflict.publicError} Expected ${targetForHost(conflict.cli).repository}. Existing state was not replaced.\n${recovery(conflict)}`);
                } else {
                    console.error(`Cannot replace the existing WIQD plugin setup in ${conflict.cli}.\nReason: ${conflict.reason}\n${recovery(conflict)}`);
                }
            }
            check(!conflict);
            break;
        }
        case "host": {
            const entries = input().filter((entry) => entry.cli === args[0]);
            if (entries.length !== 1) fail("Missing or ambiguous host inventory");
            output(entries[0]);
            break;
        }
        case "verified-claude-destination": {
            const binding = input().filter((entry) => entry.name === "wiqd");
            check(binding.length === 1 && binding[0].kind === "GitHub" && binding[0].targetSource);
            break;
        }
        case "registered": {
            const current = input();
            check(current.skipMarketplace === true || current.marketplaces.some((entry) => entry.name === targetForHost(args[0]).marketplace));
            break;
        }
        case "source": console.log(input().marketplaces.find((entry) => entry.name === "wiqd").source); break;
        case "removable": {
            const current = JSON.parse(args[0]);
            const plugins = JSON.parse(args[1]);
            const consumers = plugins.filter((entry) => entry.id.endsWith("@wiqd"));
            const retainedLivePlugin = current.cli === "copilot" && consumers.length === 1 && consumers[0].id === "wiqd@wiqd" && consumers[0].localMarketplace === true && consumers[0].enabled === false;
            const marketplaces = input();
            check(isDeepStrictEqual(marketplaces, current.marketplaces) && (consumers.length === 0 || retainedLivePlugin));
            break;
        }
        case "migration-error": {
            const current = JSON.parse(args[0]);
            const plugins = JSON.parse(args[1]);
            const marketplaces = input();
            const targets = plugins.filter((entry) => entry.id === "wiqd@wiqd");
            const consumers = plugins.filter((entry) => entry.id.endsWith("@wiqd"));
            const retained = current.cli === "copilot" && consumers.length === 1 && targets.length === 1 && targets[0].localMarketplace === true && targets[0].enabled === false;
            const state = !targets.length ? "uninstalled" : targets.length === 1 && targets[0].enabled === false ? "disabled" : "still installed";
            const reasons = [];
            if (consumers.length && !retained) reasons.push("Plugins still reference marketplace \u0027wiqd\u0027.");
            const registrations = (entries) => entries.map(({ name, kind, source }) => ({ name, kind, source }));
            if (!isDeepStrictEqual(registrations(marketplaces), registrations(current.marketplaces))) reasons.push("Marketplace registrations changed during setup.");
            else if (!isDeepStrictEqual(marketplaces, current.marketplaces)) reasons.push("Marketplace source verification changed during setup.");
            if (args[2] !== "true") reasons.push("The old local source can no longer be verified as WIQD-owned.");
            console.error(`Migration of the old local WIQD plugin \u0027wiqd@wiqd\u0027 stopped in ${current.cli}.\nCurrent plugin state: ${state}.\nReason: ${reasons.join(" ")}\nThe installer has not removed the old marketplace.\n${recovery({ cli: current.cli, plugins, marketplaces }, true)}`);
            break;
        }
        case "targets": for (const entry of input().filter((entry) => entry.state === "local" && (args[1] === "true" || entry.cli === args[0]))) output(entry); break;
        case "coexistence-warning": check(input().warnCoexistence === true); break;
        case "duplicate-wiqd-plugins": {
            const entry = input();
            check(entry.cli === "copilot" && ["wiqd@wiqd", "wiqd@awesome-copilot"].every((id) => entry.plugins.filter((plugin) => plugin.id === id).length === 1));
            break;
        }
        case "update": {
            const entry = input();
            check(entry.plugins.some((plugin) => plugin.id === targetForHost(entry.cli).id));
            break;
        }
        default: fail("Unknown plugin data operation");
    }
} catch (error) {
    console.error(error.message);
    process.exitCode = 1;
}
' "$@"
}

wiqd_plugin_host() {
    local override
    case "$1" in
        copilot) override="${COPILOT_PATH:-}" ;;
        claude) override="${CLAUDE_PATH:-}" ;;
        *) return 2 ;;
    esac
    if [[ -n "$override" ]]; then printf '%s\n' "$override"; else command -v "$1"; fi
}

wiqd_plugin_kill_tree() {
    local parent="$1" child
    local -a ps_args
    case "${OSTYPE:-}" in
        msys*|cygwin*) ps_args=(-a) ;;
        *) ps_args=(-eo 'pid=,ppid=') ;;
    esac
    while read -r child; do
        [[ -n "$child" ]] && wiqd_plugin_kill_tree "$child"
    done < <(ps "${ps_args[@]}" | awk -v parent="$parent" '$2 == parent { print $1 }')
    kill -TERM "$parent" 2>/dev/null || true
    kill -KILL "$parent" 2>/dev/null || true
}

wiqd_plugin_run() (
    local cli="$1" binary milliseconds seconds child='' timer='' code=0
    shift
    binary=$(wiqd_plugin_host "$cli") || return 2
    case "$cli" in
        copilot) milliseconds="${WIQD_COPILOT_TIMEOUT:-60000}" ;;
        claude) milliseconds="${WIQD_CLAUDE_TIMEOUT:-60000}" ;;
    esac
    if ! seconds=$(wiqd_plugin_seconds "$milliseconds"); then
        printf '%s\n' 'Invalid native host timeout. Use a positive number of milliseconds.' >&2
        return 2
    fi
    trap '[[ -z "$timer" ]] || wiqd_plugin_kill_tree "$timer"; [[ -z "$child" ]] || wiqd_plugin_kill_tree "$child"; exit 130' INT TERM
    rm -f "$wiqd_plugin_directory/timed-out"
    CI=true "$binary" "$@" </dev/null >"$wiqd_plugin_directory/stdout" 2>"$wiqd_plugin_directory/stderr" &
    child=$!
    # Reaping the watchdog can terminate its sleep; keep that expected shell noise off host output.
    ( sleep "$seconds" || exit 0; : >"$wiqd_plugin_directory/timed-out"; wiqd_plugin_kill_tree "$child" ) 2>/dev/null &
    timer=$!
    wait "$child" || code=$?
    wiqd_plugin_kill_tree "$timer"
    wait "$timer" 2>/dev/null || true
    if [[ -f "$wiqd_plugin_directory/timed-out" ]]; then
        printf '%s\n' "$cli timed out. Inspect its native plugin inventory before retrying." >&2
        return 1
    fi
    if [[ "$code" -eq 124 ]]; then : >"$wiqd_plugin_directory/timed-out"; fi
    [[ "$code" -ne 143 ]] || code=130
    return "$code"
)

wiqd_plugin_failure() {
    local code="$1"
    shift
    if [[ "$code" -eq 130 ]]; then printf '%s\n' 'Plugin setup cancelled:' >&2; else printf '%s\n' 'Plugin setup failed:' >&2; fi
    printf '  %s' "$1" >&2
    shift
    printf ' %s' "$@" >&2
    printf '\n' >&2
    [[ "$code" -ne 130 ]] || return 0
    printf '%s\n' 'Error:' >&2
    if [[ -s "$wiqd_plugin_directory/stderr" ]]; then cat "$wiqd_plugin_directory/stderr" >&2; else printf 'Native command exited with code %s.\n' "$code" >&2; fi
    if [[ -s "$wiqd_plugin_directory/stdout" ]]; then cat "$wiqd_plugin_directory/stdout" >&2; fi
    printf '%s\n' 'Resolve the reported error, then rerun this installer.' >&2
}

wiqd_plugin_require() {
    local code=0
    wiqd_plugin_run "$@" || code=$?
    if [[ "$code" -ne 0 ]]; then
        wiqd_plugin_failure "$code" "$@"
        [[ "$code" -ne 130 ]] || return 130
        if [[ " $* " == *' --json '* ]]; then printf '%s\n' "Cannot read $1 inventory. Inspect the native command output before retrying." >&2; fi
        return 1
    fi
}

wiqd_plugin_parse_markets() {
    wiqd_plugin_json markets "$1"
}

wiqd_plugin_parse_copilot() {
    wiqd_plugin_json copilot-list
}

wiqd_plugin_read_inventory() {
    local cli="$1" operation="$2" code=0 diagnostics='' registry_allowed=false
    shift 2
    wiqd_plugin_run "$cli" "$@" --json || code=$?
    if [[ "$code" -ne 0 && "$code" -ne 124 && "$code" -ne 130 && ! -f "$wiqd_plugin_directory/timed-out" ]]; then
        if [[ "$operation" == claude-list && "$code" -eq 1 && ! -s "$wiqd_plugin_directory/stdout" ]] && wiqd_plugin_json unsupported "$operation" <"$wiqd_plugin_directory/stderr"; then registry_allowed=true; fi
        diagnostics=$(printf 'JSON inventory failed: %s %s --json (exit %s)\n' "$cli" "$*" "$code"; cat "$wiqd_plugin_directory/stderr" "$wiqd_plugin_directory/stdout")
        code=0
        wiqd_plugin_run "$cli" "$@" || code=$?
        if [[ "$code" -ne 0 ]]; then
            if [[ "$registry_allowed" == true && "$code" -ne 124 && "$code" -ne 130 && ! -f "$wiqd_plugin_directory/timed-out" ]]; then
                if [[ ! -e "$HOME/.claude/plugins/installed_plugins.json" ]]; then printf '[]\n'; return 0; fi
                if wiqd_plugin_json claude-registry <"$HOME/.claude/plugins/installed_plugins.json"; then return 0; fi
                printf '%s\n' "$diagnostics" "Invalid legacy registry for $cli plugin list --json:" >&2
                cat "$wiqd_plugin_directory/stderr" >&2
                return 1
            fi
            if [[ "$operation" == copilot-list && "$code" -ne 124 && "$code" -ne 130 && ! -f "$wiqd_plugin_directory/timed-out" && "${wiqd_plugin_require_native:-false}" != true ]]; then
                if wiqd_plugin_json copilot-registry "${COPILOT_HOME:-$HOME/.copilot}/config.json"; then return 0; fi
                printf '%s\n' "$diagnostics" >&2
                printf 'Native inventory failed: %s %s (exit %s)\n' "$cli" "$*" "$code" >&2
                cat "$wiqd_plugin_directory/stderr" "$wiqd_plugin_directory/stdout" >&2
                return 1
            fi
            printf '%s\n' "$diagnostics" >&2
            wiqd_plugin_failure "$code" "$cli" "$@"
            [[ "$code" -ne 130 ]] || return 130
            return 1
        fi
        if wiqd_plugin_json legacy "$cli" "$operation" "${wiqd_plugin_allow_no_match:-false}" <"$wiqd_plugin_directory/stdout"; then return 0; fi
    elif [[ "$code" -ne 0 ]]; then
        wiqd_plugin_failure "$code" "$cli" "$@" --json
        [[ "$code" -ne 130 ]] || return 130
        return 1
    else
        if wiqd_plugin_json "$operation" "$cli" <"$wiqd_plugin_directory/stdout"; then return 0; fi
    fi
    if [[ -n "$diagnostics" ]]; then printf '%s\n' "$diagnostics" >&2; fi
    printf 'Invalid inventory from %s %s:\n' "$cli" "$*" >&2
    cat "$wiqd_plugin_directory/stdout" "$wiqd_plugin_directory/stderr" >&2
    return 1
}

wiqd_plugin_seconds() {
    [[ "$1" =~ ^[0-9]+$ ]] || return 1
    LC_ALL=C awk -v milliseconds="$1" 'BEGIN {
        if (milliseconds > 0 && milliseconds <= 1.7976931348623157e308) printf "%.3f\n", milliseconds / 1000
        else exit 1
    }'
}

wiqd_plugin_posix_path() {
    local remaining="$1" normalized='' part
    [[ "$remaining" == /* ]] || remaining="$PWD/$remaining"
    while [[ -n "$remaining" ]]; do
        part="${remaining%%/*}"
        if [[ "$remaining" == */* ]]; then remaining="${remaining#*/}"; else remaining=''; fi
        case "$part" in
            ''|.) ;;
            ..) normalized="${normalized%/*}" ;;
            *) normalized+="/$part" ;;
        esac
    done
    printf '%s\n' "${normalized:-/}"
}

wiqd_plugin_public_source() {
    local source="$1"
    source="${source#"${source%%[![:space:]]*}"}"
    source="${source%"${source##*[![:space:]]}"}"
    source=$(printf '%s' "${source//\\//}" | tr '[:upper:]' '[:lower:]') || return 1
    source="${source#git+}"
    case "$source" in
        https://github.com/*) source="${source#https://github.com/}" ;;
        http://github.com/*) source="${source#http://github.com/}" ;;
        git@github.com:*) source="${source#git@github.com:}" ;;
    esac
    case "$source" in
        *.git/) source="${source%.git/}" ;;
        *.git) source="${source%.git}" ;;
    esac
    source="${source%/}"
    if [[ -n "${2:-}" ]]; then [[ "$source" == "$2" ]]; else [[ "$source" == microsoft/wiqd || "$source" == github/awesome-copilot ]]; fi
}

wiqd_plugin_path() {
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -am -- "$1" | tr '[:upper:]' '[:lower:]'
    else
        wiqd_plugin_posix_path "$1"
    fi
}

wiqd_plugin_owned() {
    local source="$1" root="$HOME/.wiqd/marketplace/wiqd" relative current
    [[ -z "${WIQD_MARKETPLACE_DIR:-}" && -d "$root" ]] || return 1
    [[ "$(wiqd_plugin_path "$source")" == "$(wiqd_plugin_path "$root")" ]] || return 1
    for relative in .github/plugin/plugin.json .claude-plugin/plugin.json; do
        current="$root/$relative"
        while [[ "$current" != / && "$current" != . ]]; do
            [[ -e "$current" && ! -L "$current" ]] || return 1
            current=$(dirname "$current")
        done
        wiqd_plugin_json manifest <"$root/$relative" >/dev/null 2>&1 || return 1
    done
}

wiqd_plugin_markets() {
    local cli="$1" parsed entry source owned local_source public_source target_source destination repository result='[]'
    destination=$(wiqd_plugin_json target "$cli") || return 1
    repository=$(wiqd_plugin_json field repository <<<"$destination") || return 1
    parsed=$(wiqd_plugin_read_inventory "$cli" markets plugin marketplace list) || return $?
    while IFS= read -r entry; do
        source=$(wiqd_plugin_json field source <<<"$entry") || return 1
        owned=false; local_source=false; public_source=false; target_source=false
        if wiqd_plugin_owned "$source"; then owned=true; fi
        if [[ "$(wiqd_plugin_path "$source")" == "$(wiqd_plugin_path "${WIQD_MARKETPLACE_DIR:-$HOME/.wiqd/marketplace/wiqd}")" ]]; then local_source=true; fi
        if wiqd_plugin_public_source "$source"; then public_source=true; fi
        if wiqd_plugin_public_source "$source" "$repository"; then target_source=true; fi
        result=$(wiqd_plugin_json market-add "$entry" "$owned" "$local_source" "$public_source" "$target_source" <<<"$result") || return 1
    done < <(wiqd_plugin_json entries <<<"$parsed")
    printf '%s\n' "$result"
}

wiqd_plugin_list() {
    local wiqd_plugin_require_native="${2:-false}"
    local wiqd_plugin_allow_no_match="${3:-false}"
    wiqd_plugin_read_inventory "$1" "$1-list" plugin list
}

wiqd_plugin_cache() {
    if [[ "$1" == copilot ]]; then
        [[ -d "$HOME/.copilot/installed-plugins/wiqd/wiqd" || -d "$HOME/.copilot/installed-plugins/awesome-copilot/wiqd" ]]
    else
        [[ -d "$HOME/.claude/plugins/cache/wiqd/wiqd" ]]
    fi
}

wiqd_plugin_inventory() {
    local cli markets plugins entry inventory='[]' allow_unknown="${1:-false}" install_cli="${2:-}" market_code plugin_code allow_no_match hosts='copilot claude'
    if [[ -n "$install_cli" ]]; then hosts="$install_cli"; fi
    for cli in $hosts; do
        if ! wiqd_plugin_host "$cli" >/dev/null 2>&1; then
            if wiqd_plugin_cache "$cli"; then printf '%s\n' "$cli is unavailable but a WIQD plugin cache exists. Restore the host to inspect native plugin inventory before retrying." >&2; return 1; fi
            continue
        fi
        market_code=0
        if [[ "$allow_unknown" != true ]]; then markets=$(wiqd_plugin_markets "$cli") || return $?; fi
        plugin_code=0
        allow_no_match=false
        if [[ "$allow_unknown" == true && "$install_cli" == "$cli" ]]; then allow_no_match=true; fi
        plugins=$(wiqd_plugin_list "$cli" false "$allow_no_match") || plugin_code=$?
        if [[ "$plugin_code" -ne 0 ]]; then
            if [[ "$allow_unknown" != true || "$plugin_code" -eq 130 || -f "$wiqd_plugin_directory/timed-out" ]]; then return "$plugin_code"; fi
            plugins='[]'
        fi
        if [[ "$allow_unknown" == true && "$install_cli" == "$cli" && "$plugin_code" -eq 0 ]] && wiqd_plugin_json public-plugin-shortcut "$cli" <<<"$plugins"; then
            wiqd_plugin_json fresh-public-host "$cli" <<<"$plugins"
            return $?
        fi
        if [[ "$allow_unknown" == true ]]; then markets=$(wiqd_plugin_markets "$cli") || market_code=$?; fi
        if [[ "$market_code" -ne 0 ]]; then
            if [[ "$allow_unknown" != true || "$market_code" -eq 130 || -f "$wiqd_plugin_directory/timed-out" ]]; then return "$market_code"; fi
            markets='[]'
        fi
        if [[ "$market_code" -ne 0 || "$plugin_code" -ne 0 ]]; then
            entry=$(wiqd_plugin_json partial-inventory "$cli" "$markets" "$plugins") || return 1
        else
            entry=$(wiqd_plugin_json inventory-entry "$cli" "$markets" "$plugins" "$allow_unknown") || return 1
        fi
        inventory=$(wiqd_plugin_json append "$entry" <<<"$inventory") || return 1
    done
    printf '%s\n' "$inventory"
}

wiqd_plugin_guard() {
    wiqd_plugin_json guard "$2" explain "$3" <<<"$1"
}

wiqd_plugin_mutation() {
    local attempt code=0
    for attempt in 1 2 3; do
        code=0
        wiqd_plugin_run "$@" || code=$?
        [[ "$code" -ne 0 ]] || return 0
        if [[ "$code" -eq 130 ]]; then wiqd_plugin_failure "$code" "$@"; return 130; fi
        if [[ "$code" -eq 124 || -f "$wiqd_plugin_directory/timed-out" ]]; then wiqd_plugin_failure "$code" "$@"; return 1; fi
        if [[ "$attempt" -eq 3 ]] || ! grep -Eiq 'EBUSY|EPERM|EACCES|being used by another process|resource busy|file.*locked' "$wiqd_plugin_directory/stderr"; then
            wiqd_plugin_failure "$code" "$@"; return 1
        fi
        if [[ "$attempt" -eq 1 ]]; then sleep 0.2; else sleep 0.4; fi
    done
}

wiqd_plugin_migrate() {
    local current="$1" internal="$2" fresh cli rechecked remaining markets source owned=true code=0
    cli=$(wiqd_plugin_json field cli <<<"$current") || return 1
    if [[ "$internal" == true ]]; then fresh=$(wiqd_plugin_inventory) || return $?
    else fresh=$(wiqd_plugin_inventory false "$cli") || return $?; fi
    rechecked=$(wiqd_plugin_json host "$cli" <<<"$fresh") || return 1
    if ! wiqd_plugin_json guard "$internal" "" "$cli" <<<"$fresh" || [[ "$current" != "$rechecked" || "$(wiqd_plugin_json field state <<<"$rechecked")" != local ]]; then
        printf '%s\n' "Plugin configuration changed during setup ($cli)." 'This migration stopped before uninstalling the old local WIQD plugin.' 'Let other plugin operations finish, then rerun this installer.' >&2; return 1
    fi
    printf '%s\n' "Migrating the old local WIQD plugin 'wiqd@wiqd' in $cli..." "Uninstalling the old local plugin 'wiqd@wiqd'..." >&2
    : >"$wiqd_plugin_directory/migration-started"
    wiqd_plugin_mutation "$cli" plugin uninstall wiqd@wiqd || return $?
    if [[ "$internal" == true ]]; then
        remaining=$(wiqd_plugin_list "$cli" true) || code=$?
        if [[ "$code" -eq 0 ]]; then markets=$(wiqd_plugin_markets "$cli") || code=$?; fi
        if [[ "$code" -ne 0 ]]; then
            [[ "$code" -ne 130 ]] || return 130
            printf '%s\n' "Migration of the old local WIQD plugin 'wiqd@wiqd' stopped in $cli." 'Current plugin state: unknown.' 'The installer has not removed the old marketplace.' 'Check the current setup:' "  $cli plugin list --json" "  $cli plugin marketplace list --json" 'Resolve the reported error, then rerun this installer.' >&2
            return "$code"
        fi
        source=$(wiqd_plugin_json source <<<"$current") || return 1
        wiqd_plugin_owned "$source" || owned=false
        if ! wiqd_plugin_json removable "$current" "$remaining" <<<"$markets" || ! $owned; then
            wiqd_plugin_json migration-error "$current" "$remaining" "$owned" <<<"$markets"
            return 1
        fi
    fi
    printf '%s\n' "Removing the old local marketplace 'wiqd' in $cli..." >&2
    wiqd_plugin_require "$cli" plugin marketplace remove wiqd
}

wiqd_plugin_public_inventory_fallback() {
    local cli="$1" current="${2:-}" destination plugin warning host_label=Copilot verb=install result=installed
    if [[ "$cli" == claude ]]; then host_label=Claude; fi
    destination=$(wiqd_plugin_json target "$cli") || return 1
    plugin=$(wiqd_plugin_json field id <<<"$destination") || return 1
    warning='Warning: Could not inspect existing WIQD plugins. Legacy migration was skipped. Attempting installation from the selected marketplace; duplicate active plugins may exist. Inspect host plugin settings before use.'
    if [[ -n "$current" ]]; then
        if wiqd_plugin_json fallback-duplicates "$cli" <<<"$current"; then printf '%s\n' 'Requested WIQD plugin identity is duplicated.' >&2; return 1; fi
        if [[ "$cli" == claude ]] && wiqd_plugin_json fallback-scope-conflict <<<"$current"; then printf '%s\n' 'Claude WIQD scope is not user. Existing state was not replaced.' >&2; return 1; fi
        if [[ "$cli" == claude ]] && ! wiqd_plugin_json inventory-unknown <<<"$current"; then
            warning='Warning: Existing Claude WIQD setup was not migrated. Attempting native marketplace registration from microsoft/wiqd and plugin installation. If a command fails, fix the reported cause and rerun this installer.'
        fi
        if [[ "$cli" == copilot ]] && wiqd_plugin_json update <<<"$current"; then verb=update; result=updated; fi
    fi
    printf '%s\n' "$warning" >&2
    if [[ "$cli" == claude ]]; then wiqd_plugin_mutation "$cli" plugin marketplace add microsoft/wiqd || return $?; fi
    wiqd_plugin_mutation "$cli" plugin "$verb" "$plugin" || return $?
    printf '%s\n' "WIQD plugin $result ($cli): $plugin. Check $host_label plugin settings for duplicate WIQD plugins." "$warning"
}

invoke_wiqd_plugin_helper() (
    local operation="${1:-}" cli=copilot internal=false inventory targets current verb destination repository plugin detected=false notice='' allow_migration_skip=false code=0
    case "$operation:$#" in
        install:1|check:1|migrate:1) ;;
        check:2|migrate:2) [[ "$2" == --allow-migration-skip ]] || return 2; allow_migration_skip=true ;;
        install:3) [[ "$2" == --cli && ( "$3" == copilot || "$3" == claude ) ]] || return 2; cli="$3" ;;
        *) printf '%s\n' 'Expected install [--cli copilot|claude], check, or migrate.' >&2; return 2 ;;
    esac
    [[ "$operation" == install ]] || internal=true
    if $internal; then
        for current in copilot claude; do
            if wiqd_plugin_host "$current" >/dev/null 2>&1 || wiqd_plugin_cache "$current"; then detected=true; fi
        done
        if ! $detected; then printf '[]\n'; return 0; fi
    fi
    if ! command -v node >/dev/null 2>&1; then
        printf '%s\n' 'Node.js is required for safe plugin inventory. Restore the Node.js runtime installed by this installer and retry, or use --skip-plugin to install only the CLI.' >&2
        return 2
    fi
    local wiqd_plugin_directory worker=''
    wiqd_plugin_directory=$(mktemp -d "${TMPDIR:-/tmp}/wiqd-plugin.XXXXXXXX") || return 2
    trap 'rm -rf -- "$wiqd_plugin_directory"' EXIT
    trap '[[ -z "$worker" ]] || wiqd_plugin_kill_tree "$worker"; exit 130' INT TERM
    (
    if [[ "$operation" == install ]]; then
        wiqd_plugin_require "$cli" --version || return $?
        wiqd_plugin_require "$cli" plugin marketplace --help || return $?
    fi
    code=0
    inventory=$(wiqd_plugin_inventory "$([[ "$operation" == install ]] && printf true || printf false)" "$([[ "$operation" == install ]] && printf '%s' "$cli")") || code=$?
    if [[ "$code" -ne 0 ]]; then
        if [[ "$operation" == install && "$code" -ne 130 && ! -f "$wiqd_plugin_directory/timed-out" ]]; then
            wiqd_plugin_public_inventory_fallback "$cli"
            return $?
        fi
        return "$code"
    fi
    if [[ "$operation" == install ]]; then
        current=$(wiqd_plugin_json host "$cli" <<<"$inventory") || return 1
        if wiqd_plugin_json fallback-duplicates "$cli" <<<"$current"; then printf '%s\n' 'Requested WIQD plugin identity is duplicated.' >&2; return 1; fi
        if [[ "$cli" == claude ]] && wiqd_plugin_json fallback-scope-conflict <<<"$current"; then printf '%s\n' 'Claude WIQD scope is not user. Existing state was not replaced.' >&2; return 1; fi
        if wiqd_plugin_json inventory-unknown <<<"$current"; then
            wiqd_plugin_public_inventory_fallback "$cli" "$current"; return $?
        fi
        if [[ "$cli" == claude ]] && wiqd_plugin_json claude-unverified-binding <<<"$current"; then
            wiqd_plugin_public_inventory_fallback "$cli" "$current"; return $?
        fi
    fi
    wiqd_plugin_guard "$inventory" "$internal" "$cli" || return $?
    targets=$(wiqd_plugin_json targets "$cli" "$internal" <<<"$inventory") || return 1
    while IFS= read -r current; do
        [[ -n "$current" ]] || continue
        wiqd_plugin_require "$(wiqd_plugin_json field cli <<<"$current")" plugin marketplace --help || return $?
    done <<<"$targets"
    if [[ "$operation" != check ]]; then
        while IFS= read -r current; do
            [[ -n "$current" ]] || continue
            wiqd_plugin_migrate "$current" "$internal" || return $?
        done <<<"$targets"
    fi
    if [[ "$operation" != install ]]; then printf '%s\n' "$inventory"; return 0; fi
    destination=$(wiqd_plugin_json target "$cli") || return 1
    repository=$(wiqd_plugin_json field repository <<<"$destination") || return 1
    plugin=$(wiqd_plugin_json field id <<<"$destination") || return 1
    current=$(wiqd_plugin_json host "$cli" <<<"$inventory") || return 1
    if [[ "$(wiqd_plugin_json field publicState <<<"$current")" == preserve ]] ||
       { [[ "$cli" == claude ]] && wiqd_plugin_json claude-remote-update <<<"$current"; }; then
        if [[ "$cli" == copilot ]]; then
            printf '%s\n' 'Updating WIQD from microsoft/wiqd in copilot...' >&2
            wiqd_plugin_mutation "$cli" plugin update wiqd@wiqd || return $?
            printf '%s\n' 'WIQD plugin ready (copilot): wiqd@wiqd from microsoft/wiqd.'
            return 0
        fi
        printf '%s\n' 'Updating WIQD from microsoft/wiqd in claude...' >&2
        wiqd_plugin_mutation "$cli" plugin update wiqd@wiqd || return $?
        printf '%s\n' 'WIQD plugin ready (claude): wiqd@wiqd from microsoft/wiqd.'
        return 0
    fi
    if wiqd_plugin_json duplicate-wiqd-plugins <<<"$current"; then
        printf '%s\n' 'Warning: Both wiqd@wiqd and wiqd@awesome-copilot are installed in Copilot; duplicate active plugins may coexist. Check Copilot plugin settings.' >&2
    elif wiqd_plugin_json coexistence-warning <<<"$current"; then
        notice="Warning: Other WIQD plugins in $cli are left untouched; duplicate active plugins may coexist. Inspect host plugin settings."
    fi
    if [[ -n "$notice" ]]; then
        printf '%s\n' "$notice" >&2
        printf '%s\n' "$notice"
    fi
    if [[ "$cli" == claude ]]; then
        wiqd_plugin_mutation "$cli" plugin marketplace add "$repository" || return $?
    fi
    verb=install
    if [[ -z "$targets" ]] && wiqd_plugin_json update <<<"$current"; then verb=update; fi
    if [[ "$verb" == update ]]; then printf '%s\n' "Updating WIQD from $repository in $cli..." >&2; else printf '%s\n' "Installing WIQD from $repository in $cli..." >&2; fi
    wiqd_plugin_mutation "$cli" plugin "$verb" "$plugin" || return $?
    printf '%s\n' "WIQD plugin ready ($cli): $plugin from $repository."
    ) &
    worker=$!
    wait "$worker" || code=$?
    if $allow_migration_skip && [[ "$code" -ne 0 && "$code" -ne 130 && ! -f "$wiqd_plugin_directory/timed-out" && ! -f "$wiqd_plugin_directory/migration-started" ]]; then
        return 3
    fi
    return "$code"
)
# native-plugin:end


install_wiqd_plugin() {
    invoke_wiqd_plugin_helper install --cli "$1"
}

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
    local i
    for ((i = 0; i < ${#packages[@]}; i++)); do
        if [[ "${packages[$i]}" == *.tgz && -e "${packages[$i]}" ]]; then
            local package_dir package_name
            package_dir=$(cd "$(dirname "${packages[$i]}")" && pwd -P) || return 1
            package_name=$(basename "${packages[$i]}")
            packages[$i]="$package_dir/$package_name"
        fi
    done

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
    # NPM_REGISTRY_ARGS is empty for normal installer flows. The guarded
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
    local npm_output npm_working_directory
    npm_working_directory=$(mktemp -d "${TMPDIR:-/tmp}/wiqd-npm.XXXXXXXX") || {
        write_err "Could not create an isolated npm working directory."
        return 1
    }
    if ! npm_output=$(cd "$npm_working_directory" && npm "${npm_args[@]}" 2>&1); then
        rm -rf "$npm_working_directory"
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
        # package — a purely LOCAL problem the GitHub fallback can't fix (it
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
        # GitHub fallback can't fix. Lead with the npm-recommended remedy
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
    rm -rf "$npm_working_directory"

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
    checks=$(printf '%s' "$json" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const c=((JSON.parse(s).data)||{}).checks||[];for(const x of c)process.stdout.write(`${x.name||""}\t${x.status||""}\t${x.message||""}\t${x.remediation||""}\n`);}catch(e){}});' 2>/dev/null || true)
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
    local -a c_name=() c_status=() c_msg=() c_remediation=() consumed=()
    local nm st ms remediation
    while IFS=$'\t' read -r nm st ms remediation; do
        [[ -z "$nm" ]] && continue
        c_name+=("$nm"); c_status+=("$st"); c_msg+=("$ms"); c_remediation+=("$remediation"); consumed+=(0)
    done <<< "$checks"

    # Display rows: "candidates::label::required::ok-word::note::extension-id::rerun::first-use::override-env".
    # Candidates are '|'-separated; `required=1` makes a miss fatal. An empty
    # check uses the extension id to print a registration repair; an emitted
    # managed failure uses doctor's own trimmed message and diagnostic command.
    local core_active=0 core_inactive=0 k
    for ((k = 0; k < ${#c_name[@]}; k++)); do
        [[ "${c_name[$k]}" == "Extensions" ]] || continue
        if [[ "${c_status[$k]}" != "error" ]] && extensions_check_has_id "${c_status[$k]}" "${c_msg[$k]}" active "microsoft.wiqd.core"; then
            core_active=1
        fi
        if extensions_check_has_id "${c_status[$k]}" "${c_msg[$k]}" inactive "microsoft.wiqd.core"; then
            core_inactive=1
        fi
        break
    done
    if [[ $core_active -ne 1 ]]; then
        if [[ $core_inactive -eq 1 ]]; then
            write_err "Lifecycle backend extension is inactive."
            write_hint "Re-run: wiqd ext add microsoft.wiqd.core"
            return 1
        fi
        write_err "Could not determine the active lifecycle backend from wiqd doctor."
        write_hint "Run 'wiqd doctor' and ensure microsoft.wiqd.core is active."
        return 1
    fi

    local backend_row="Extensions::fx-core::1::Active::(required for \`wiqd agent\` commands)::::1"
    local rows=(
        "$backend_row"
        "runevals::runevals::0::Installed::(optional - needed for \`wiqd agent eval\`)::microsoft.eval::1::wiqd agent eval::M365_COPILOT_EVAL_PATH"
        "workiq --json|workiq::workiq::0::Installed::(optional - needed for \`wiqd agent\` commands)::microsoft.workiq::1::wiqd agent list::WORKIQ_PATH"
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
    local cands label required okword note extension_id rerun first_use override_env status message remediation_kind padded idx k cc is_ok repair
    local -a cand_arr
    for row in "${rows[@]}"; do
        IFS=$'\x1e' read -ra parts <<< "${row//::/$'\x1e'}"
        cands=${parts[0]}; label=${parts[1]}; required=${parts[2]}
        okword=${parts[3]}; note=${parts[4]}; extension_id=${parts[5]}; rerun=${parts[6]}; first_use=${parts[7]:-}; override_env=${parts[8]:-}

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
            consumed[$idx]=1; status=${c_status[$idx]}; message=${c_msg[$idx]}; remediation_kind=${c_remediation[$idx]}
        else
            status=""; message=""; remediation_kind=""
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
            if [[ $idx -ge 0 && -n "$first_use" ]]; then
                if [[ "$status" == "error" ]]; then
                    case "$remediation_kind" in
                        clear-managed-override)
                            repair="clear or correct ${override_env}, then run wiqd doctor"
                            ;;
                        reinstall-host)
                            repair="npm uninstall -g @microsoft/wiqd, then re-run this installer"
                            ;;
                        managed-install-diagnostics)
                            repair="wiqd doctor --verbose"
                            ;;
                        *)
                            repair="wiqd doctor"
                            ;;
                    esac
                else
                    repair="$first_use"
                fi
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

    local install_status
    install_status=0
    install_npm_global_packages "$package_spec from npm registry" "$package_spec" || install_status=$?
    if [[ "$install_status" -ne 0 && "$LAST_NPM_ERROR_CODE" == "E404" ]]; then
        if [[ -n "$LAST_NPM_MISSING_SPEC" && "$LAST_NPM_MISSING_SPEC" != "$package_spec" ]]; then
            write_warn "A dependency ($LAST_NPM_MISSING_SPEC) of $package_spec was not found using your npm configuration."
        else
            write_warn "$package_spec was not found using your npm configuration."
        fi
    fi
    return "$install_status"
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
            local resolved npm_working_directory
            npm_working_directory=$(mktemp -d "${TMPDIR:-/tmp}/wiqd-npm.XXXXXXXX") || {
                echo "${version#v}"
                return
            }
            resolved=$(cd "$npm_working_directory" && npm view "${package}@${version}" version 2>/dev/null || true)
            rm -rf "$npm_working_directory"
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

record_install_provenance() {
    local directory="$HOME/.wiqd" marker="$HOME/.wiqd/install-method.json" temporary_path
    local url='https://aka.ms/wiqd/install.sh' arguments='[]'
    if ! mkdir -p "$directory" || [[ -d "$marker" ]]; then
        write_err 'Could not save install provenance. Re-run your intended installer.'
        return 1
    fi
    temporary_path=$(mktemp "$directory/.install-method.XXXXXX") || {
        write_err 'Could not save install provenance. Re-run your intended installer.' >&2
        return 1
    }
    local vscode_edition="stable"
    $INSIDERS && vscode_edition="insiders"
    if ! printf '{"version":1,"method":"bootstrap","vscodeEdition":"%s","installer":{"url":"%s","args":%s}}\n' "$vscode_edition" "$url" "$arguments" >"$temporary_path" ||
        ! mv -f "$temporary_path" "$marker"; then
        rm -f "$temporary_path"
        write_err 'Could not save install provenance. Re-run your intended installer.'
        return 1
    fi
}

normalize_update_result_home() {
    local home_directory="$1"
    while [[ "$home_directory" != "/" && "$home_directory" == */ ]]; do
        home_directory="${home_directory%/}"
    done
    [[ -n "$home_directory" ]] || home_directory="/"
    printf '%s\n' "$home_directory"
}

update_result_directory_for_home() {
    local home_directory
    home_directory=$(normalize_update_result_home "$1") || return 1
    if [[ "$home_directory" == "/" ]]; then
        printf '/.wiqd\n'
    else
        printf '%s/.wiqd\n' "$home_directory"
    fi
}

validate_update_result_path_location() {
    local path="$1" home_directory="${2:-$HOME}" expected_directory
    [[ -n "$path" ]] || return 1
    expected_directory=$(update_result_directory_for_home "$home_directory") || return 1
    [[ "$(dirname -- "$path")" == "$expected_directory" ]] || return 1
    [[ "$(basename -- "$path")" =~ ^\.update-result\.[0-9a-f]{32}\.json$ ]] || return 1
}

validate_update_result_path() {
    local path="${1:-$UPDATE_RESULT_PATH}" home_directory="${2:-$HOME}"
    validate_update_result_path_location "$path" "$home_directory" || return 1
    [[ ! -e "$path" && ! -L "$path" ]]
}

write_update_result() {
    local status="$1" reason="$2" path="${3:-$UPDATE_RESULT_PATH}" home_directory="${4:-$HOME}"
    if ! validate_update_result_path "$path" "$home_directory"; then
        write_err 'The wiqd update result path is invalid or untrusted.'
        return 1
    fi
    local vscode_edition="stable"
    $INSIDERS && vscode_edition="insiders"
    if ! (
        umask 077
        set -o noclobber
        printf '{"version":1,"extension":{"status":"%s","edition":"%s","reason":"%s"}}\n' \
            "$status" "$vscode_edition" "$reason" >"$path"
    ); then
        write_err 'Could not save the wiqd update result.'
        return 1
    fi
    if [[ ! -f "$path" || -L "$path" ]]; then
        rm -f "$path"
        write_err 'Could not save the wiqd update result.'
        return 1
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

if [[ -n "$UPDATE_RESULT_PATH" ]] && ! validate_update_result_path; then
    write_err 'The wiqd update result path is invalid or untrusted.'
    exit 1
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
    local white; white=$(fg 243 244 246)
    local dim; dim=$(fg 110 116 130)
    local bold="${e}[1m"

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
    printf "   %s▸%s %s%sWork IQ Dev Tools%s  %sv%s%s\n" "$purple" "$reset" "$bold" "$white" "$reset" "$dim" "$WIQD_INSTALLER_VERSION" "$reset"
    printf "     %sgithub.com/microsoft/wiqd%s\n" "$dim" "$reset"
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
# Eval and Work IQ are managed by their extension
# payloads and intentionally stay off PATH. Doctor reconciles active owners here;
# related commands retry the same lifecycle if this verification was incomplete.

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

# A missing REQUIRED dependency (the fx-core backend) is fatal: stop before the VS Code /
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

if ! record_install_provenance; then
    exit 1
fi

# ─────────────────────────────────────────────
# Step 4: VS Code Extension (optional)
# ─────────────────────────────────────────────

if ! $SKIP_VSCODE; then
    step_num=4
    vscode_partial_failure=false
    legacy_updater_invocation=false
    if is_legacy_wiqd_updater_invocation; then
        legacy_updater_invocation=true
    fi

    if $INSIDERS; then
        code_cmd="code-insiders"
        code_name="VS Code Insiders"
    else
        code_cmd="code"
        code_name="VS Code"
    fi

    write_step "$step_num" "$TOTAL_STEPS" "Installing $code_name extension..."

    if command_exists "$code_cmd"; then
        npm_root=$(npm root -g --loglevel=error 2>/dev/null || true)
        vsix_path="$npm_root/$WIQD_PACKAGE/vsix/wiqd.vsix"

        if [[ -z "$npm_root" || ! -f "$vsix_path" ]]; then
            if [[ -n "$UPDATE_RESULT_PATH" ]]; then
                write_update_result failed bundled-vsix-not-found || exit 1
                vscode_partial_failure=true
                write_warn "Could not find the bundled VS Code extension."
            elif $legacy_updater_invocation; then
                vscode_partial_failure=true
                write_warn "Could not find the bundled VS Code extension."
            else
                write_err "Could not find the bundled VS Code extension."
            fi
            write_hint "Reinstall $WIQD_PACKAGE, then re-run this installer."
            [[ -n "$UPDATE_RESULT_PATH" || "$legacy_updater_invocation" == true ]] || exit 1
        else
            extensions=$("$code_cmd" --list-extensions 2>/dev/null || true)
            extension_installed=false
            if echo "$extensions" | grep -qi "$VSCODE_EXTENSION_ID"; then
                extension_installed=true
            fi

            if $extension_installed && ! $FORCE; then
                write_ok "Work IQ extension already installed in $code_name"
                if [[ -n "$UPDATE_RESULT_PATH" ]]; then
                    write_update_result success already-installed || exit 1
                fi
            else
                if $extension_installed && $FORCE; then
                    write_info "Reinstalling Work IQ extension in $code_name (--force)..."
                fi
                if install_output=$("$code_cmd" --install-extension "$vsix_path" --force 2>&1); then
                    write_ok "Work IQ extension installed in $code_name"
                    if [[ -n "$UPDATE_RESULT_PATH" ]]; then
                        write_update_result success installed || exit 1
                    fi
                else
                    install_exit=$?
                    if [[ "$install_exit" -eq 130 ]]; then
                        exit 130
                    fi
                    if [[ -n "$UPDATE_RESULT_PATH" ]]; then
                        write_update_result failed install-failed || exit 1
                        vscode_partial_failure=true
                        write_warn "Could not install extension."
                    elif $legacy_updater_invocation; then
                        vscode_partial_failure=true
                        write_warn "Could not install extension."
                    else
                        write_err "Could not install extension."
                    fi
                    [[ -n "$install_output" ]] && sanitize_installer_output "$install_output" >&2
                    if quoted_vsix_path=$(quote_shell_literal "$vsix_path"); then
                        write_hint "Install manually: $code_cmd --install-extension $quoted_vsix_path --force"
                    else
                        write_hint "Manual install command unavailable because the bundled VSIX path contains a line break. Reinstall @microsoft/wiqd in a path without line breaks, then retry."
                    fi
                    [[ -n "$UPDATE_RESULT_PATH" || "$legacy_updater_invocation" == true ]] || exit 1
                fi
            fi
        fi
    else
        write_warn "$code_name not found — skipping extension install"
        write_hint "Install $code_name from https://code.visualstudio.com/"
        if [[ -n "$UPDATE_RESULT_PATH" ]]; then
            write_update_result not-available cli-not-found || exit 1
        fi
    fi
elif [[ -n "$UPDATE_RESULT_PATH" ]]; then
    write_update_result skipped requested || exit 1
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
        # Detect which supported host(s) are already on PATH. The shared
        # The embedded installer helper inventories every
        # host, proves and migrates WIQD's legacy local marketplace, rejects
        # unsafe local state, and installs the selected remote profile.
        # Keeping that logic in one handler gives PowerShell, Bash, and update
        # identical safety checks. If neither host is present, skip gracefully.
        plugin_hosts=()
        if command_exists copilot; then plugin_hosts+=(copilot); fi
        if command_exists claude; then plugin_hosts+=(claude); fi

        if [[ ${#plugin_hosts[@]} -eq 0 ]]; then
            write_info "No Copilot CLI or Claude Code detected — skipping plugin install."
            write_hint "Install one, then rerun this same WIQD installer."
        else
            for plugin_host in "${plugin_hosts[@]}"; do
                if plugin_output=$(install_wiqd_plugin "$plugin_host"); then
                    case "$plugin_output" in
                        'Keeping existing WIQD plugin ('*) ;;
                        *) write_ok "wiqd plugin setup completed for $plugin_host" ;;
                    esac
                    case "$plugin_output" in
                        *'duplicate active plugins may coexist.'*)
                            plugin_notices="${plugin_notices}${plugin_notices:+
}${plugin_output}" ;;
                    esac
                    if [[ -n "$plugin_output" ]]; then
                        printf '%s\n' "$plugin_output" >&2
                    fi
                    plugin_install_succeeded=true
                else
                    # Capture the command's own rc immediately — anything evaluated
                    # between the failed substitution and this point (even a failed
                    # `[[ ]]` test) would otherwise clobber $? before it's read.
                    rc=$?
                    case "$plugin_output" in
                        *'duplicate active plugins may coexist.'*)
                            plugin_notices="${plugin_notices}${plugin_notices:+
}${plugin_output}" ;;
                    esac
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
                    write_hint "Fix the reported cause, then rerun this same WIQD installer."
                    plugin_install_failed=true
                    failed_plugin_hosts+=("$plugin_host")
                fi
            done
        fi
    else
        write_warn "Skipping plugin install — wiqd CLI not verified on PATH"
        write_hint "Restart your terminal, then rerun this same WIQD installer."
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

    printf "${YELLOW} WIQD CLI installed; plugin setup incomplete for: %s.${RESET}\n" "${failed_plugin_hosts[*]}"
    printf "${GRAY} Follow the recovery steps above, then rerun this installer.${RESET}\n"
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
    if $PLUGIN_NON_FATAL && $install_success; then
        exit 76
    fi
    exit 1
fi
