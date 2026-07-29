#!/usr/bin/env node
// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

// generate-docs-index.js — Walks docs/src/content/docs/ and produces a JSON search index.
// Uses only Node.js built-in modules. Output goes to stdout or --output <path>.

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const DOCS_ROOT = path.resolve(__dirname, '..', 'src', 'content', 'docs');
const BASE_URL = 'https://aka.ms/wiqd/docs';
const MAX_BODY_LENGTH = 2000;
const MAX_DESCRIPTION_LENGTH = 200;

// Changelog scrubbing is neutralized in the mirror: the public changelog is
// already cleaned upstream by the release pipeline, so this marker filter is a
// never-match no-op kept only to preserve the search-index code path.
const CHANGELOG_ID = 'project/changelog';
const CHANGELOG_MARKER = /(?!)/i;

function parseArgs() {
  const args = process.argv.slice(2);
  let outputPath = null;
  let excludeSections = new Set();
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--output' && i + 1 < args.length) {
      outputPath = args[i + 1];
      i++;
    } else if (args[i] === '--exclude-sections' && i + 1 < args.length) {
      for (const s of args[i + 1].split(',')) {
        const trimmed = s.trim();
        if (trimmed) excludeSections.add(trimmed);
      }
      i++;
    }
  }
  return { outputPath, excludeSections };
}

function getGitCommit() {
  try {
    return execSync('git rev-parse --short HEAD', { encoding: 'utf-8' }).trim();
  } catch {
    return 'unknown';
  }
}

function walkDir(dir, exts) {
  let results = [];
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return results;
  }
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results = results.concat(walkDir(fullPath, exts));
    } else if (entry.isFile() && exts.some((ext) => entry.name.endsWith(ext))) {
      results.push(fullPath);
    }
  }
  return results;
}

function parseFrontmatter(content) {
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!match) return { frontmatter: {}, body: content };

  const rawYaml = match[1];
  const frontmatter = {};
  for (const line of rawYaml.split(/\r?\n/)) {
    const colonIdx = line.indexOf(':');
    if (colonIdx === -1) continue;
    const key = line.slice(0, colonIdx).trim();
    let value = line.slice(colonIdx + 1).trim();
    // Skip complex YAML (nested objects, arrays)
    if (value.startsWith('{') || value.startsWith('[') || value === '') continue;
    // Strip surrounding quotes
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    frontmatter[key] = value;
  }

  const body = content.slice(match[0].length).trim();
  return { frontmatter, body };
}

function extractHeadings(body) {
  const headings = [];
  for (const line of body.split(/\r?\n/)) {
    const m = line.match(/^(#{1,6})\s+(.+)/);
    if (m) {
      headings.push(m[2].trim());
    }
  }
  return headings;
}

function stripMarkdown(body) {
  let text = body;

  // Remove MDX import/export statements
  text = text.replace(/^(import|export)\s+.*$/gm, '');

  // Remove Starlight admonition containers (:::tip, :::note, :::caution, :::danger, etc.)
  text = text.replace(/^:::\w+.*$/gm, '');
  text = text.replace(/^:::$/gm, '');

  // Handle fenced code blocks: keep only the first line of content
  text = text.replace(/```[^\n]*\n([\s\S]*?)```/g, (_, blockContent) => {
    const lines = blockContent.split(/\r?\n/).filter((l) => l.trim() !== '');
    return lines.length > 0 ? lines[0] : '';
  });

  // Remove inline code backticks but keep content
  text = text.replace(/`([^`]*)`/g, '$1');

  // Remove HTML/JSX tags
  text = text.replace(/<[^>]+>/g, '');

  // Remove MDX component blocks (self-closing and block)
  text = text.replace(/<\w+[^>]*\/>/g, '');

  // Remove images
  text = text.replace(/!\[.*?\]\(.*?\)/g, '');

  // Convert links to just text
  text = text.replace(/\[([^\]]*)\]\([^)]*\)/g, '$1');

  // Remove heading markers
  text = text.replace(/^#{1,6}\s+/gm, '');

  // Remove bold/italic markers
  text = text.replace(/\*{1,3}([^*]+)\*{1,3}/g, '$1');
  text = text.replace(/_{1,3}([^_]+)_{1,3}/g, '$1');

  // Remove horizontal rules
  text = text.replace(/^[-*_]{3,}\s*$/gm, '');

  // Remove table formatting
  text = text.replace(/^\|.*\|$/gm, (line) => {
    // Skip separator rows
    if (/^\|[-:\s|]+\|$/.test(line)) return '';
    return line.replace(/\|/g, ' ').trim();
  });

  // Collapse multiple blank lines and trim
  text = text.replace(/\n{3,}/g, '\n\n').trim();

  // Collapse multiple spaces
  text = text.replace(/ {2,}/g, ' ');

  return text;
}

function extractDescription(frontmatter, strippedBody) {
  if (frontmatter.description) {
    return frontmatter.description.slice(0, MAX_DESCRIPTION_LENGTH);
  }
  // First paragraph: text up to the first double-newline
  const firstPara = strippedBody.split(/\n\n/)[0] || '';
  const cleaned = firstPara.replace(/\n/g, ' ').trim();
  if (cleaned.length <= MAX_DESCRIPTION_LENGTH) return cleaned;
  return cleaned.slice(0, MAX_DESCRIPTION_LENGTH - 3) + '...';
}

function filePathToSlug(filePath, frontmatter) {
  if (frontmatter.slug != null && frontmatter.slug !== '') {
    return frontmatter.slug.replace(/^\/+|\/+$/g, '');
  }

  let relative = path.relative(DOCS_ROOT, filePath).replace(/\\/g, '/');
  // Remove extension
  relative = relative.replace(/\.(md|mdx)$/, '');
  // Collapse index to parent
  relative = relative.replace(/\/index$/, '');
  // Handle root index
  if (relative === 'index') relative = '';

  return relative;
}

function extractSection(filePath) {
  const relative = path.relative(DOCS_ROOT, filePath).replace(/\\/g, '/');
  const parts = relative.split('/');
  // If the file is at the root (e.g., index.mdx), section is empty
  if (parts.length <= 1) return '';
  return parts[0];
}

function processFile(filePath) {
  let content;
  try {
    content = fs.readFileSync(filePath, 'utf-8');
  } catch {
    return null;
  }

  // Skip binary or empty files
  if (!content || content.includes('\0')) return null;

  const { frontmatter, body } = parseFrontmatter(content);
  let title = frontmatter.title;

  // Fall back to the first H1 heading when frontmatter title is absent
  if (!title) {
    const h1Match = body.match(/^#\s+(.+)/m);
    if (h1Match) {
      title = h1Match[1].trim();
    }
  }

  if (!title) return null;

  const slug = filePathToSlug(filePath, frontmatter);
  const id = slug;
  const section = extractSection(filePath);

  // Strip 1P-marker changelog lines before indexing so the public offline index
  // never carries 1P history the rendered site already scrubs.
  const indexBody =
    id === CHANGELOG_ID
      ? body
          .split(/\r?\n/)
          .filter((line) => !CHANGELOG_MARKER.test(line))
          .join('\n')
      : body;

  const headings = extractHeadings(indexBody);
  let strippedBody = stripMarkdown(indexBody);

  if (strippedBody.length > MAX_BODY_LENGTH) {
    strippedBody = strippedBody.slice(0, MAX_BODY_LENGTH - 3) + '...';
  }

  const description = extractDescription(frontmatter, strippedBody);
  // Use deep-link format (?id=slug) so the single aka.ms redirect works
  const url = slug ? `${BASE_URL}?id=${slug}` : BASE_URL;

  return { id, title, description, section, headings, body: strippedBody, url };
}

function main() {
  const { outputPath, excludeSections } = parseArgs();

  if (!fs.existsSync(DOCS_ROOT)) {
    console.error(`Error: docs root not found at ${DOCS_ROOT}`);
    process.exit(1);
  }

  const files = walkDir(DOCS_ROOT, ['.md', '.mdx']);
  const entries = [];

  for (const filePath of files) {
    const entry = processFile(filePath);
    if (entry && !excludeSections.has(entry.section)) entries.push(entry);
  }

  entries.sort((a, b) => a.id.localeCompare(b.id));

  const index = {
    generatedFromCommit: getGitCommit(),
    generatedAt: new Date().toISOString(),
    entries,
  };

  const json = JSON.stringify(index, null, 2);

  if (outputPath) {
    const dir = path.dirname(outputPath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(outputPath, json, 'utf-8');
    console.error(`Wrote ${entries.length} entries to ${outputPath}`);
  } else {
    process.stdout.write(json + '\n');
  }
}

main();
