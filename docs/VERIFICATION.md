# Bootstrap verification — November 9, 2026

After adding explicit Azure initialization/helpers and global ignore coverage, the implementation passed 36 isolated Python unittest cases on macOS using `/bin/bash` 3.2.57. Tests run copied checkouts and temporary home directories with fixture commands replacing Homebrew, runtime downloads, and runtime installation (unexpected Git/GitHub commands fail). They do not invoke the live bootstrap against the host home directory.

Verified behavior includes default core-only selection, explicit extras, rejection of removed repository/configuration flags, argument errors, dry-run without mutations or network/authentication calls, backup uniqueness, idempotent links, missing-source preflight, rollback on link failure/termination, prerequisite and runtime failures, phase summaries, cancellation status, existing runtime/default preservation, optional app/package preservation, local Git overrides, Vim undo permissions, and repeated Zsh startup with optional integrations present and absent.

The initial bootstrap had 30 cases; nine downloader/configuration tests were retired and 15 Azure/helper/global-ignore cases were added. Removed options still fail before setup changes anything. Azure tests use a fake CLI and synthetic local state; they check cloud mappings, selection, private new-file permissions, preserving existing profile state, mismatch handling, failed-initialization cleanup, no authentication, and fail-closed context checks. Helper installation and restoration are tested for nested backup paths. Xcode user-state patterns are intentionally absent from global ignores; tests verify they remain visible for project-specific ignore rules. Global-ignore tests also cover local Claude settings/instructions, Claude/Codex credential caches, and local environment files at root/nested paths; shared tool configuration, instruction files, skills, environment examples, and certificate/key fixtures remain visible.

Additional checks passed:

- Bash and Zsh syntax checks.
- ShellCheck for all installer scripts, without warnings or suppressed code errors.
- Ruby syntax parsing for both Brewfiles.
- Git configuration parsing and `git diff --check`.
- Live `--dry-run --extras` inspection.
- Authorized live `--links-only` setup: backed up and linked the global ignore file and existing guard, installed the initializer link, and verified original backup contents by SHA-256.
- Git in a temporary repository picked up the installed global ignore file and matched the expected personal-artifact rules.
- Installed Azure helpers passed dry-run/help checks; no live Azure initialization or login was run.

Package identifiers were checked using Homebrew’s public metadata. In particular, [Azure CLI is now a cask](https://formulae.brew.sh/cask/azure-cli) and [PowerShell is now a formula](https://formulae.brew.sh/api/formula/powershell.json). The bootstrap preserves older installed package types rather than migrating/removing them. The other identifiers were checked through their formula/cask endpoints under the [Homebrew Formulae API](https://formulae.brew.sh/docs/api/).

Dynamic .NET completion forwards the complete command buffer and cursor position to `dotnet complete`, preserving each returned line as a separate suggestion; [Microsoft documents the completion interface](https://learn.microsoft.com/dotnet/core/tools/enable-tab-autocomplete).

A clean environment sourcing `/etc/zprofile` confirmed that macOS `path_helper` already supplies the removed standard/Apple/Cryptex paths. Existing-user Zsh configuration sourcing took a median **0.265 seconds before** and **0.234 seconds after** over seven runs each. These are local warm-start measurements, not fresh-Mac performance guarantees; no lazy-loading layer was added.

Still requiring environment acceptance: real Azure cloud initialization/sign-in and credential authorization, a full fresh install on disposable Apple Silicon macOS, administrator authorization for package installers, real SDK downloads, physical YubiKey/signing-key provisioning, and interactive completion behavior in a terminal. No full bootstrap was run on the working Mac; existing software was not installed, removed, or migrated during verification.
