# Assurance OS release gate

Fail a GitHub Actions job when an AI system's release gate in [Assurance OS](https://github.com/SVamseekar/eu-ai-assurance-os)
is `BLOCKED` — or `REVIEW`, if you choose. The gate is computed from the evidence, controls, evals, and approvals
tracked for that system. Optionally, also check the model card, approval record, and deployment record in your
repository with [`evgraph scan-promotion --gate`](https://pypi.org/project/evgraph-cli/).

## Usage

```yaml
name: AI release gate
on: [push, pull_request]

permissions:
  contents: read

jobs:
  gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: SVamseekar/assurance-os-release-gate@v1
        with:
          api-key: ${{ secrets.ASSURANCE_API_KEY }}
          system-id: ${{ vars.ASSURANCE_SYSTEM_ID }}
          api-url: ${{ vars.ASSURANCE_URL }}
```

Fail on `REVIEW` as well, and run the evgraph promotion scan on files in your repository:

```yaml
      - uses: SVamseekar/assurance-os-release-gate@v1
        with:
          api-key: ${{ secrets.ASSURANCE_API_KEY }}
          system-id: ${{ vars.ASSURANCE_SYSTEM_ID }}
          api-url: ${{ vars.ASSURANCE_URL }}
          fail-on: review
          evgraph-scan: governance/model_card.json governance/approval.json governance/deployment.json
```

Use the decision in later steps:

```yaml
      - id: gate
        uses: SVamseekar/assurance-os-release-gate@v1
        with: { api-key: "${{ secrets.ASSURANCE_API_KEY }}", system-id: "${{ vars.ASSURANCE_SYSTEM_ID }}", api-url: "${{ vars.ASSURANCE_URL }}" }
      - run: echo "Gate said ${{ steps.gate.outputs.decision }}"
```

## Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `api-key` | yes | | Assurance OS API key. Store it as a repository or organisation secret. |
| `system-id` | yes | | The AI system id shown in Assurance OS. |
| `api-url` | yes | | Base URL of your Assurance OS workspace, for example `https://app.example.com`. |
| `fail-on` | no | `blocked` | `blocked` fails only on `BLOCKED`; `review` also fails on `REVIEW`. |
| `evgraph-scan` | no | | Three space-separated paths: model card, approval record, deployment record. Runs `evgraph scan-promotion --gate`. |
| `evgraph-version` | no | `0.1.3` | `evgraph-cli` version installed for `evgraph-scan`. |

## Outputs

| Output | Description |
|---|---|
| `decision` | `PASS`, `REVIEW`, or `BLOCKED`. |
| `blockers` | JSON array of blocker strings, for example `["CONTROL:HUMAN_OVERSIGHT"]`. |

## Behaviour

| Situation | Job |
|---|---|
| `PASS` | passes |
| `REVIEW` | passes (fails with `fail-on: review`) |
| `BLOCKED` | fails, blockers listed in the log and job summary |
| Wrong API key, unknown system, plan limit, any non-200 answer | fails with `Assurance OS returned HTTP <status>: <message>` |
| API unreachable or timed out (30 s) | fails with `HTTP 000` |
| Answer is not a release-gate response | fails |
| `evgraph-scan` finds an inconsistency | fails, report in the job summary |

The action never passes when it cannot read a decision.

The job summary looks like this:

```
### Assurance OS release gate: BLOCKED

- CONTROL:HUMAN_OVERSIGHT
- Missing evidence: DPIA

Evidence and readiness signal, not legal advice.
```

## How to get an API key

1. Sign in to your Assurance OS workspace.
2. Open **Settings → API keys** and create a key named after the repository (for example `ci-claims-triage`).
3. Copy the key once; it is not shown again. Add it as the `ASSURANCE_API_KEY` secret in
   **GitHub → Settings → Secrets and variables → Actions**.
4. Add `ASSURANCE_SYSTEM_ID` (from the system's page) and `ASSURANCE_URL` as repository variables.

Each call counts as one gate run on your plan.

## Versions

`@v1` follows the newest `v1.x.y`, so you get fixes without editing your workflow. Breaking changes ship as `v2`.
Each `vX.Y.Z` release is immutable: its tag cannot be moved or deleted.

If your organisation requires actions pinned to a commit, pin the SHA of a release and keep the version as a
comment. Dependabot then opens a pull request for each new release:

```yaml
      - uses: SVamseekar/assurance-os-release-gate@<commit-sha> # v1.0.0
```

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
```

Runs on GitHub-hosted Ubuntu and macOS runners, and on self-hosted runners with `bash`, `curl` and `jq`
(`python3` as well for `evgraph-scan`).

## Development

```bash
bash test/run.sh          # gate script against test/mock-server.py
bash test/run-evgraph.sh  # evgraph step against test/fixtures (installs evgraph-cli unless EVGRAPH_BIN is set)
```

`.github/workflows/self-test.yml` runs both and exercises the action itself (`uses: ./`) against the mock server.

## Disclaimer

The release gate is an evidence and readiness signal. It is not legal advice and does not certify conformity with
any law or standard.

## License

[MIT](LICENSE)
