# fleet-review

Thin GitHub composite action. It runs
[jbot slim](https://github.com/pgup-ai/jbot-review-action) with fleet
defaults. Each caller checks out the PR head first.

This is not a jbot fork. Change defaults here. Move the `v1` tag. Callers
keep `uses: tomagranate/fleet-review@v1`.

## Defaults

- Pool: `opencode-go/deepseek-v4.1-flash`, `opencode-go/deepseek-v4-flash`,
  `opencode-go/glm-5.3-flash`
- Two review passes, then verify findings
- Skip docs-only and unchanged patches
- No auto-approve
- 20 minute model budget

`runs-on` and the draft/fork skip stay in each caller. A composite action
cannot set those job fields.

## Caller workflow

Each repo keeps a short workflow. Put it at
`.github/workflows/pr-fleet-review.yml`.

```yaml
name: Fleet review

on:
  pull_request:
    types: [opened, reopened, ready_for_review, synchronize]
  workflow_dispatch:
    inputs:
      pr-number:
        description: Pull request number to review
        required: true
      model:
        description: Model pool override
        required: false
        default: opencode-go/deepseek-v4.1-flash,opencode-go/deepseek-v4-flash,opencode-go/glm-5.3-flash

concurrency:
  group: fleet-review-${{ github.event.pull_request.number || inputs.pr-number }}
  cancel-in-progress: true

permissions:
  contents: read
  pull-requests: write
  issues: write
  checks: read

jobs:
  review:
    if: >-
      github.event_name != 'pull_request' ||
      (github.event.pull_request.draft == false &&
       github.event.pull_request.head.repo.full_name == github.repository)
    runs-on: [self-hosted, linux, fleet]
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@d23441a48e516b6c34aea4fa41551a30e30af803 # v6
        with:
          fetch-depth: 0
          persist-credentials: false
          clean: false
          ref: ${{ github.event.pull_request.head.sha || format('refs/pull/{0}/head', inputs.pr-number) }}
      - uses: tomagranate/fleet-review@v1
        with:
          opencode-api-key: ${{ secrets.OPENCODE_API_KEY }}
          model: ${{ inputs.model || 'opencode-go/deepseek-v4.1-flash,opencode-go/deepseek-v4-flash,opencode-go/glm-5.3-flash' }}
          pr-number: ${{ inputs.pr-number || '' }}
```

Set `OPENCODE_API_KEY` on the caller repo. Runners need the labels
`self-hosted`, `linux`, and `fleet`.

## Release

Pin jbot and checkout by SHA in `action.yml`. Tag the commit `v1.0.0`.
Point the moving `v1` tag at that commit.
