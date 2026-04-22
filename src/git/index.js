const fs = require('node:fs');
const {
  path,
  TOOL_NAME,
  GIT_PROTECTED_BRANCHES_KEY,
  GIT_BASE_BRANCH_KEY,
  GIT_SYNC_STRATEGY_KEY,
  DEFAULT_PROTECTED_BRANCHES,
  DEFAULT_BASE_BRANCH,
  DEFAULT_SYNC_STRATEGY,
  COMPOSE_HINT_FILES,
  LOCK_FILE_RELATIVE,
} = require('../context');
const { run } = require('../core/runtime');

function gitRun(repoRoot, args, { allowFailure = false } = {}) {
  const result = run('git', ['-C', repoRoot, ...args]);
  if (!allowFailure && result.status !== 0) {
    throw new Error(`git ${args.join(' ')} failed: ${(result.stderr || '').trim()}`);
  }
  return result;
}

function resolveRepoRoot(targetPath) {
  const resolvedTarget = path.resolve(targetPath || process.cwd());
  const result = run('git', ['-C', resolvedTarget, 'rev-parse', '--show-toplevel']);
  if (result.status !== 0) {
    const stderr = (result.stderr || '').trim();
    throw new Error(
      `Target is not inside a git repository: ${resolvedTarget}${stderr ? `\n${stderr}` : ''}`,
    );
  }
  return result.stdout.trim();
}

function isGitRepo(targetPath) {
  const resolvedTarget = path.resolve(targetPath || process.cwd());
  const result = run('git', ['-C', resolvedTarget, 'rev-parse', '--show-toplevel']);
  return result.status === 0;
}

const NESTED_REPO_DEFAULT_MAX_DEPTH = 6;
const NESTED_REPO_DEFAULT_SKIP_DIRS = new Set([
  'node_modules',
  '.git',
  'dist',
  'build',
  '.next',
  '.cache',
  'target',
  'vendor',
  '.venv',
  '.pnpm-store',
]);

function resolveGitCommonDir(repoPath) {
  const result = run('git', ['-C', repoPath, 'rev-parse', '--git-common-dir'], { cwd: repoPath });
  if (result.status !== 0) return null;
  const raw = result.stdout.trim();
  if (!raw) return null;
  return path.resolve(repoPath, raw);
}

function discoverNestedGitRepos(rootPath, opts = {}) {
  const maxDepth = Number.isFinite(opts.maxDepth)
    ? Math.max(1, opts.maxDepth)
    : NESTED_REPO_DEFAULT_MAX_DEPTH;
  const extraSkip = new Set(Array.isArray(opts.extraSkip) ? opts.extraSkip : []);
  const includeSubmodules = Boolean(opts.includeSubmodules);
  const skipRelativeDirs = Array.isArray(opts.skipRelativeDirs) ? opts.skipRelativeDirs.filter(Boolean) : [];
  const resolvedRoot = path.resolve(rootPath);

  if (!isGitRepo(resolvedRoot)) {
    throw new Error(`Target is not inside a git repository: ${resolvedRoot}`);
  }

  const rootCommonDir = resolveGitCommonDir(resolvedRoot);
  const skipAbsolutes = skipRelativeDirs.map((relativeDir) => path.join(resolvedRoot, relativeDir));
  const found = new Set([resolvedRoot]);

  function shouldSkipDir(dirName) {
    return NESTED_REPO_DEFAULT_SKIP_DIRS.has(dirName) || extraSkip.has(dirName);
  }

  function walk(currentPath, depth) {
    if (depth > maxDepth) return;
    let entries;
    try {
      entries = fs.readdirSync(currentPath, { withFileTypes: true });
    } catch {
      return;
    }

    for (const entry of entries) {
      const entryPath = path.join(currentPath, entry.name);

      if (entry.name === '.git') {
        if (entry.isDirectory()) {
          if (entryPath === path.join(resolvedRoot, '.git')) continue;
          found.add(path.dirname(entryPath));
        } else if (includeSubmodules && entry.isFile()) {
          found.add(path.dirname(entryPath));
        }
        continue;
      }

      if (!entry.isDirectory() || entry.isSymbolicLink()) continue;
      if (shouldSkipDir(entry.name)) continue;
      if (skipAbsolutes.includes(entryPath)) continue;
      walk(entryPath, depth + 1);
    }
  }

  walk(resolvedRoot, 0);

  const filtered = Array.from(found).filter((repoPath) => {
    if (repoPath === resolvedRoot || !rootCommonDir) return true;
    const childCommonDir = resolveGitCommonDir(repoPath);
    return !childCommonDir || childCommonDir !== rootCommonDir;
  });

  const [root, ...rest] = filtered;
  rest.sort((a, b) => a.localeCompare(b));
  return root ? [root, ...rest] : [];
}

function parseBranchList(rawValue) {
  return String(rawValue || '')
    .split(/[\s,]+/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function uniquePreserveOrder(items) {
  const seen = new Set();
  const result = [];
  for (const item of items) {
    if (seen.has(item)) continue;
    seen.add(item);
    result.push(item);
  }
  return result;
}

function readConfiguredProtectedBranches(repoRoot) {
  const result = gitRun(repoRoot, ['config', '--get', GIT_PROTECTED_BRANCHES_KEY], { allowFailure: true });
  if (result.status !== 0) {
    return null;
  }
  const parsed = uniquePreserveOrder(parseBranchList(result.stdout.trim()));
  if (parsed.length === 0) {
    return null;
  }
  return parsed;
}

function listLocalUserBranches(repoRoot) {
  const result = gitRun(repoRoot, ['for-each-ref', '--format=%(refname:short)', 'refs/heads'], { allowFailure: true });
  const branchNames = result.status === 0
    ? uniquePreserveOrder(
      String(result.stdout || '')
        .split('\n')
        .map((item) => item.trim())
        .filter(Boolean),
    )
    : [];

  const additionalUserBranches = branchNames.filter(
    (branchName) =>
      !branchName.startsWith('agent/') &&
      !DEFAULT_PROTECTED_BRANCHES.includes(branchName),
  );
  if (additionalUserBranches.length > 0) {
    return additionalUserBranches;
  }

  const current = gitRun(repoRoot, ['branch', '--show-current'], { allowFailure: true });
  if (current.status !== 0) {
    return [];
  }

  const branchName = String(current.stdout || '').trim();
  if (
    !branchName ||
    branchName.startsWith('agent/') ||
    DEFAULT_PROTECTED_BRANCHES.includes(branchName)
  ) {
    return [];
  }

  return [branchName];
}

function listLocalAgentBranches(repoRoot) {
  const result = gitRun(
    repoRoot,
    ['for-each-ref', '--format=%(refname:short)', 'refs/heads/agent/'],
    { allowFailure: true },
  );
  if (result.status !== 0) {
    return [];
  }
  return uniquePreserveOrder(
    String(result.stdout || '')
      .split('\n')
      .map((item) => item.trim())
      .filter(Boolean),
  );
}

function mapWorktreePathsByBranch(repoRoot) {
  const result = gitRun(repoRoot, ['worktree', 'list', '--porcelain'], { allowFailure: true });
  const map = new Map();
  if (result.status !== 0) {
    return map;
  }

  const lines = String(result.stdout || '').split('\n');
  let currentWorktree = '';
  for (const line of lines) {
    if (line.startsWith('worktree ')) {
      currentWorktree = line.slice('worktree '.length).trim();
      continue;
    }
    if (line.startsWith('branch refs/heads/')) {
      const branchName = line.slice('branch refs/heads/'.length).trim();
      if (currentWorktree && branchName) {
        map.set(branchName, currentWorktree);
      }
    }
  }
  return map;
}

function gitRefExists(repoRoot, ref) {
  return run('git', ['-C', repoRoot, 'show-ref', '--verify', '--quiet', ref]).status === 0;
}

function hasSignificantWorkingTreeChanges(worktreePath) {
  const result = run('git', [
    '-C',
    worktreePath,
    'status',
    '--porcelain',
    '--untracked-files=normal',
    '--',
  ]);
  if (result.status !== 0) {
    return true;
  }

  const lines = String(result.stdout || '')
    .split('\n')
    .map((line) => line.trimEnd())
    .filter((line) => line.length > 0);

  for (const line of lines) {
    const pathPart = (line.length > 3 ? line.slice(3) : '').trim();
    if (!pathPart) continue;
    if (pathPart === LOCK_FILE_RELATIVE) continue;
    if (pathPart.startsWith(`${LOCK_FILE_RELATIVE} -> `)) continue;
    if (pathPart.endsWith(` -> ${LOCK_FILE_RELATIVE}`)) continue;
    return true;
  }
  return false;
}

function readProtectedBranches(repoRoot) {
  const result = gitRun(repoRoot, ['config', '--get', GIT_PROTECTED_BRANCHES_KEY], { allowFailure: true });
  if (result.status !== 0) {
    return [...DEFAULT_PROTECTED_BRANCHES];
  }

  const parsed = uniquePreserveOrder(parseBranchList(result.stdout.trim()));
  if (parsed.length === 0) {
    return [...DEFAULT_PROTECTED_BRANCHES];
  }
  return parsed;
}

function ensureSetupProtectedBranches(repoRoot, dryRun) {
  const localUserBranches = listLocalUserBranches(repoRoot);
  if (localUserBranches.length === 0) {
    return {
      status: 'unchanged',
      file: `git config ${GIT_PROTECTED_BRANCHES_KEY}`,
      note: 'no additional local user branches detected',
    };
  }

  const configured = readConfiguredProtectedBranches(repoRoot);
  const currentBranches = configured || [...DEFAULT_PROTECTED_BRANCHES];
  const missingBranches = localUserBranches.filter((branchName) => !currentBranches.includes(branchName));
  if (missingBranches.length === 0) {
    return {
      status: 'unchanged',
      file: `git config ${GIT_PROTECTED_BRANCHES_KEY}`,
      note: 'local user branches already protected',
    };
  }

  const nextBranches = uniquePreserveOrder([...currentBranches, ...missingBranches]);
  if (!dryRun) {
    writeProtectedBranches(repoRoot, nextBranches);
  }

  return {
    status: dryRun ? 'would-update' : 'updated',
    file: `git config ${GIT_PROTECTED_BRANCHES_KEY}`,
    note: `added local user branch(es): ${missingBranches.join(', ')}`,
  };
}

function writeProtectedBranches(repoRoot, branches) {
  if (branches.length === 0) {
    gitRun(repoRoot, ['config', '--unset-all', GIT_PROTECTED_BRANCHES_KEY], { allowFailure: true });
    return;
  }
  gitRun(repoRoot, ['config', GIT_PROTECTED_BRANCHES_KEY, branches.join(' ')]);
}

function readGitConfig(repoRoot, key) {
  const result = gitRun(repoRoot, ['config', '--get', key], { allowFailure: true });
  if (result.status !== 0) {
    return '';
  }
  return (result.stdout || '').trim();
}

function resolveBaseBranch(repoRoot, explicitBase) {
  if (explicitBase) {
    return explicitBase;
  }
  const configured = readGitConfig(repoRoot, GIT_BASE_BRANCH_KEY);
  return configured || DEFAULT_BASE_BRANCH;
}

function resolveSyncStrategy(repoRoot, explicitStrategy) {
  const strategy = (explicitStrategy || readGitConfig(repoRoot, GIT_SYNC_STRATEGY_KEY) || DEFAULT_SYNC_STRATEGY)
    .trim()
    .toLowerCase();
  if (strategy !== 'rebase' && strategy !== 'merge') {
    throw new Error(`Invalid sync strategy '${strategy}' (expected: rebase or merge)`);
  }
  return strategy;
}

function currentBranchName(repoRoot) {
  const result = gitRun(repoRoot, ['branch', '--show-current'], { allowFailure: true });
  if (result.status !== 0) {
    throw new Error('Unable to detect current branch');
  }
  const branch = (result.stdout || '').trim();
  if (!branch) {
    throw new Error('Detached HEAD is not supported for sync operations');
  }
  return branch;
}

function repoHasHeadCommit(repoRoot) {
  return gitRun(repoRoot, ['rev-parse', '--verify', 'HEAD'], { allowFailure: true }).status === 0;
}

function readBranchDisplayName(repoRoot) {
  const symbolic = gitRun(repoRoot, ['symbolic-ref', '--quiet', '--short', 'HEAD'], { allowFailure: true });
  if (symbolic.status === 0) {
    const branch = String(symbolic.stdout || '').trim();
    if (!branch) {
      return '(unknown)';
    }
    return repoHasHeadCommit(repoRoot) ? branch : `${branch} (unborn; no commits yet)`;
  }

  const detached = gitRun(repoRoot, ['rev-parse', '--short', 'HEAD'], { allowFailure: true });
  if (detached.status === 0) {
    return `(detached at ${String(detached.stdout || '').trim()})`;
  }
  return '(unknown)';
}

function hasOriginRemote(repoRoot) {
  return gitRun(repoRoot, ['remote', 'get-url', 'origin'], { allowFailure: true }).status === 0;
}

function detectComposeHintFiles(repoRoot) {
  return COMPOSE_HINT_FILES.filter((relativePath) => fs.existsSync(path.join(repoRoot, relativePath)));
}

function printSetupRepoHints(repoRoot, baseBranch, repoLabel = '') {
  const branchDisplay = readBranchDisplayName(repoRoot);
  const hasHeadCommit = repoHasHeadCommit(repoRoot);
  const hasOrigin = hasOriginRemote(repoRoot);
  const composeFiles = detectComposeHintFiles(repoRoot);
  if (hasHeadCommit && hasOrigin && composeFiles.length === 0) {
    return;
  }

  const label = repoLabel ? ` ${repoLabel}` : '';
  if (!hasHeadCommit) {
    console.log(`[${TOOL_NAME}] Fresh repo onboarding${label}: current branch is ${branchDisplay}.`);
    console.log(`[${TOOL_NAME}] Bootstrap commit${label}: git add . && git commit -m "bootstrap gitguardex"`);
    console.log(
      `[${TOOL_NAME}] First agent flow${label}: ` +
      `gx branch start "<task>" "codex" -> ` +
      `gx locks claim --branch "$(git branch --show-current)" <file...> -> ` +
      `gx branch finish --branch "$(git branch --show-current)" --base ${baseBranch} --via-pr --wait-for-merge`,
    );
  }
  if (!hasOrigin) {
    console.log(`[${TOOL_NAME}] No origin remote${label}: finish and auto-merge flows stay local until you add one.`);
  }
  if (composeFiles.length > 0) {
    console.log(
      `[${TOOL_NAME}] Docker Compose helper${label}: detected ${composeFiles.join(', ')}. ` +
      `Set GUARDEX_DOCKER_SERVICE and run 'bash scripts/guardex-docker-loader.sh -- <command...>'.`,
    );
  }
}

function workingTreeIsDirty(repoRoot) {
  const result = gitRun(repoRoot, ['status', '--porcelain'], { allowFailure: true });
  if (result.status !== 0) {
    throw new Error('Unable to inspect git working tree status');
  }
  const lines = (result.stdout || '').split('\n').filter((line) => line.length > 0);
  const significant = lines.filter((line) => {
    const pathPart = (line.length > 3 ? line.slice(3) : '').trim();
    if (!pathPart) return false;
    if (pathPart === LOCK_FILE_RELATIVE) return false;
    if (pathPart.startsWith(`${LOCK_FILE_RELATIVE} -> `)) return false;
    if (pathPart.endsWith(` -> ${LOCK_FILE_RELATIVE}`)) return false;
    return true;
  });
  return significant.length > 0;
}

function ensureRepoBranch(repoRoot, branch) {
  const current = currentBranchName(repoRoot);
  if (current === branch) {
    return { ok: true, changed: false };
  }

  const checkoutResult = run('git', ['-C', repoRoot, 'checkout', branch], { timeout: 20_000 });
  if (checkoutResult.error && typeof checkoutResult.status !== 'number') {
    return {
      ok: false,
      changed: false,
      stdout: checkoutResult.stdout || '',
      stderr: checkoutResult.stderr || '',
    };
  }
  if (checkoutResult.status !== 0) {
    return {
      ok: false,
      changed: false,
      stdout: checkoutResult.stdout || '',
      stderr: checkoutResult.stderr || '',
    };
  }

  return { ok: true, changed: true };
}

function ensureOriginBaseRef(repoRoot, baseBranch) {
  const fetch = gitRun(repoRoot, ['fetch', 'origin', baseBranch, '--quiet'], { allowFailure: true });
  if (fetch.status !== 0) {
    throw new Error(
      `Unable to fetch origin/${baseBranch}. Ensure remote 'origin' exists and branch '${baseBranch}' is available.`,
    );
  }
  const hasRemoteBase = gitRun(repoRoot, ['show-ref', '--verify', '--quiet', `refs/remotes/origin/${baseBranch}`], {
    allowFailure: true,
  });
  if (hasRemoteBase.status !== 0) {
    throw new Error(`Remote base branch not found: origin/${baseBranch}`);
  }
}

function aheadBehind(repoRoot, branchRef, baseRef) {
  const result = gitRun(repoRoot, ['rev-list', '--left-right', '--count', `${branchRef}...${baseRef}`], {
    allowFailure: true,
  });
  if (result.status !== 0) {
    throw new Error(`Unable to compute ahead/behind for ${branchRef} vs ${baseRef}`);
  }
  const parts = (result.stdout || '').trim().split(/\s+/).filter(Boolean);
  const ahead = Number.parseInt(parts[0] || '0', 10);
  const behind = Number.parseInt(parts[1] || '0', 10);
  return { ahead: Number.isFinite(ahead) ? ahead : 0, behind: Number.isFinite(behind) ? behind : 0 };
}

function lockRegistryStatus(repoRoot) {
  const result = gitRun(repoRoot, ['status', '--porcelain', '--', LOCK_FILE_RELATIVE], { allowFailure: true });
  if (result.status !== 0) {
    return { dirty: false, untracked: false };
  }
  const lines = (result.stdout || '').split('\n').filter((line) => line.length > 0);
  if (lines.length === 0) {
    return { dirty: false, untracked: false };
  }
  const untracked = lines.some((line) => line.startsWith('??'));
  return { dirty: true, untracked };
}

function listAgentWorktrees(repoRoot) {
  const result = gitRun(repoRoot, ['worktree', 'list', '--porcelain'], { allowFailure: true });
  if (result.status !== 0) {
    throw new Error('Unable to list git worktrees for finish command');
  }

  const entries = [];
  let currentPath = '';
  let currentBranchRef = '';
  const lines = String(result.stdout || '').split('\n');
  for (const line of lines) {
    if (!line.trim()) {
      if (currentPath && currentBranchRef.startsWith('refs/heads/agent/')) {
        entries.push({
          worktreePath: currentPath,
          branch: currentBranchRef.replace(/^refs\/heads\//, ''),
        });
      }
      currentPath = '';
      currentBranchRef = '';
      continue;
    }
    if (line.startsWith('worktree ')) {
      currentPath = line.slice('worktree '.length).trim();
      continue;
    }
    if (line.startsWith('branch ')) {
      currentBranchRef = line.slice('branch '.length).trim();
      continue;
    }
  }
  if (currentPath && currentBranchRef.startsWith('refs/heads/agent/')) {
    entries.push({
      worktreePath: currentPath,
      branch: currentBranchRef.replace(/^refs\/heads\//, ''),
    });
  }

  return entries;
}

function listLocalAgentBranchesForFinish(repoRoot) {
  return uniquePreserveOrder(
    listLocalAgentBranches(repoRoot).filter((line) => line.startsWith('agent/')),
  );
}

function gitQuietChangeResult(worktreePath, args) {
  const result = run('git', ['-C', worktreePath, ...args], { stdio: 'pipe' });
  if (result.status === 0) {
    return false;
  }
  if (result.status === 1) {
    return true;
  }
  throw new Error(
    `git ${args.join(' ')} failed in ${worktreePath}: ${(
      result.stderr || result.stdout || ''
    ).trim()}`,
  );
}

function worktreeHasLocalChanges(worktreePath) {
  const hasUnstaged = gitQuietChangeResult(worktreePath, [
    'diff',
    '--quiet',
    '--',
    '.',
    ':(exclude).omx/state/agent-file-locks.json',
  ]);
  if (hasUnstaged) {
    return true;
  }

  const hasStaged = gitQuietChangeResult(worktreePath, [
    'diff',
    '--cached',
    '--quiet',
    '--',
    '.',
    ':(exclude).omx/state/agent-file-locks.json',
  ]);
  if (hasStaged) {
    return true;
  }

  const untracked = run('git', ['-C', worktreePath, 'ls-files', '--others', '--exclude-standard'], {
    stdio: 'pipe',
  });
  if (untracked.status !== 0) {
    throw new Error(`Unable to inspect untracked files in ${worktreePath}`);
  }
  return String(untracked.stdout || '').trim().length > 0;
}

function gitOutputLines(worktreePath, args) {
  const result = run('git', ['-C', worktreePath, ...args], { stdio: 'pipe' });
  if (result.status !== 0) {
    throw new Error(
      `git ${args.join(' ')} failed in ${worktreePath}: ${(
        result.stderr || result.stdout || ''
      ).trim()}`,
    );
  }
  return String(result.stdout || '')
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);
}

function branchExists(repoRoot, branch) {
  const result = gitRun(repoRoot, ['show-ref', '--verify', '--quiet', `refs/heads/${branch}`], {
    allowFailure: true,
  });
  return result.status === 0;
}

function resolveFinishBaseBranch(repoRoot, _sourceBranch, explicitBase) {
  if (explicitBase) {
    return explicitBase;
  }

  const configured = readGitConfig(repoRoot, GIT_BASE_BRANCH_KEY);
  if (configured) {
    return configured;
  }

  return DEFAULT_BASE_BRANCH;
}

function branchMergedIntoBase(repoRoot, branch, baseBranch) {
  if (!branchExists(repoRoot, baseBranch)) {
    return false;
  }
  const result = gitRun(repoRoot, ['merge-base', '--is-ancestor', branch, baseBranch], {
    allowFailure: true,
  });
  if (result.status === 0) {
    return true;
  }
  if (result.status === 1) {
    return false;
  }
  throw new Error(`Unable to determine merge status for ${branch} -> ${baseBranch}`);
}

function syncOperation(repoRoot, strategy, baseRef, ffOnly) {
  if (strategy === 'rebase') {
    if (ffOnly) {
      throw new Error('--ff-only is only supported with --strategy merge');
    }
    const rebased = run('git', ['-C', repoRoot, 'rebase', baseRef], { stdio: 'pipe' });
    if (rebased.status !== 0) {
      const details = (rebased.stderr || rebased.stdout || '').trim();
      const gitDir = path.join(repoRoot, '.git');
      const rebaseActive = fs.existsSync(path.join(gitDir, 'rebase-merge')) || fs.existsSync(path.join(gitDir, 'rebase-apply'));
      const help = rebaseActive
        ? '\nResolve conflicts, then run: git rebase --continue\nOr abort: git rebase --abort'
        : '';
      throw new Error(`Sync failed during rebase onto ${baseRef}.${details ? `\n${details}` : ''}${help}`);
    }
    return;
  }

  const mergeArgs = ['-C', repoRoot, 'merge', '--no-edit'];
  if (ffOnly) {
    mergeArgs.push('--ff-only');
  }
  mergeArgs.push(baseRef);
  const merged = run('git', mergeArgs, { stdio: 'pipe' });
  if (merged.status !== 0) {
    const details = (merged.stderr || merged.stdout || '').trim();
    const gitDir = path.join(repoRoot, '.git');
    const mergeActive = fs.existsSync(path.join(gitDir, 'MERGE_HEAD'));
    const help = mergeActive ? '\nResolve conflicts, then run: git commit\nOr abort: git merge --abort' : '';
    throw new Error(`Sync failed during merge from ${baseRef}.${details ? `\n${details}` : ''}${help}`);
  }
}

module.exports = {
  DEFAULT_NESTED_REPO_MAX_DEPTH: NESTED_REPO_DEFAULT_MAX_DEPTH,
  gitRun,
  resolveRepoRoot,
  isGitRepo,
  discoverNestedGitRepos,
  parseBranchList,
  uniquePreserveOrder,
  readConfiguredProtectedBranches,
  listLocalUserBranches,
  listLocalAgentBranches,
  mapWorktreePathsByBranch,
  gitRefExists,
  hasSignificantWorkingTreeChanges,
  readProtectedBranches,
  ensureSetupProtectedBranches,
  writeProtectedBranches,
  readGitConfig,
  resolveBaseBranch,
  resolveSyncStrategy,
  currentBranchName,
  repoHasHeadCommit,
  readBranchDisplayName,
  hasOriginRemote,
  repoHasOriginRemote: hasOriginRemote,
  detectComposeHintFiles,
  printSetupRepoHints,
  workingTreeIsDirty,
  ensureRepoBranch,
  ensureOriginBaseRef,
  aheadBehind,
  lockRegistryStatus,
  listAgentWorktrees,
  listLocalAgentBranchesForFinish,
  gitQuietChangeResult,
  worktreeHasLocalChanges,
  gitOutputLines,
  branchExists,
  resolveFinishBaseBranch,
  branchMergedIntoBase,
  syncOperation,
};
