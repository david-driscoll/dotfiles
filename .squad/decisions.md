# Decisions

> Canonical decision ledger. Append-only. Managed by Scribe.

<!-- decisions start -->
## Approved six-file integration — 2026-08-11T11:58:28.284-04:00

- **Decided by:** David Driscoll
- **Decision:** Approve the reviewed six-file integration.
- **Recorded outcome:** Bobbie committed exactly the approved scope as cd7d17264a3b1e21893877a0891c4d7e748ece27, including the required co-author trailer; the scoped worktree status was clean.
## Workstation experiment source baselines — 2026-08-11T12:09:43.493-04:00

- **Decided by:** David Driscoll
- **Decision:** Use the current commit SHA on `master`/`main` for both ReliasRunAll and Configurator.
- **Why:** User direction for the experiment baseline.
## Workstation experiment parity sign-off — 2026-08-11T12:09:43.493-04:00

- **Decided by:** David Driscoll
- **Decision:** David Driscoll is the designated parity-matrix sign-off owner.
- **Why:** User direction.
## Workstation experiment representative consumer — 2026-08-11T12:09:43.493-04:00

- **Decided by:** David Driscoll
- **Decision:** Use RLMS Website as the representative Core consumer for parity testing.
- **Why:** User direction.
## Workstation experiment lifecycle state — 2026-08-11T12:09:43.493-04:00

- **Decided by:** David Driscoll
- **Decision:** Use Aspire-managed persistent lifecycle state. Retain data until explicitly deleted and automatically restore service state after a Docker container or database is lost.
- **Why:** User direction.
## Workstation experiment parity data source — 2026-08-11T12:09:43.493-04:00

- **Decided by:** David Driscoll
- **Decision:** Use Configurator-supported database backups as the parity data source, subject to required sanitization and retention metadata.
- **Why:** User direction.
## Workstation experiment database scope — 2026-08-11T12:09:43.493-04:00

- **Decided by:** David Driscoll
- **Decision:** Include LMSAudit and LMSRepl in the initial parity scope.
- **Why:** User direction.
## Workstation experiment optional Azure services — 2026-08-11T12:09:43.493-04:00

- **Decided by:** David Driscoll
- **Decision:** Use local emulators for optional Azure-backed services where available.
- **Why:** User direction.
## Workstation experiment Current and Target scope — 2026-08-11T12:09:43.493-04:00

- **Decided by:** David Driscoll
- **Decision:** Include the Current and Target service tracks in the initial workstation scope.
- **Why:** User direction.
## Workstation experiment ReliasRunAll source — 2026-08-11T12:09:43.493-04:00

- **Provided by:** David Driscoll
- **Location:** `C:\Users\ddriscoll\Development\reliasrunall`
- **Baseline:** Current commit SHA on the repository's `master`/`main` branch.
## Workstation experiment Configurator source — 2026-08-11T12:09:43.493-04:00

- **Provided by:** David Driscoll
- **Location:** `C:\Users\ddriscoll\Development\configurator`
- **Baseline:** Current commit SHA on the repository's `master`/`main` branch.
## Workstation experiment representative consumer source — 2026-08-11T12:09:43.493-04:00

- **Provided by:** David Driscoll
- **Location:** `C:\Users\ddriscoll\Development\rlms-website`
- **Purpose:** Representative RLMS Website consumer for parity testing.
## Workstation experiment backup discovery — 2026-08-11T12:09:43.493-04:00

- **Provided by:** David Driscoll
- **Decision:** Use the Configurator source code as the authoritative location for supported backup discovery and metadata handling.
## Workstation experiment LMSAudit and LMSRepl deferral — 2026-08-11T12:09:43.493-04:00

- **Decided by:** David Driscoll
- **Decision:** Defer LMSAudit and LMSRepl from the initial scope until approved backup manifests and ownership contracts are available.
- **Why:** Required sanitization, checksum, retention, and ownership evidence is not currently available.
## Workstation experiment missing-backup policy — 2026-08-11T12:09:43.493-04:00

- **Decided by:** David Driscoll
- **Decision:** When Configurator has no backup for a service, use that service's built-in bootstrap when available; otherwise initialize it blank.
- **Why:** No approved backup manifest exists for the remaining initial databases.
## Workstation experiment RLMS Website baseline — 2026-08-11T12:22:37.672-04:00

- **Decided by:** David Driscoll
- **Decision:** Do not pin the RLMS Website representative-consumer baseline yet.
- **Why:** User direction.
## Workstation experiment unverified backup policy — 2026-08-11T12:22:37.672-04:00

- **Decided by:** David Driscoll
- **Decision:** Restore Configurator-discovered backups even when an approved manifest, sanitization attestation, and SHA-256 checksum are unavailable.
- **Why:** User direction.
## Workstation experiment source-discovery and dependency policy — 2026-08-11T12:32:41.938-04:00

- **Decided by:** David Driscoll
- **Decision:** Use Configurator's "Clone common legacy repositories" capability to discover the remaining legacy source repositories.
- **Decision:** Derive connection-string keys, consumer contracts, LaunchDarkly policy, and service ownership from each service's source, then verify the findings.
- **Decision:** Treat all non-RLMS databases as self-owned by their respective libraries unless source verification proves otherwise.
- **Decision:** Follow the current `main`/`master` branch for RLMS Website research; do not pin a revision yet.

## Workstation experiment platform and optional-service policy — 2026-08-11T12:32:41.938-04:00

- **Decided by:** David Driscoll
- **Decision:** Use the latest compatible SqlPackage release.
- **Decision:** Use Aspire persistent lifetime for most lifecycle-state and recovery scenarios.
- **Decision:** Use a LaunchDarkly emulator or equivalent when available; use a Service Bus emulator; defer AI Search, Reporting, and Identity Outbox.
- **Decision:** Start RLMS Legacy through Aspire and support setting a tenant to Legacy or Current before executing the corresponding migration.
- **Decision:** Use the Target setup guide at `https://engineering.reliaslearning.com/developer-documentation/docs/onboarding/target-setup.html` as the source for future Current/Target tenant-migration artifacts and seed rules.

## Workstation experiment unresolved inputs — 2026-08-11T12:32:41.938-04:00

- **Open:** Exact approved SQL Server 2022 container tag/digest remains to be verified; user expressed a tentative preference only.
- **Open:** Exact approved Configurator-supported backup manifests, identifiers, checksums, and retention rules remain incomplete.
- **Open:** LMSAudit/LMSRepl backup manifests and ownership contracts remain TBD and deferred.
## Workstation experiment SQL Server image — 2026-08-11T12:32:41.938-04:00

- **Decided by:** David Driscoll
- **Decision:** Use the Docker image `mcr.microsoft.com/mssql/server:2022-latest` for the initial workstation SQL Server environment.
- **Open:** Capture and record the immutable image digest after the selected tag is pulled.
## User directive — 2026-08-11T14:17:15.163-04:00

- **By:** David Driscoll (via Copilot)
- **Decision:** Use GPT-5.6 Luna (`gpt-5.6-luna`) as the default model for subagents.
- **Why:** User request — captured for team memory.
<!-- decisions end -->
## User directives — 2026-08-11T15:52:27.403-04:00

- **By:** David Driscoll (via Copilot)
- **Decisions:** Assume Docker is available for the pinned SQL image; determine SqlPackage requirements per service because most services use EF Core and do not need SqlPackage for migrations; defer service-ownership artifacts for now.
- **Why:** User direction.

