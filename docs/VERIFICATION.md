# Bootstrap verification — November 9, 2026

The combined implementation passed 30 isolated Python unittest cases on macOS using `/bin/bash` 3.2.57. Tests run copied checkouts and temporary home directories with fixture commands replacing Homebrew, GitHub, downloads, and runtime installation. They do not invoke the live bootstrap against the host home directory.

Verified behavior includes default core-only selection, explicit extras/repos, parameters migration, argument errors, dry-run without mutations or network/authentication calls, backup uniqueness, idempotent links, missing-source preflight, rollback on link failure/termination, prerequisite and runtime failures, phase summaries, cancellation status, existing runtime/default preservation, optional app/package preservation, repository pagination/private filtering/conflicts/clone failures, local Git overrides, Vim undo permissions, and repeated Zsh startup with optional integrations present and absent.

Additional checks passed:

- Bash and Zsh syntax checks.
- ShellCheck for all installer scripts, without warnings or suppressed code errors.
- Ruby syntax parsing for both Brewfiles.
- Git configuration parsing and `git diff --check`.
- Live `--dry-run --extras --repos` inspection, with no bootstrap execution.

Package identifiers were checked using Homebrew’s public metadata. In particular, [Azure CLI is now a cask](https://formulae.brew.sh/cask/azure-cli) and [PowerShell is now a formula](https://formulae.brew.sh/api/formula/powershell.json). The bootstrap preserves older installed package types rather than migrating/removing them. The other identifiers were checked through their formula/cask endpoints under the [Homebrew Formulae API](https://formulae.brew.sh/docs/api/).

GitHub enumeration uses [RepositoryOwner pagination](https://docs.github.com/en/graphql/reference/interfaces#repositoryowner), with owned repositories selected explicitly. Dynamic .NET completion forwards the complete command buffer and cursor position to `dotnet complete`, preserving each returned line as a separate suggestion; [Microsoft documents the completion interface](https://learn.microsoft.com/dotnet/core/tools/enable-tab-autocomplete).

A clean environment sourcing `/etc/zprofile` confirmed that macOS `path_helper` already supplies the removed standard/Apple/Cryptex paths. Existing-user Zsh configuration sourcing took a median **0.265 seconds before** and **0.234 seconds after** over seven runs each. These are local warm-start measurements, not fresh-Mac performance guarantees; no lazy-loading layer was added.

Still requiring environment acceptance: a full fresh install on disposable Apple Silicon macOS, administrator authorization for package installers, real GitHub access/private visibility, real SDK downloads, physical YubiKey/signing-key provisioning, and interactive completion behavior in a terminal. No full bootstrap was run on the working Mac; existing software was not installed, removed, or migrated during verification.
