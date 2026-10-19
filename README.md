# fleet-review

Thin GitHub composite action. It runs
[jbot slim](https://github.com/pgup-ai/jbot-review-action) with fleet
defaults. Each caller checks out the PR head first.

This is not a jbot fork. Change defaults here. Move the `v1` tag. Callers
keep `uses: tomagranate/fleet-review@v1`.

## Defaults

- Model: `opencode/deepseek-v4.1-flash-free` (free on OpenCode Zen)
- Two review passes, then verify findings
- At most two model sessions at once (free tiers throttle)
- If the free run fails (for example, on rate limits), run again once on
  `opencode-go/deepseek-v4.1-flash` with one review pass. This one costs money.
- Skip docs-only and unchanged patches
- No auto-approve
- 12 minute model budget on the free run, 15 on the paid run, so both fit
  in a 30 minute job

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
        description: Model pool override (empty uses the action default)
        required: false
        default: ""

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
          model: ${{ inputs.model }}
          pr-number: ${{ inputs.pr-number || '' }}
```

Set `OPENCODE_API_KEY` on the caller repo. Runners need the labels
`self-hosted`, `linux`, and `fleet`.

## Release

The action drops leftover jbot containers and root-owned review files
before it starts. Primer's github-runner unit does the same on start and
stop.

Pin jbot by SHA in `action.yml`. Tag the commit `v1.0.0`. Point the
moving `v1` tag at that commit.
