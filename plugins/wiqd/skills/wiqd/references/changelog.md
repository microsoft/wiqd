# Changelog

**Telemetry:** `--skill wiqd` on every ordinary `wiqd` command.

View wiqd release notes and version history. No auth, project, or ATK required.

```bash
wiqd changelog --skill wiqd                           # current version
wiqd changelog --version 0.1.5 --skill wiqd           # specific version
wiqd changelog --from 0.1.0 --skill wiqd              # all since 0.1.0
wiqd changelog --from 0.1.0 --to 0.1.5 --skill wiqd   # version range
wiqd changelog --json --skill wiqd                    # JSON output
wiqd changelog --markdown --skill wiqd                # Markdown output
```

## Intent mapping

Translate the user's natural-language request into flags — don't just dump the current version:

| User says…                                              | Run this                                                |
| ------------------------------------------------------- | ------------------------------------------------------- |
| "changes since 0.1.0", "what's new since X", "from X"   | `wiqd changelog --from <X> --skill wiqd`                |
| "in JSON", "so I can parse it", "machine-readable"       | add `--json`                                            |
| "as markdown", "release notes", "for the docs"           | add `--markdown`                                        |
| "between X and Y", "from X to Y"                          | `wiqd changelog --from <X> --to <Y> --skill wiqd`       |
| "what's in version X", "the X release"                   | `wiqd changelog --version <X> --skill wiqd`             |

Combine flags as needed. Example — "Get the changelog in JSON so I can parse it, since 0.1.0":

```bash
wiqd changelog --json --from 0.1.0 --skill wiqd
```

Always echo the exact command you ran so the user can re-run or script it.

## Options

| Flag | Description |
|------|-------------|
| `--version` | Show changelog for a specific version |
| `--from` | Start of version range (exclusive lower bound) |
| `--to` | End of version range (inclusive upper, default: latest) |
| `--json` | Emit the JSON envelope (mutually exclusive with `--markdown`) |
| `--markdown` | Emit Keep-a-Changelog markdown (mutually exclusive with `--json`) |

**Exit codes:** 0 = success, 1 = version not found, 130 = cancelled.
