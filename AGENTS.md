# AGENTS.md

Conventions for coding agents working in this repository.

Keep this file focused on durable project principles. Do not create or update
project documentation merely to record the current task, implementation process,
validation run, or agent reasoning.

## Working conventions

- Follow the user's current task and constraints. Do not automatically start subsequent tasks.
- Inspect the working tree and preserve user / other agent changes, including staged and untracked files. Coordinate shared files when parallel work is authorized.
- Prefer small, reviewable changes and the simplest design that meets the task. Avoid speculative abstractions, premature optimization, and unrelated refactoring.
- Use Chinese for project explanations and task documentation when documentation is actually required, unless requested otherwise; preserve established code naming and the English commit convention below.
- Do not broaden the scope to cleanup, documentation, refactoring, or follow-up work unless it is required for correctness or explicitly requested.

## Documentation policy

Documentation changes are opt-in, not a default part of implementation work.

- Do not create a new document unless the user explicitly requests one or there is no appropriate existing document for a durable project-level fact.
- Do not update documentation just because code was changed.
- Update an existing document only when the change makes that document materially incorrect or incomplete about stable behavior.
- Documentation should describe the current durable state of the project, not the history of how that state was reached.
- Before editing docs, ask: "Would the existing documentation be false or materially misleading after this change?" If not, do not edit it.
- Prefer code, tests, commit messages, and pull-request descriptions for implementation details and development evidence.

Never add the following to tracked project documentation unless the user explicitly asks for it:

- task IDs or phase names such as `BATCH-004`, `TASK-123`, or implementation milestones;
- task plans, TODO checklists, acceptance checklists, progress reports, or completion reports;
- dated validation records or "tested on YYYY-MM-DD" sections;
- local machine diagnostics, temporary environment workarounds, cache issues, or tool installation notes that are not durable setup requirements;
- `.tooling` paths, local log filenames, command transcripts, test-run counts, elapsed times, or one-off build results;
- agent reasoning, review notes, investigation history, or explanations of why the agent chose an implementation;
- temporary compatibility notes that cease to matter once the implementation is complete;
- duplicated implementation details already clear from code or tests.

When documentation must change:

- describe behavior, contracts, architecture, user workflow, supported platforms, or durable setup requirements;
- keep it concise and platform-neutral where behavior is shared;
- avoid duplicating the same contract across multiple documents;
- separate user-facing limits from lower-level implementation limits;
- use terminology consistently with the code;
- remove obsolete statements instead of appending historical corrections;
- do not add a changelog-style history section to architecture documents.

Commit messages and pull-request descriptions are the preferred place for:
implementation summaries, validation evidence, test counts, migration notes,
temporary limitations, and task-specific context.

If unsure whether a documentation change is necessary, do not make it.

## Architecture principles

- Keep domain logic pure Dart and independent of UI frameworks, networking, storage, and concrete data sources. Domain models remain immutable.
- Presentation consumes domain contracts. Keep site-specific protocols, parsing, credentials, and transport/storage details behind the data layer boundaries.
- Use explicit dependency injection and clear resource ownership. Avoid hidden global service dependencies; handle asynchronous cancellation and lifecycle cleanup deliberately.
- Preserve existing model and contract semantics. Read [docs/architecture.md](docs/architecture.md) and [docs/contracts.md](docs/contracts.md) when affected. Update them only when their durable contracts would otherwise become incorrect.
- Keep development fixtures and test infrastructure separate from production behavior.
- Design user-facing UI for localization; currently support Chinese and English. Keep translatable copy in shared language resources and account for different text lengths. See [docs/architecture.md](docs/architecture.md) for the implementation convention.

## Platforms and dependencies

- Android and iOS are the application targets; Windows is a development host. Preserve shared-code compatibility and respect platform conventions.
- Follow the toolchain pins and [docs/development.md](docs/development.md). Add or upgrade dependencies only when needed for the task, checking SDK and target-platform compatibility.
- Keep machine-specific paths, downloaded toolchains, credentials, and generated build artifacts out of tracked application configuration.

## Validation and evidence

- Run checks appropriate to the change and the task's acceptance criteria. Use offline, deterministic fixtures.
- Report what was actually validated in the final response or commit / PR description. Distinguish unit tests, widget tests, builds, emulator runs, device runs, and release checks.
- Do not persist routine validation evidence into architecture or feature documentation.
- Documentation or compile success does not establish device/runtime success.
- This project is an offline EPUB/TXT reader: no online sources, network layer, or online caches exist. Do not add live-source requests or site-specific tooling back; keep tests and fixtures offline and synthetic.

## Git commits

- Commit messages must be written in English.
- Keep the repo's existing format: `<type>: <short summary>` subject line, followed by `-` bullet points grouping the change by module.
- Use the commit body for task-specific implementation summaries, validation evidence, and noteworthy temporary limitations instead of adding them to project documentation.