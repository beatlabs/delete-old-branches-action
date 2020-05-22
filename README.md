![Linting](https://github.com/beatlabs/delete-old-branches-action/workflows/Linting/badge.svg)
# Delete Old Branches Action

## Introduction
This simple GitHub Action will delete branches that haven't received a commit recently. The time since last commit is configurable

## Disclaimer
**Always** run the GitHub action in dry-run mode to ensure that it will do the right thing before you actually let it do it. Also make sure that you have a full copy of the repository (`git clone --mirror ...`) in case something goes bad

## Example usage

```
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
        uses: beatlabs/delete-old-branches-action@v0.0.1
        with:
          repo_token: ${{ github.token }}
          date: '3 months ago'
          dry_run: true
```
Once you are happy switch, `dry_run` to `false` so the action actually does the job

Happy cleaning!
