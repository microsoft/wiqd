# Adaptive Cards in API Plugins

This reference covers how to use Adaptive Cards with `response_semantics` in API plugin manifests. Adaptive Cards provide structured, rich rendering of API responses in M365 Copilot.

## Overview

When an API plugin returns data, Copilot can render it as plain text or as a structured Adaptive Card. To enable card rendering, configure `response_semantics` in your API plugin's operation definition.

## response_semantics Structure

Add `response_semantics` to each operation in your API plugin manifest:

```json
{
  "name": "searchEmployees",
  "description": "Search the employee directory",
  "response_semantics": {
    "data_path": "$.results",
    "properties": {
      "title": "$.name",
      "subtitle": "$.title",
      "url": "$.profileUrl"
    },
    "static_template": {
      "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
      "type": "AdaptiveCard",
      "version": "1.5",
      "body": [...]
    }
  }
}
```

### Fields

| Field                 | Required | Description                                                             |
| --------------------- | -------- | ----------------------------------------------------------------------- |
| `data_path`           | Yes      | JSONPath expression to extract the data array from the API response     |
| `properties`          | No       | Maps semantic properties (title, subtitle, url) to JSONPath expressions |
| `properties.title`    | No       | Main display text — JSONPath into each result item                      |
| `properties.subtitle` | No       | Secondary text — JSONPath into each result item                         |
| `properties.url`      | No       | Clickable link — JSONPath into each result item                         |
| `static_template`     | No       | Full Adaptive Card template for custom rendering                        |

## Adaptive Card Template Basics

Adaptive Cards use a declarative JSON format. Key elements:

### TextBlock

```json
{
  "type": "TextBlock",
  "text": "${name}",
  "weight": "Bolder",
  "size": "Large",
  "wrap": true
}
```

Properties: `text`, `weight` (Default/Lighter/Bolder), `size` (Small/Default/Medium/Large/ExtraLarge), `color` (Default/Dark/Light/Accent/Good/Warning/Attention), `wrap`, `isSubtle`.

### ColumnSet / Column

```json
{
  "type": "ColumnSet",
  "columns": [
    {
      "type": "Column",
      "width": "auto",
      "items": [...]
    },
    {
      "type": "Column",
      "width": "stretch",
      "items": [...]
    }
  ]
}
```

### FactSet

Ideal for key-value data:

```json
{
  "type": "FactSet",
  "facts": [
    { "title": "Department", "value": "${department}" },
    { "title": "Email", "value": "${email}" },
    { "title": "Location", "value": "${office}" }
  ]
}
```

### Image

```json
{
  "type": "Image",
  "url": "${photoUrl}",
  "size": "Small",
  "style": "Person"
}
```

Properties: `url`, `size` (Auto/Stretch/Small/Medium/Large), `style` (Default/Person), `altText`.

### Container

```json
{
  "type": "Container",
  "style": "emphasis",
  "items": [...],
  "spacing": "Medium"
}
```

### ActionSet / Action.OpenUrl

```json
{
  "type": "ActionSet",
  "actions": [
    {
      "type": "Action.OpenUrl",
      "title": "View Profile",
      "url": "${profileUrl}"
    }
  ]
}
```

## Template Data Binding

Use `${property}` syntax to bind data from the API response. The data is scoped per-item when `data_path` extracts an array.

```json
{
  "type": "TextBlock",
  "text": "${name} — ${title}"
}
```

For nested objects:

```json
{
  "type": "TextBlock",
  "text": "${address.city}, ${address.state}"
}
```

## Complete Example: Employee Directory Card

```json
{
  "response_semantics": {
    "data_path": "$.results",
    "properties": {
      "title": "$.name",
      "subtitle": "$.title",
      "url": "$.profileUrl"
    },
    "static_template": {
      "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
      "type": "AdaptiveCard",
      "version": "1.5",
      "body": [
        {
          "type": "ColumnSet",
          "columns": [
            {
              "type": "Column",
              "width": "auto",
              "items": [
                {
                  "type": "Image",
                  "url": "${photoUrl}",
                  "size": "Small",
                  "style": "Person",
                  "altText": "${name}"
                }
              ]
            },
            {
              "type": "Column",
              "width": "stretch",
              "items": [
                {
                  "type": "TextBlock",
                  "text": "${name}",
                  "weight": "Bolder",
                  "size": "Medium",
                  "wrap": true
                },
                {
                  "type": "TextBlock",
                  "text": "${title} · ${department}",
                  "isSubtle": true,
                  "spacing": "None",
                  "wrap": true
                }
              ]
            }
          ]
        },
        {
          "type": "FactSet",
          "facts": [
            { "title": "📧 Email", "value": "${email}" },
            { "title": "📍 Office", "value": "${office}" },
            { "title": "📞 Phone", "value": "${phone}" }
          ]
        },
        {
          "type": "ActionSet",
          "actions": [
            {
              "type": "Action.OpenUrl",
              "title": "View Profile",
              "url": "${profileUrl}"
            }
          ]
        }
      ]
    }
  }
}
```

## MCP Plugin outputTemplate

For MCP plugins, rich rendering uses `outputTemplate` on individual tools instead of `response_semantics`:

```json
{
  "tools": [
    {
      "name": "get_pipeline_status",
      "description": "Get pipeline build status",
      "inputSchema": { ... },
      "annotations": {
        "readOnlyHint": true
      },
      "outputTemplate": {
        "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
        "type": "AdaptiveCard",
        "version": "1.5",
        "body": [
          {
            "type": "TextBlock",
            "text": "${pipelineName}",
            "weight": "Bolder",
            "size": "Medium"
          },
          {
            "type": "FactSet",
            "facts": [
              { "title": "Status", "value": "${status}" },
              { "title": "Duration", "value": "${duration}" },
              { "title": "Triggered By", "value": "${triggeredBy}" }
            ]
          }
        ]
      }
    }
  ]
}
```

## Best Practices

1. **Always set `data_path`** — Without it, Copilot cannot extract individual items from arrays
2. **Always set `properties.title`** — This is the fallback display when cards aren't supported
3. **Keep cards concise** — Show 3–5 key fields; link to full details via `Action.OpenUrl`
4. **Use FactSet for metadata** — Cleaner than multiple TextBlocks for key-value pairs
5. **Use Person style for avatars** — `"style": "Person"` renders circular profile images
6. **Set `wrap: true` on TextBlocks** — Prevents text truncation on narrow screens
7. **Use `isSubtle` for secondary info** — Helps establish visual hierarchy
8. **Test with Adaptive Card Designer** — https://adaptivecards.io/designer/ to preview layouts
9. **Version 1.5 is safe** — Supported across M365 Copilot surfaces; avoid 1.6+ features

## Limitations

- Maximum card payload: 28 KB
- No `Action.Submit` — Copilot does not support form submissions via cards
- No `Action.Execute` — Use `Action.OpenUrl` only
- Images must be HTTPS URLs accessible without authentication
- Template expressions (`${...}`) are case-sensitive
