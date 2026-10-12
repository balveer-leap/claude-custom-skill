# claude-custom-skill

A Claude Code skill that reviews a pull request in one repository of a multi-repository
estate. It traces every value the diff writes into the sibling repositories that consume
it, anchors every claim to a file and line, and ends with a "safe to merge" /
"not safe to merge" verdict.

```
skills/estate-review/SKILL.md          the review method (8 steps + report format)
workflows/claude-estate-review.yml     GitHub Action that installs the skill and runs it on every PR
```

## Use it locally

```bash
mkdir -p ~/.claude/skills && cp -R skills/estate-review ~/.claude/skills/
# in the repo under review, put read-only clones of the siblings in .estate/
claude "/estate-review review the changes on this branch against main"
```

## Use it on every PR

1. Fork this repository if you want to change the skill, and set `SKILL_REPO` to your fork.
2. In each estate repository, copy `workflows/claude-estate-review.yml` to `.github/workflows/`.
3. Set the secret `CLAUDE_CODE_OAUTH_TOKEN` and the variable `ESTATE_REPOS`
   (see the header of the workflow file). Add `ESTATE_TOKEN` only if repos are private.
