# Delete Old Branches Action

![Linting](https://github.com/beatlabs/delete-old-branches-action/workflows/Linting/badge.svg)

## Introduction

This simple GitHub Action will delete branches and optionally tags that haven't received a commit recently. The time since last commit is configurable.

The default behaviour is to exclude the default branch (main or master) and the Github protected branches. Default branch(es) can be overriden using the `default_branches` variable (e.g. `default_branches: develop` or for multiple default branches `default_branches: main,develop,my-default-branch`).

Additional branches can be excluded using the `extra_protected_branch_regex` variable (see example below).
Similarly, certain tags can be excluded using the `extra_protected_tag_regex` variable.
Also, branches with open pull requests are being ignored by default (see example below).  

## Disclaimer

**Always** run the GitHub action in dry-run mode to ensure that it will do the right thing before you actually let it do it. Also make sure that you have a full copy of the repository (`git clone --mirror ...`) in case something goes bad

## Example usage

```yaml
name: Cleanup old branches
on:
  push:
    branches:
      - master
      - develop
jobs:
  housekeeping:
    name: Cleanup old branches
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v2
      - name: Run delete-old-branches-action
        uses: beatlabs/delete-old-branches-action@v0.0.10
        with:
          repo_token: ${{ github.token }}
          date: '3 months ago'
          dry_run: true
          delete_tags: true
          minimum_tags: 5
          extra_protected_branch_regex: ^(foo|bar)$
          extra_protected_tag_regex: '^v.*'
          exclude_open_pr_branches: true
```

Once you are happy switch, `dry_run` to `false` so the action actually does the job

Happy cleaning!
