# claude-custom-skill

An estate-aware pull request reviewer built on the Claude Code GitHub Action. It reviews a PR
in one repository of a multi-repository estate and traces every value the diff writes into the
sibling repositories that consume it. Every claim is anchored to a file and line, and every review
ends with a "safe to merge" / "not safe to merge" verdict.

It differs from the out-of-the-box Claude Code action in two ways:

1. **Sibling repos as context.** Before the review, read-only clones of the other repositories
   are placed in `.estate/`, so Claude can read the code that consumes the changed values.
2. **A review method.** The prompt makes Claude trace data and event dependencies (not just
   imports) up to three repositories out, cite a file and line for every claim, and treat docs
   and comments as claims to verify. Claude only gets read tools (Read, Grep, Glob, LS): no
   shell, no web.

## What's here

| File | What it is |
| --- | --- |
| `workflows/claude-review-v2-8-step.yml` | Latest reviewer, 8-step method. Adds a check of the diff on its own (races, leaks, dropped errors), a "try to break it" step, and reporting defects even with no current consumer. **Start here.** |
| `workflows/claude-review-v1-6-step.yml` | First version, 6-step method focused on cross-repository consumers. |
| `skills/estate-review/SKILL.md` | The v2 method packaged as a Claude Code skill, for running it locally. |
| `workflows/claude-review-skill.yml` | A workflow that installs that skill and runs it on every PR. |

## Set it up on GitHub

1. In each repository of the estate, copy one workflow to `.github/workflows/claude-review.yml`.
2. Add the secret `CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token`).
3. Add the variable `ESTATE_REPOS`: every repository in the estate, space-separated, e.g.
   `acme/billing acme/ledger acme/notifications`. Each repo skips itself.
4. Only if those repositories are private: add the secret `ESTATE_TOKEN`, a token that can read them.

The job fails instead of reviewing blind if `ESTATE_REPOS` is empty or a sibling cannot be cloned.

## Use it locally

```bash
mkdir -p ~/.claude/skills && cp -R skills/estate-review ~/.claude/skills/
# in the repo under review, put read-only clones of the siblings in .estate/
claude "/estate-review review the changes on this branch against main"
```
