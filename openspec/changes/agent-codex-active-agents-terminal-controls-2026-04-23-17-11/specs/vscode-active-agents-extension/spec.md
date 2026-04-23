## ADDED Requirements

### Requirement: Active Agents exposes terminal-first inline session controls
The VS Code Active Agents companion SHALL prioritize jumping into the live session terminal over opening a per-file diff from the session row.

#### Scenario: Session row offers terminal access instead of diff access
- **WHEN** the extension contributes inline actions for a `gitguardex.session` row
- **THEN** it contributes a `Show Terminal` action for that row
- **AND** it does NOT contribute the old `Open Diff` inline action for that row.

### Requirement: Show Terminal focuses the live session terminal when possible
The VS Code Active Agents companion SHALL reveal the live integrated terminal that owns the selected session whenever the session metadata can be matched to a VS Code terminal process.

#### Scenario: Session `pid` matches an open terminal
- **GIVEN** a session record has a positive integer `pid`
- **AND** VS Code already has an integrated terminal whose `processId` resolves to that same pid
- **WHEN** the operator triggers `Show Terminal`
- **THEN** the extension reveals that existing terminal with focus
- **AND** it does NOT open a replacement terminal for the session.

#### Scenario: No live terminal match exists yet
- **WHEN** the operator triggers `Show Terminal` for a session without a matching live terminal
- **THEN** the extension opens a new integrated terminal rooted at the session worktree
- **AND** it focuses that terminal so the operator lands in the task sandbox immediately.

### Requirement: Stop signals the terminal before falling back to the CLI stopper
The VS Code Active Agents companion SHALL stop live sessions through the matched terminal first so the operator sees and controls the running task directly.

#### Scenario: Stop uses terminal interrupt when a live terminal is known
- **GIVEN** the selected session matches an open integrated terminal by `pid`
- **WHEN** the operator confirms `Stop`
- **THEN** the extension reveals that terminal
- **AND** it sends `Ctrl+C` to that terminal instead of spawning a separate `gx agents stop --pid` process.

#### Scenario: Stop falls back when no terminal can be matched
- **WHEN** the operator confirms `Stop` for a session without a matching live terminal
- **THEN** the extension falls back to `gx agents stop --pid <pid>`
- **AND** it preserves the existing repo-targeted stop behavior for that fallback path.
