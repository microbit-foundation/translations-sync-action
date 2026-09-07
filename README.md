# translations-sync-action

A composite GitHub Action for the micro:bit web apps' weekly translation sync:
it runs the repository's download command, then opens or refreshes a pull
request with whatever changed. The pull request is pushed with the
`microbit-i18n` GitHub App, because pushes made with `GITHUB_TOKEN` never start
workflows and the pull request would get no CI.

The download itself is the repository's business, normally
`npm run i18n:download` from [`@microbit/i18n-tools`](https://github.com/microbit-foundation/ui/tree/main/packages/i18n-tools).
The action supplies the summary file path in `I18N_SUMMARY`, which that tool
honours, and reads the exit code: 0 is success, 2 a partial download (some
files failed, the rest were written, still worth a pull request; the job is
failed after the pull request is opened so the failure is seen), anything
else stops before the pull request.

## Usage

```yaml
name: translations-download
on:
  schedule:
    - cron: "10 6 * * 1"
  workflow_dispatch:
concurrency:
  group: translations-download
  cancel-in-progress: false
jobs:
  download:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v7
        with:
          node-version: 24
          cache: npm
      - run: npm ci
      - uses: microbit-foundation/translations-sync-action@v1
        with:
          download: npm run i18n:download
          app-id: ${{ secrets.I18N_APP_ID }}
          private-key: ${{ secrets.I18N_APP_PRIVATE_KEY }}
        env:
          CROWDIN_PERSONAL_TOKEN: ${{ secrets.MICROBIT_ORG_CROWDIN_PERSONAL_ACCESS_TOKEN }}
```

Everything the download needs, such as the Crowdin token, goes in `env` on
the action step. Everything before it is the repository's own install.

## Inputs

| Input           | Default                                       | Purpose                                                                                      |
| --------------- | --------------------------------------------- | -------------------------------------------------------------------------------------------- |
| `download`      | required                                      | Command that downloads the translations, run from the repository root.                       |
| `post-download` | none                                          | Command run after a download that exited 0 or 2, for repositories that derive files from it. |
| `app-id`        | required                                      | The microbit-i18n App's id.                                                                  |
| `private-key`   | required                                      | The microbit-i18n App's private key.                                                         |
| `branch`        | `translations/sync`                           | Branch the changes are force-pushed to.                                                      |
| `base`          | the default branch                            | Branch the pull request targets.                                                             |
| `title`         | `Translation sync`                            | Commit message and pull request title.                                                       |
| `body`          | a sentence saying where the changes came from | First paragraph of the pull request body; the download summary follows it.                   |
| `reviewer`      | `microbit-foundation/web`                     | Team or user to request a review from; empty for none.                                       |

The pull request body and the run's step summary both carry the download's
summary: files written, failed downloads, and translations left out for
placeholder problems with the English and translated text, so the deletions
in the diff are explained where the reviewer reads. The body is refreshed on
every run. A run with translations left out gets a warning annotation.

Everything the download and post-download commands change is committed, so
generated output that should not be committed must be gitignored.

## Requirements

- The `microbit-i18n` GitHub App installed on the repository, with its id and
  private key available as secrets. Its setup, and why it is a separate App
  from Renovate's, is in the `@microbit/i18n-tools` README.
- A checkout with the default credentials is fine: the push uses the App
  token explicitly and drops the checkout's `GITHUB_TOKEN` header first.
- `@microbit/i18n-tools` 0.1.2 or later, for `I18N_SUMMARY`.

## Releasing

Tag `vX.Y.Z` and publish a GitHub release for it. The release workflow moves
the floating major tag (`v1`) to it, which is what consumers reference. A
breaking change to the inputs is a new major.
