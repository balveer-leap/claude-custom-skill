# Claude Estate Review

A pull request reviewer for codebases split across many repositories, built on
[Claude Code](https://docs.claude.com/en/docs/claude-code/overview).

Most AI reviewers only see the repository the PR is in. When a change alters what a field
*means*, the code that breaks usually lives in another repository that never imports the
changed package. This reviewer clones those sibling repositories read-only, traces every value
the diff writes into the code that consumes it (up to three repositories out), and ends with an
explicit **safe to merge** / **not safe to merge** verdict.

## How it works

1. **Sibling repos as context.** Before the review, read-only, history-free clones of the other
   repositories in your estate go into `.estate/`.
2. **A review method, not just "review this".** Claude is told to:
   1. state what changes at runtime, and check the diff itself for races, leaks, dropped errors,
      changed defaults and boundary bugs;
   2. find every consumer of every value the diff writes, by field name, route, schema key and
      event name, not only by imports;
   3. follow each consumer to its consumers, up to three hops;
   4. anchor every claim to a file and line, or leave it out;
   5. treat READMEs and comments as claims to verify, not evidence;
   6. try to break the change before calling it correct;
   7. report defects even when nothing calls the code yet;
   8. give a merge verdict.
3. **Read-only.** Claude gets `Read`, `Grep`, `Glob` and `LS` only: no shell and no web access.

The full prompt is in [`prompts/review-v2.md`](prompts/review-v2.md).

## Quick start (GitHub Action)

1. In **each** repository of your estate, add `.github/workflows/claude-review.yml`:

   ```yaml
   name: Claude Review
   on:
     pull_request:
       types: [opened, synchronize, reopened, ready_for_review]
   concurrency:
     group: claude-review-${{ github.event.pull_request.number }}
     cancel-in-progress: true
   jobs:
     review:
       if: >-
         github.event.pull_request.draft == false &&
         github.event.pull_request.head.repo.full_name == github.repository
       runs-on: ubuntu-latest
       timeout-minutes: 30
       permissions:
         contents: read
         pull-requests: write
         issues: write
         id-token: write
         actions: read
       steps:
         - uses: actions/checkout@v6
           with:
             fetch-depth: 1
         - uses: open-legacyleap/claude-custom-skill@v1
           with:
             claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
             estate_repos: ${{ vars.ESTATE_REPOS }}
   ```

   The same file is in [`examples/claude-review.yml`](examples/claude-review.yml).

2. Install the [Claude GitHub App](https://github.com/apps/claude) on those repositories (it
   posts the review comment), or pass your own `github_token`.
3. Add a secret: `CLAUDE_CODE_OAUTH_TOKEN` (run `claude setup-token`), or `ANTHROPIC_API_KEY` and
   use `anthropic_api_key:` instead.
4. Add a variable `ESTATE_REPOS` listing the repositories of your estate, for example
   `billing ledger notifications web`. Setting it at organisation level lets every repository
   share one list; each repository skips itself.

Open a PR. The review arrives as a comment on it.

### Inputs

| Input | Default | What it does |
| --- | --- | --- |
| `claude_code_oauth_token` / `anthropic_api_key` | | One is required. |
| `estate_repos` | empty | Sibling repos, separated by spaces, commas or newlines. Accepts `name`, `owner/name`, GitHub URLs, and `@branch` or `@tag`. Bare names use this repository's owner. Empty means single-repository mode. |
| `estate_token` | empty | Read token for **private** siblings. Never written to disk. |
| `require_estate` | `true` | Fail rather than review when a listed sibling cannot be cloned. Set `false` to review with what was cloned. |
| `method` | `v2` | `v2` (8 steps) or `v1` (the earlier 6-step method, cross-repo only). |
| `extra_instructions` | empty | Text appended to the prompt: house rules, areas to focus on. |
| `max_turns` | `80` | Agent turn limit. Raise it for very large estates. |
| `model` | Claude Code default | Model id, for example `claude-sonnet-5-5`. |
| `github_token` | Claude App token | Token used to post the review. |

### Private siblings

Create a fine-grained token with **Contents: read** on the sibling repositories, store it as
`ESTATE_TOKEN`, and pass `estate_token: ${{ secrets.ESTATE_TOKEN }}`. The token is sent as a
per-command header, the clones keep no `.git` directory, and the job stops if the token is
found anywhere in `.estate/`.

### Pull requests from forks

GitHub does not give workflows triggered by fork PRs access to secrets, so the example skips
them. Do not switch to `pull_request_target` to get around this: it would run with your secrets
on untrusted code.

## Use it locally (Claude Code plugin)

```
/plugin marketplace add open-legacyleap/claude-custom-skill
/plugin install estate-review@legacyleap
```

Clone the sibling repositories into `.estate/` in the repository you are reviewing (or tell
Claude where they are), then:

```
/estate-review review the changes on this branch against main
```

## Without the action

[`standalone/`](standalone/) has self-contained workflow files that need no external action
besides `anthropics/claude-code-action`: copy one, set `ESTATE_REPOS` (as `owner/name`
entries), and you are done. These are the exact review prompts we benchmarked.

## Repository layout

```
action.yml                 the GitHub Action
prompts/review-v2.md       the review method (default)
prompts/review-v1.md       the earlier 6-step method
scripts/clone-estate.sh    clones siblings safely; tested in tests/
skills/estate-review/      the same method as a Claude Code skill
.claude-plugin/            plugin + marketplace manifests
standalone/                self-contained workflow files
examples/                  copy-paste workflow
```

## Development

```bash
bash tests/test-clone-estate.sh   # clone script, against local repositories
bash tests/test-prompts.sh        # every copy of the method says the same thing
shellcheck scripts/*.sh tests/*.sh
```

## Contributors

- Rajat Singhal (CTO, Legacyleap)
- Balveer Singh (Senior Data Scientist, Legacyleap)
- Dhruv Kapur (Data Architect, Legacyleap)

## License

MIT. See [LICENSE](LICENSE).
