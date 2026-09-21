/**
 * wiqd-agent-enforcer
 * --------------------
 * Project-scoped Copilot CLI extension that enforces routing of M365
 * declarative agent edits through the `wiqd` skill.
 *
 * Why this exists:
 *   Skill discovery via SKILL.md descriptions is best-effort. The model
 *   sometimes bypasses wiqd and invokes raw `edit`/`create` on
 *   agent files (declarativeAgent.json, manifest.json, m365agents.yml,
 *   plugin manifests, etc.). This extension closes that gap by denying
 *   raw mutations to agent-owned paths until `skill(wiqd)` is
 *   invoked at least once in the session.
 *
 * To disable for a single session: delete or rename this file before
 * launching `copilot`.
 */
import { joinSession } from '@github/copilot-sdk/extension';
import { appendFileSync } from 'node:fs';
import { join } from 'node:path';

const DEBUG_LOG = process.env.WIQD_ENFORCER_DEBUG
  ? join(process.cwd(), '.wiqd-enforcer.log')
  : null;

function debugLog(msg) {
  if (!DEBUG_LOG) return;
  try {
    appendFileSync(DEBUG_LOG, `${new Date().toISOString()} ${msg}\n`);
  } catch {}
}

let wiqdInvoked = false;

const MUTATION_TOOLS = new Set(['edit', 'create', 'write']);

const MARKER_FILES = new Set([
  'm365agents.yml',
  'm365agents.local.yml',
  'teamsapp.yml',
  'teamsapp.local.yml',
]);

function isAgentOwnedPath(rawPath) {
  if (!rawPath) return false;
  const p = String(rawPath).replace(/\\/g, '/');
  if (p.includes('/appPackage/')) return true;
  const fileName = p.toLowerCase().split('/').pop();
  return MARKER_FILES.has(fileName);
}

// Defensive field-name extraction: SDK historically used `toolName`/`toolArgs`,
// but accept `name`/`arguments` as fallbacks in case wire format changes.
function extractTool(input) {
  const toolName = input?.toolName ?? input?.name ?? input?.tool ?? '';
  const toolArgs = input?.toolArgs ?? input?.arguments ?? input?.args ?? input?.input ?? {};
  return { toolName, toolArgs };
}

debugLog(`extension loaded pid=${process.pid} cwd=${process.cwd()}`);

try {
  await joinSession({
    hooks: {
      onPreToolUse: async (rawInput) => {
        try {
          const { toolName, toolArgs } = extractTool(rawInput);
          debugLog(
            `preToolUse tool=${toolName} path=${toolArgs?.path ?? ''} wiqdInvoked=${wiqdInvoked}`,
          );

          if (toolName === 'skill') {
            const name = toolArgs?.name || toolArgs?.skillName || toolArgs?.skill;
            if (name === 'wiqd') {
              wiqdInvoked = true;
              debugLog(`wiqd skill invoked - gate lifted`);
            }
            return;
          }

          if (!MUTATION_TOOLS.has(toolName)) return;
          if (wiqdInvoked) return;

          const filePath = toolArgs?.path;
          if (!isAgentOwnedPath(filePath)) return;

          debugLog(`DENY ${toolName} on ${filePath}`);
          return {
            permissionDecision: 'deny',
            permissionDecisionReason:
              'This file is part of an M365 declarative agent project. ' +
              'You MUST invoke skill(wiqd) before editing files under ' +
              'appPackage/, m365agents.yml, or teamsapp.yml. ' +
              'Call skill(wiqd) first to load the wiqd skill, ' +
              'then retry this edit.',
          };
        } catch (err) {
          debugLog(`HOOK ERROR: ${err?.stack ?? err}`);
          return {
            permissionDecision: 'deny',
            permissionDecisionReason: `wiqd-agent-enforcer hook error: ${err?.message ?? err}`,
          };
        }
      },
    },
  });
  debugLog(`joinSession completed`);
} catch (err) {
  debugLog(`joinSession FAILED: ${err?.stack ?? err}`);
  throw err;
}
