const {
  fs,
  path,
  TOOL_NAME,
  SHORT_TOOL_NAME,
  CLI_ENTRY_PATH,
  LOCK_FILE_RELATIVE,
  REQUIRED_MANAGED_REPO_FILES,
  AGENT_WORKTREE_RELATIVE_DIRS,
  OMX_SCAFFOLD_DIRECTORIES,
  OMX_SCAFFOLD_FILES,
} = require('../context');
const { run, runPackageAsset } = require('../core/runtime');
const { readGitConfig, ensureRepoBranch } = require('../git');
const { printAutoFinishSummary } = require('../output');

/**
 * @typedef {Object} AutoFinishSummary
 * @property {boolean} [enabled]
 * @property {number} [attempted]
 * @property {number} [completed]
 * @property {number} [skipped]
 * @property {number} [failed]
 * @property {string[]} [details]
 * @property {string} [baseBranch]
 */

/**
 * @typedef {Object} OperationResult
 * @property {string} status
 * @property {string} note
 * @property {string} [stdout]
 * @property {string} [stderr]
 * @property {string} [prUrl]
 * @property {string[]} [stagedFiles]
 * @property {string} [commitMessage]
 * @property {unknown[]} [operations]
 * @property {OperationResult} [cleanup]
 * @property {OperationResult} [hookRefresh]
 */

/**
 * @typedef {Object} SandboxMetadata
 * @property {string} branch
 * @property {string} worktreePath
 */

/**
 * @typedef {Object} SandboxStartResult
 * @property {SandboxMetadata} metadata
 * @property {string} [stdout]
 * @property {string} [stderr]
 */

/**
 * @typedef {Object} DoctorLockSyncState
 * @property {OperationResult} result
 * @property {string | null} sandboxLockContent
 */

/**
 * @typedef {Object} DoctorSandboxExecution
 * @property {OperationResult} autoCommit
 * @property {OperationResult} finish
 * @property {OperationResult} protectedBaseRepairSync
 * @property {OperationResult} lockSync
 * @property {OperationResult} omxScaffoldSync
 * @property {AutoFinishSummary} autoFinish
 * @property {string | null} sandboxLockContent
 */

function requireDoctorIntegration(name, value) {
  if (typeof value !== 'function') {
    throw new Error(`doctor integration missing: ${name}`);
  }
  return value;
}

function appendForceArgs(args, options) {
  if (!options.force) {
    return;
  }
  args.push('--force');
  if (Array.isArray(options.forceManagedPaths) && options.forceManagedPaths.length > 0) {
    args.push(...options.forceManagedPaths);
  }
}

function resolveSandboxTarget(repoRoot, worktreePath, targetPath) {
  const resolvedTarget = path.resolve(targetPath);
  const relativeTarget = path.relative(repoRoot, resolvedTarget);
  if (relativeTarget.startsWith('..') || path.isAbsolute(relativeTarget)) {
    throw new Error(`sandbox target must stay inside repo root: ${resolvedTarget}`);
  }
  if (!relativeTarget || relativeTarget === '.') {
    return worktreePath;
  }
  return path.join(worktreePath, relativeTarget);
}

function buildSandboxDoctorArgs(options, sandboxTarget) {
  const args = ['doctor', '--target', sandboxTarget];
  if (options.dryRun) args.push('--dry-run');
  appendForceArgs(args, options);
  if (options.skipAgents) args.push('--skip-agents');
  if (options.skipPackageJson) args.push('--skip-package-json');
  if (options.skipGitignore) args.push('--no-gitignore');
  if (!options.dropStaleLocks) args.push('--keep-stale-locks');
  args.push(options.waitForMerge ? '--wait-for-merge' : '--no-wait-for-merge');
  if (options.verboseAutoFinish) args.push('--verbose-auto-finish');
  if (options.json) args.push('--json');
  return args;
}

function isSpawnFailure(result) {
  return Boolean(result?.error) && typeof result?.status !== 'number';
}

function parseGitPathList(output) {
  return String(output || '')
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line && line !== LOCK_FILE_RELATIVE);
}

function collectWorktreePaths(worktreePath, commands) {
  const changed = new Set();
  for (const gitArgs of commands) {
    const result = run('git', ['-C', worktreePath, ...gitArgs], { timeout: 20_000 });
    for (const filePath of parseGitPathList(result.stdout)) {
      changed.add(filePath);
    }
  }
  return Array.from(changed);
}

function collectDoctorChangedPaths(worktreePath) {
  return collectWorktreePaths(worktreePath, [
    ['diff', '--name-only'],
    ['diff', '--cached', '--name-only'],
    ['ls-files', '--others', '--exclude-standard'],
  ]);
}

function collectDoctorDeletedPaths(worktreePath) {
  return collectWorktreePaths(worktreePath, [
    ['diff', '--name-only', '--diff-filter=D'],
    ['diff', '--cached', '--name-only', '--diff-filter=D'],
  ]);
}

function collectWorktreeDirtyPaths(worktreePath) {
  return collectWorktreePaths(worktreePath, [
    ['diff', '--name-only'],
    ['diff', '--cached', '--name-only'],
    ['ls-files', '--others', '--exclude-standard'],
  ]);
}

function collectDoctorForceAddPaths(worktreePath) {
  return REQUIRED_MANAGED_REPO_FILES
    .filter((relativePath) => relativePath.startsWith('scripts/') || relativePath.startsWith('.githooks/'))
    .filter((relativePath) => fs.existsSync(path.join(worktreePath, relativePath)));
}

function stripDoctorSandboxLocks(rawContent, branchName) {
  if (!rawContent || !branchName) {
    return rawContent;
  }
  try {
    const parsed = JSON.parse(rawContent);
    const locks = parsed && typeof parsed === 'object' && parsed.locks && typeof parsed.locks === 'object'
      ? parsed.locks
      : null;
    if (!locks) {
      return rawContent;
    }
    let changed = false;
    const filteredLocks = {};
    for (const [filePath, lockInfo] of Object.entries(locks)) {
      if (lockInfo && lockInfo.branch === branchName) {
        changed = true;
        continue;
      }
      filteredLocks[filePath] = lockInfo;
    }
    if (!changed) {
      return rawContent;
    }
    return `${JSON.stringify({ ...parsed, locks: filteredLocks }, null, 2)}\n`;
  } catch {
    return rawContent;
  }
}

function claimDoctorChangedLocks(metadata) {
  if (!metadata.branch) {
    return {
      status: 'skipped',
      note: 'missing sandbox branch metadata',
      changedCount: 0,
      deletedCount: 0,
    };
  }

  const changedPaths = Array.from(new Set([
    ...collectDoctorChangedPaths(metadata.worktreePath),
    ...collectDoctorForceAddPaths(metadata.worktreePath),
  ]));
  const deletedPaths = collectDoctorDeletedPaths(metadata.worktreePath);
  if (changedPaths.length > 0) {
    runPackageAsset('lockTool', ['claim', '--branch', metadata.branch, ...changedPaths], {
      cwd: metadata.worktreePath,
      timeout: 30_000,
    });
  }
  if (deletedPaths.length > 0) {
    runPackageAsset('lockTool', ['allow-delete', '--branch', metadata.branch, ...deletedPaths], {
      cwd: metadata.worktreePath,
      timeout: 30_000,
    });
  }

  return {
    status: 'claimed',
    note: 'claimed locks for doctor auto-commit',
    changedCount: changedPaths.length,
    deletedCount: deletedPaths.length,
  };
}

function autoCommitDoctorSandboxChanges(metadata) {
  if (!metadata.worktreePath || !metadata.branch) {
    return {
      status: 'skipped',
      note: 'missing sandbox branch metadata',
    };
  }

  claimDoctorChangedLocks(metadata);
  run(
    'git',
    ['-C', metadata.worktreePath, 'add', '-A', '--', '.', `:(exclude)${LOCK_FILE_RELATIVE}`],
    { timeout: 20_000 },
  );
  const forceAddPaths = collectDoctorForceAddPaths(metadata.worktreePath);
  if (forceAddPaths.length > 0) {
    run(
      'git',
      ['-C', metadata.worktreePath, 'add', '-f', '--', ...forceAddPaths],
      { timeout: 20_000 },
    );
  }
  const staged = run(
    'git',
    ['-C', metadata.worktreePath, 'diff', '--cached', '--name-only', '--', '.', `:(exclude)${LOCK_FILE_RELATIVE}`],
    { timeout: 20_000 },
  );
  const stagedFiles = parseGitPathList(staged.stdout);
  if (stagedFiles.length === 0) {
    return {
      status: 'no-changes',
      note: 'no committable doctor changes found in sandbox',
    };
  }

  const commitResult = run(
    'git',
    ['-C', metadata.worktreePath, 'commit', '-m', 'Auto-finish: gx doctor repairs'],
    { timeout: 30_000 },
  );
  if (commitResult.status !== 0) {
    return {
      status: 'failed',
      note: 'doctor sandbox auto-commit failed',
      stdout: commitResult.stdout || '',
      stderr: commitResult.stderr || '',
    };
  }

  return {
    status: 'committed',
    note: 'doctor sandbox repairs committed',
    commitMessage: 'Auto-finish: gx doctor repairs',
    stagedFiles,
  };
}

function hasOriginRemote(repoRoot) {
  return run('git', ['-C', repoRoot, 'remote', 'get-url', 'origin']).status === 0;
}

function originRemoteLooksLikeGithub(repoRoot) {
  const originUrl = readGitConfig(repoRoot, 'remote.origin.url');
  if (!originUrl) {
    return false;
  }
  return /github\.com[:/]/i.test(originUrl);
}

function isCommandAvailable(commandName) {
  return run('which', [commandName]).status === 0;
}

function extractAgentBranchFinishPrUrl(output) {
  const match = String(output || '').match(/\[agent-branch-finish\] PR:\s*(\S+)/);
  return match ? match[1] : '';
}

function doctorFinishFlowIsPending(output) {
  return (
    /\[agent-branch-finish\] PR merge not completed yet; leaving PR open\./.test(output) ||
    /\[agent-branch-finish\] Merge pending review\/check policy\. Branch cleanup skipped for now\./.test(output) ||
    /\[agent-branch-finish\] PR auto-merge enabled; waiting for required checks\/reviews\./.test(output)
  );
}

function finishDoctorSandboxBranch(blocked, metadata, options = {}) {
  if (!hasOriginRemote(blocked.repoRoot)) {
    return {
      status: 'skipped',
      note: 'origin remote missing; skipped auto-finish',
    };
  }
  const explicitGhBin = Boolean(String(process.env.GUARDEX_GH_BIN || '').trim());
  if (!explicitGhBin && !originRemoteLooksLikeGithub(blocked.repoRoot)) {
    return {
      status: 'skipped',
      note: 'origin remote is not GitHub; skipped auto-finish PR flow',
    };
  }

  const ghBin = process.env.GUARDEX_GH_BIN || 'gh';
  if (!isCommandAvailable(ghBin)) {
    return {
      status: 'skipped',
      note: `'${ghBin}' not available; skipped auto-finish PR flow`,
    };
  }
  const ghAuthStatus = run(ghBin, ['auth', 'status'], { timeout: 20_000 });
  if (ghAuthStatus.status !== 0) {
    return {
      status: 'skipped',
      note: `'${ghBin}' auth unavailable; skipped auto-finish PR flow`,
      stderr: ghAuthStatus.stderr || '',
    };
  }

  const rawWaitTimeoutSeconds = Number.parseInt(process.env.GUARDEX_FINISH_WAIT_TIMEOUT_SECONDS || '1800', 10);
  const waitTimeoutSeconds =
    Number.isFinite(rawWaitTimeoutSeconds) && rawWaitTimeoutSeconds >= 30 ? rawWaitTimeoutSeconds : 1800;
  const finishTimeoutMs = Math.max(180_000, (waitTimeoutSeconds + 60) * 1000);
  const waitForMergeArg = options.waitForMerge === false ? '--no-wait-for-merge' : '--wait-for-merge';

  const finishResult = runPackageAsset(
    'branchFinish',
    ['--branch', metadata.branch, '--base', blocked.branch, '--via-pr', waitForMergeArg, '--cleanup'],
    { cwd: metadata.worktreePath, timeout: finishTimeoutMs },
  );
  if (isSpawnFailure(finishResult)) {
    return {
      status: 'failed',
      note: 'doctor sandbox finish flow errored',
      stdout: finishResult.stdout || '',
      stderr: finishResult.stderr || '',
    };
  }
  if (finishResult.status !== 0) {
    return {
      status: 'failed',
      note: 'doctor sandbox finish flow failed',
      stdout: finishResult.stdout || '',
      stderr: finishResult.stderr || '',
    };
  }

  const combinedOutput = `${finishResult.stdout || ''}\n${finishResult.stderr || ''}`;
  if (doctorFinishFlowIsPending(combinedOutput)) {
    return {
      status: 'pending',
      note: 'PR created and waiting for merge policy/checks',
      prUrl: extractAgentBranchFinishPrUrl(combinedOutput),
      stdout: finishResult.stdout || '',
      stderr: finishResult.stderr || '',
    };
  }

  return {
    status: 'completed',
    note: 'doctor sandbox finish flow completed',
    stdout: finishResult.stdout || '',
    stderr: finishResult.stderr || '',
  };
}

function applyStash(repoRoot, stashRef) {
  if (!stashRef) {
    return;
  }
  run('git', ['-C', repoRoot, 'stash', 'apply', stashRef], { timeout: 30_000 });
}

function dropStash(repoRoot, stashRef) {
  if (!stashRef) {
    return;
  }
  run('git', ['-C', repoRoot, 'stash', 'drop', stashRef], { timeout: 20_000 });
}

function mergeDoctorSandboxRepairsBackToProtectedBase(options, blocked, metadata, autoCommitResult, finishResult, integrations) {
  if (options.dryRun) {
    return {
      status: autoCommitResult.status === 'committed' ? 'would-merge' : 'skipped',
      note: autoCommitResult.status === 'committed'
        ? 'dry run: would fast-forward tracked doctor repairs into the protected base workspace'
        : 'dry run skips tracked repair merge',
    };
  }

  if (autoCommitResult.status !== 'committed') {
    return {
      status: autoCommitResult.status === 'no-changes' ? 'unchanged' : 'skipped',
      note: autoCommitResult.status === 'no-changes'
        ? 'no tracked doctor repairs needed in the protected base workspace'
        : 'tracked doctor repair merge skipped',
    };
  }

  if (finishResult.status !== 'skipped') {
    return {
      status: 'skipped',
      note: finishResult.status === 'failed'
        ? 'tracked doctor repairs remain in the sandbox after finish failure'
        : 'tracked doctor repairs are being delivered through the sandbox finish flow',
    };
  }

  const allowedPaths = new Set([
    ...(autoCommitResult.stagedFiles || []),
    ...OMX_SCAFFOLD_DIRECTORIES,
    ...Array.from(OMX_SCAFFOLD_FILES.keys()),
    ...REQUIRED_MANAGED_REPO_FILES,
    'bin',
    'package.json',
    '.gitignore',
    'AGENTS.md',
  ]);
  const dirtyPaths = collectWorktreeDirtyPaths(blocked.repoRoot);
  let stashRef = '';
  let mergeSucceeded = false;

  try {
    if (dirtyPaths.length > 0) {
      const unexpectedPaths = dirtyPaths.filter((filePath) => {
        if (allowedPaths.has(filePath)) {
          return false;
        }
        return !AGENT_WORKTREE_RELATIVE_DIRS.some(
          (relativeDir) => filePath === relativeDir || filePath.startsWith(`${relativeDir}/`),
        );
      });
      if (unexpectedPaths.length > 0) {
        return {
          status: 'failed',
          note: `protected branch workspace has unrelated local changes: ${unexpectedPaths.join(', ')}`,
        };
      }

      const stashMessage = `guardex-doctor-merge-${Date.now()}`;
      const stashResult = run(
        'git',
        ['-C', blocked.repoRoot, 'stash', 'push', '--all', '--message', stashMessage],
        { timeout: 30_000 },
      );
      if (isSpawnFailure(stashResult)) {
        return {
          status: 'failed',
          note: 'could not stash protected branch doctor drift before merge',
          stdout: stashResult.stdout || '',
          stderr: stashResult.stderr || '',
        };
      }
      if (stashResult.status !== 0) {
        return {
          status: 'failed',
          note: 'stashing protected branch doctor drift failed',
          stdout: stashResult.stdout || '',
          stderr: stashResult.stderr || '',
        };
      }

      const stashLookup = run(
        'git',
        ['-C', blocked.repoRoot, 'stash', 'list'],
        { timeout: 20_000 },
      );
      stashRef = String(stashLookup.stdout || '')
        .split('\n')
        .find((line) => line.includes(stashMessage))
        ?.split(':')[0]
        ?.trim() || '';
    }

    const restoreResult = ensureRepoBranch(blocked.repoRoot, blocked.branch);
    if (!restoreResult.ok) {
      return {
        status: 'failed',
        note: `could not restore protected branch '${blocked.branch}' before applying sandbox repairs`,
        stdout: restoreResult.stdout || '',
        stderr: restoreResult.stderr || '',
      };
    }

    const mergeResult = run(
      'git',
      ['-C', blocked.repoRoot, 'merge', '--ff-only', metadata.branch],
      { timeout: 30_000 },
    );
    if (isSpawnFailure(mergeResult)) {
      return {
        status: 'failed',
        note: 'tracked doctor repair merge errored',
        stdout: mergeResult.stdout || '',
        stderr: mergeResult.stderr || '',
      };
    }
    if (mergeResult.status !== 0) {
      return {
        status: 'failed',
        note: 'tracked doctor repair merge failed',
        stdout: mergeResult.stdout || '',
        stderr: mergeResult.stderr || '',
      };
    }
    mergeSucceeded = true;

    let cleanupResult;
    try {
      cleanupResult = integrations.cleanupProtectedBaseSandbox(blocked.repoRoot, metadata);
    } catch (error) {
      return {
        status: 'failed',
        note: `tracked doctor repair merge succeeded but sandbox cleanup failed: ${error.message}`,
        stdout: mergeResult.stdout || '',
        stderr: mergeResult.stderr || '',
      };
    }

    let hookRefreshResult;
    try {
      hookRefreshResult = integrations.configureHooks(blocked.repoRoot, false);
    } catch (error) {
      return {
        status: 'failed',
        note: `tracked doctor repair merge succeeded but local hook refresh failed: ${error.message}`,
        stdout: mergeResult.stdout || '',
        stderr: mergeResult.stderr || '',
      };
    }

    return {
      status: 'merged',
      note: 'fast-forwarded tracked doctor repairs into the protected base workspace',
      stdout: mergeResult.stdout || '',
      stderr: mergeResult.stderr || '',
      cleanup: cleanupResult,
      hookRefresh: hookRefreshResult,
    };
  } finally {
    if (mergeSucceeded) {
      dropStash(blocked.repoRoot, stashRef);
    } else {
      applyStash(blocked.repoRoot, stashRef);
    }
  }
}

function createDoctorSkippedOperation(note = 'sandbox doctor did not complete successfully') {
  return {
    status: 'skipped',
    note,
  };
}

function createSkippedDoctorAutoFinishSummary(note = 'sandbox doctor did not complete successfully') {
  return {
    enabled: false,
    attempted: 0,
    completed: 0,
    skipped: 0,
    failed: 0,
    details: [`Skipped auto-finish sweep (${note}).`],
  };
}

function createDoctorSandboxExecutionState(note = 'sandbox doctor did not complete successfully') {
  return {
    autoCommit: createDoctorSkippedOperation(note),
    finish: createDoctorSkippedOperation(note),
    protectedBaseRepairSync: createDoctorSkippedOperation(note),
    lockSync: createDoctorSkippedOperation(note),
    omxScaffoldSync: createDoctorSkippedOperation(note),
    autoFinish: createSkippedDoctorAutoFinishSummary(note),
    sandboxLockContent: null,
  };
}

function summarizeDoctorOmxScaffoldSync(repoRoot, dryRun, ensureOmxScaffold) {
  const omxScaffoldOps = ensureOmxScaffold(repoRoot, dryRun);
  const changedOmxPaths = omxScaffoldOps.filter((operation) => operation.status !== 'unchanged');
  if (changedOmxPaths.length === 0) {
    return {
      status: 'unchanged',
      note: '.omx scaffold already in sync',
      operations: omxScaffoldOps,
    };
  }
  return {
    status: dryRun ? 'would-sync' : 'synced',
    note: `${dryRun ? 'would sync' : 'synced'} ${changedOmxPaths.length} .omx path(s)`,
    operations: omxScaffoldOps,
  };
}

function syncDoctorLockRegistryBeforeMerge(repoRoot, metadata) {
  const sandboxLockPath = path.join(metadata.worktreePath, LOCK_FILE_RELATIVE);
  const baseLockPath = path.join(repoRoot, LOCK_FILE_RELATIVE);
  if (!fs.existsSync(baseLockPath)) {
    return {
      result: {
        status: 'skipped',
        note: `${LOCK_FILE_RELATIVE} missing in protected base workspace`,
      },
      sandboxLockContent: null,
    };
  }
  if (!fs.existsSync(sandboxLockPath)) {
    return {
      result: {
        status: 'skipped',
        note: `${LOCK_FILE_RELATIVE} missing in sandbox worktree`,
      },
      sandboxLockContent: null,
    };
  }

  const sourceContent = stripDoctorSandboxLocks(
    fs.readFileSync(sandboxLockPath, 'utf8'),
    metadata.branch,
  );
  const destinationContent = fs.readFileSync(baseLockPath, 'utf8');
  if (sourceContent === destinationContent) {
    return {
      result: {
        status: 'unchanged',
        note: `${LOCK_FILE_RELATIVE} already in sync`,
      },
      sandboxLockContent: sourceContent,
    };
  }

  fs.mkdirSync(path.dirname(baseLockPath), { recursive: true });
  fs.writeFileSync(baseLockPath, sourceContent, 'utf8');
  return {
    result: {
      status: 'synced',
      note: `${LOCK_FILE_RELATIVE} synced from sandbox`,
    },
    sandboxLockContent: sourceContent,
  };
}

function syncDoctorLockRegistryAfterMerge(repoRoot, sandboxLockContent) {
  if (sandboxLockContent === null) {
    return {
      status: 'skipped',
      note: `${LOCK_FILE_RELATIVE} missing in sandbox worktree`,
    };
  }

  const baseLockPath = path.join(repoRoot, LOCK_FILE_RELATIVE);
  if (!fs.existsSync(baseLockPath)) {
    fs.mkdirSync(path.dirname(baseLockPath), { recursive: true });
    fs.writeFileSync(baseLockPath, sandboxLockContent, 'utf8');
    return {
      status: 'synced',
      note: `${LOCK_FILE_RELATIVE} recreated from sandbox`,
    };
  }

  const destinationContent = fs.readFileSync(baseLockPath, 'utf8');
  if (sandboxLockContent === destinationContent) {
    return {
      status: 'unchanged',
      note: `${LOCK_FILE_RELATIVE} already in sync`,
    };
  }

  fs.mkdirSync(path.dirname(baseLockPath), { recursive: true });
  fs.writeFileSync(baseLockPath, sandboxLockContent, 'utf8');
  return {
    status: 'synced',
    note: `${LOCK_FILE_RELATIVE} synced from sandbox`,
  };
}

function executeDoctorSandboxLifecycle(options, blocked, metadata, integrations) {
  const execution = createDoctorSandboxExecutionState();
  const dryRun = Boolean(options.dryRun);

  execution.omxScaffoldSync = summarizeDoctorOmxScaffoldSync(
    blocked.repoRoot,
    dryRun,
    integrations.ensureOmxScaffold,
  );

  if (!dryRun) {
    execution.autoCommit = autoCommitDoctorSandboxChanges(metadata);
    if (execution.autoCommit.status === 'committed') {
      execution.finish = finishDoctorSandboxBranch(blocked, metadata, options);
    } else if (execution.autoCommit.status === 'no-changes') {
      execution.finish = createDoctorSkippedOperation('no doctor changes to auto-finish');
    } else if (execution.autoCommit.status !== 'failed') {
      execution.finish = createDoctorSkippedOperation('auto-commit did not run');
    }
  } else {
    execution.autoCommit = createDoctorSkippedOperation('dry-run skips doctor sandbox auto-commit');
    execution.finish = createDoctorSkippedOperation('dry-run skips doctor sandbox finish flow');
  }

  const lockSyncState = syncDoctorLockRegistryBeforeMerge(blocked.repoRoot, metadata);
  execution.lockSync = lockSyncState.result;
  execution.sandboxLockContent = lockSyncState.sandboxLockContent;

  execution.protectedBaseRepairSync = mergeDoctorSandboxRepairsBackToProtectedBase(
    options,
    blocked,
    metadata,
    execution.autoCommit,
    execution.finish,
    integrations,
  );

  execution.omxScaffoldSync = summarizeDoctorOmxScaffoldSync(
    blocked.repoRoot,
    dryRun,
    integrations.ensureOmxScaffold,
  );
  execution.lockSync = syncDoctorLockRegistryAfterMerge(
    blocked.repoRoot,
    execution.sandboxLockContent,
  );
  execution.autoFinish = integrations.autoFinishReadyAgentBranches(blocked.repoRoot, {
    baseBranch: blocked.branch,
    dryRun: options.dryRun,
    waitForMerge: options.waitForMerge,
    excludeBranches: [metadata.branch],
  });

  return execution;
}

function emitDoctorSandboxJsonOutput(nestedResult, execution) {
  if (nestedResult.stdout) {
    if (nestedResult.status === 0) {
      try {
        const parsed = JSON.parse(nestedResult.stdout);
        process.stdout.write(
          JSON.stringify(
            {
              ...parsed,
              protectedBaseRepairSync: execution.protectedBaseRepairSync,
              sandboxOmxScaffoldSync: execution.omxScaffoldSync,
              sandboxLockSync: execution.lockSync,
              sandboxAutoCommit: execution.autoCommit,
              sandboxFinish: execution.finish,
              autoFinish: execution.autoFinish,
            },
            null,
            2,
          ) + '\n',
        );
      } catch {
        process.stdout.write(nestedResult.stdout);
      }
    } else {
      process.stdout.write(nestedResult.stdout);
    }
  }
  if (nestedResult.stderr) process.stderr.write(nestedResult.stderr);
}

function emitDoctorSandboxConsoleOutput(options, blocked, metadata, startResult, nestedResult, execution) {
  console.log(
    `[${TOOL_NAME}] doctor detected protected branch '${blocked.branch}'. ` +
    `Running repairs in sandbox branch '${metadata.branch || 'agent/<auto>'}'.`,
  );
  if (startResult.stdout) process.stdout.write(startResult.stdout);
  if (startResult.stderr) process.stderr.write(startResult.stderr);
  if (nestedResult.stdout) process.stdout.write(nestedResult.stdout);
  if (nestedResult.stderr) process.stderr.write(nestedResult.stderr);
  if (nestedResult.status !== 0) {
    return;
  }

  if (execution.autoCommit.status === 'committed') {
    console.log(
      `[${TOOL_NAME}] Auto-committed doctor repairs in sandbox branch '${metadata.branch}'.`,
    );
  } else if (execution.autoCommit.status === 'failed') {
    console.log(`[${TOOL_NAME}] Doctor sandbox auto-commit failed; branch left for manual follow-up.`);
    if (execution.autoCommit.stdout) process.stdout.write(execution.autoCommit.stdout);
    if (execution.autoCommit.stderr) process.stderr.write(execution.autoCommit.stderr);
  } else {
    console.log(`[${TOOL_NAME}] Doctor sandbox auto-commit skipped: ${execution.autoCommit.note}.`);
  }

  if (execution.protectedBaseRepairSync.status === 'merged') {
    console.log(`[${TOOL_NAME}] Fast-forwarded tracked doctor repairs into the protected branch workspace.`);
  } else if (execution.protectedBaseRepairSync.status === 'unchanged') {
    console.log(`[${TOOL_NAME}] Protected branch workspace already had the tracked doctor repairs.`);
  } else if (execution.protectedBaseRepairSync.status === 'would-merge') {
    console.log(`[${TOOL_NAME}] Dry run: would fast-forward tracked doctor repairs into the protected branch workspace.`);
  } else if (execution.protectedBaseRepairSync.status === 'failed') {
    console.log(`[${TOOL_NAME}] Protected branch tracked repair merge failed: ${execution.protectedBaseRepairSync.note}.`);
    if (execution.protectedBaseRepairSync.stdout) process.stdout.write(execution.protectedBaseRepairSync.stdout);
    if (execution.protectedBaseRepairSync.stderr) process.stderr.write(execution.protectedBaseRepairSync.stderr);
  } else {
    console.log(`[${TOOL_NAME}] Protected branch tracked repair merge skipped: ${execution.protectedBaseRepairSync.note}.`);
  }

  if (execution.lockSync.status === 'synced') {
    console.log(
      `[${TOOL_NAME}] Synced repaired lock registry back to protected branch workspace (${LOCK_FILE_RELATIVE}).`,
    );
  } else if (execution.lockSync.status === 'unchanged') {
    console.log(`[${TOOL_NAME}] Lock registry already synced in protected branch workspace.`);
  } else {
    console.log(`[${TOOL_NAME}] Lock registry sync skipped: ${execution.lockSync.note}.`);
  }

  if (execution.finish.status === 'completed') {
    console.log(`[${TOOL_NAME}] Auto-finish flow completed for sandbox branch '${metadata.branch}'.`);
    if (execution.finish.stdout) process.stdout.write(execution.finish.stdout);
    if (execution.finish.stderr) process.stderr.write(execution.finish.stderr);
  } else if (execution.finish.status === 'pending') {
    console.log(
      `[${TOOL_NAME}] Auto-finish pending for sandbox branch '${metadata.branch}': ${execution.finish.note}.`,
    );
    if (execution.finish.prUrl) {
      console.log(`[${TOOL_NAME}] PR: ${execution.finish.prUrl}`);
    }
    if (execution.finish.stdout) process.stdout.write(execution.finish.stdout);
    if (execution.finish.stderr) process.stderr.write(execution.finish.stderr);
  } else if (execution.finish.status === 'failed') {
    console.log(`[${TOOL_NAME}] Auto-finish flow failed for sandbox branch '${metadata.branch}'.`);
    if (execution.finish.stdout) process.stdout.write(execution.finish.stdout);
    if (execution.finish.stderr) process.stderr.write(execution.finish.stderr);
  } else {
    console.log(`[${TOOL_NAME}] Auto-finish skipped: ${execution.finish.note}.`);
  }

  printAutoFinishSummary(execution.autoFinish, {
    baseBranch: blocked.branch,
    verbose: options.verboseAutoFinish,
  });
  if (execution.omxScaffoldSync.status === 'synced') {
    console.log(`[${TOOL_NAME}] Synced .omx scaffold back to protected branch workspace.`);
  } else if (execution.omxScaffoldSync.status === 'unchanged') {
    console.log(`[${TOOL_NAME}] .omx scaffold already aligned in protected branch workspace.`);
  } else if (execution.omxScaffoldSync.status === 'would-sync') {
    console.log(`[${TOOL_NAME}] Dry run: would sync .omx scaffold back to protected branch workspace.`);
  } else {
    console.log(`[${TOOL_NAME}] .omx scaffold sync skipped: ${execution.omxScaffoldSync.note}.`);
  }
}

function setDoctorSandboxExitCode(nestedResult, execution) {
  if (typeof nestedResult.status === 'number') {
    let exitCode = nestedResult.status;
    if (exitCode === 0 && execution.autoCommit.status === 'failed') {
      exitCode = 1;
    }
    if (
      exitCode === 0 &&
      execution.autoCommit.status === 'committed' &&
      (execution.finish.status === 'failed' || execution.finish.status === 'pending')
    ) {
      exitCode = 1;
    }
    if (exitCode === 0 && execution.protectedBaseRepairSync.status === 'failed') {
      exitCode = 1;
    }
    process.exitCode = exitCode;
    return;
  }
  process.exitCode = 1;
}

function runDoctorInSandbox(options, blocked, rawIntegrations = {}) {
  const integrations = {
    startProtectedBaseSandbox: requireDoctorIntegration(
      'startProtectedBaseSandbox',
      rawIntegrations.startProtectedBaseSandbox,
    ),
    cleanupProtectedBaseSandbox: requireDoctorIntegration(
      'cleanupProtectedBaseSandbox',
      rawIntegrations.cleanupProtectedBaseSandbox,
    ),
    ensureOmxScaffold: requireDoctorIntegration('ensureOmxScaffold', rawIntegrations.ensureOmxScaffold),
    configureHooks: requireDoctorIntegration('configureHooks', rawIntegrations.configureHooks),
    autoFinishReadyAgentBranches: requireDoctorIntegration(
      'autoFinishReadyAgentBranches',
      rawIntegrations.autoFinishReadyAgentBranches,
    ),
  };

  /** @type {SandboxStartResult} */
  const startResult = integrations.startProtectedBaseSandbox(blocked, {
    taskName: `${SHORT_TOOL_NAME}-doctor`,
    sandboxSuffix: 'gx-doctor',
  });
  const metadata = startResult.metadata;

  const sandboxTarget = resolveSandboxTarget(blocked.repoRoot, metadata.worktreePath, options.target);
  const nestedResult = run(
    process.execPath,
    [CLI_ENTRY_PATH, ...buildSandboxDoctorArgs(options, sandboxTarget)],
    { cwd: metadata.worktreePath },
  );
  if (isSpawnFailure(nestedResult)) {
    throw nestedResult.error;
  }

  const execution = nestedResult.status === 0
    ? executeDoctorSandboxLifecycle(options, blocked, metadata, integrations)
    : createDoctorSandboxExecutionState();

  if (options.json) {
    emitDoctorSandboxJsonOutput(nestedResult, execution);
  } else {
    emitDoctorSandboxConsoleOutput(options, blocked, metadata, startResult, nestedResult, execution);
  }

  setDoctorSandboxExitCode(nestedResult, execution);
}

module.exports = {
  runDoctorInSandbox,
};
