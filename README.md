# fleet-review

Thin GitHub composite action. It runs
[jbot slim](https://github.com/pgup-ai/jbot-review-action) with fleet
defaults. Each caller checks out the PR head first.

This is not a jbot fork. Change defaults here. Move the `v1` tag. Callers
keep `uses: tomagranate/fleet-review@v1`.

## Defaults

- Model: `opencode-go/deepseek-v4.1-flash` (paid on OpenCode Go)
- One review pass, then verify findings
- Auto shards: jbot splits large diffs into up to four parallel shards
- At most four model sessions at once, one for each shard
- Skip docs-only and unchanged patches
- No auto-approve
- 16 minute model budget, so each main review session gets about 10 minutes
  and the run fits in a 30 minute job

The free OpenCode Zen tier is not used. On large PRs it ran out of time on
every run, and the paid run had to start again after it.

`runs-on` and the draft/fork skip stay in each caller. A composite action
cannot set those job fields.

Large patches can need more time to finish every review task. Set
`time-budget-minutes` on the action to raise the budget. Set the caller's job
timeout above it, with room for setup and cleanup. For example, a 45-minute
budget fits within a 70-minute job:

```yaml
jobs:
  review:
    timeout-minutes: 70
    # Keep the runner, checkout, permissions, and other settings shown below.
    steps:
      - uses: tomagranate/fleet-review@v1
        with:
          opencode-api-key: ${{ secrets.OPENCODE_API_KEY }}
          time-budget-minutes: "45"
```

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
