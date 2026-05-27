// Auto-synced from commands/*.md at build time.
// Update via: npm run sync
export interface Command {
  name: string;
  description: string;
  category: string;
  whenToUse?: string;
}

export const commands: Command[] = [
  {
    name: "nightshift-setup",
    category: "SETUP",
    description:
      "Walks you through setting up a new nightshift run on the current project. Detects your stack, drafts the todo file with Implementation+Validation pairs, generates the codebase context heredoc, configures the runner, runs pre-flight checks, and gives you the exact launch command.",
    whenToUse: "Starting a brand-new nightshift in a project you haven't run one in before.",
  },
  {
    name: "nightshift-status",
    category: "OBSERVE",
    description:
      "Checks whether a nightshift is currently running. Reports the PID, current task, iteration budget used, time elapsed, and rough ETA based on average task duration.",
    whenToUse: "At any time during a run. Especially useful right after starting (verify it didn't die immediately) and in the morning (see what's still in flight).",
  },
  {
    name: "nightshift-review",
    category: "REVIEW",
    description:
      "Reads .agent-logs/nightshift-summary.log, greps the todo for REVIEW-flagged tasks, summarizes the git diff by area, lists any CHROME REVIEW NEEDED screenshots, and produces a structured morning report with suggested commits.",
    whenToUse: "Morning after a completed run. Or any time you want a quick status without launching anything new.",
  },
  {
    name: "nightshift-resume",
    category: "RECOVER",
    description:
      "Diagnoses why a nightshift stopped (iteration cap, rate limit, auth expired, crash, dev-server died), instructs you through the fix, and restarts cleanly from the next unchecked task. The runner is inherently resumable; this command codifies the diagnose+resume workflow.",
    whenToUse: "A run died before completing. You want to pick up where it left off without re-running already-finished tasks.",
  },
  {
    name: "nightshift-debug",
    category: "TRIAGE",
    description:
      "A specific task exhausted MAX_FIX_ATTEMPTS and got marked NEEDS MANUAL REVIEW. Walks through the task spec, Claude transcript, and validation logs to classify the failure pattern, then proposes one of three actions: rewrite the task, fix the codebase context, or implement manually.",
    whenToUse: "Morning review shows a task that failed all retries. You want to understand why and decide what to do.",
  },
  {
    name: "nightshift-bulletproof",
    category: "PRODUCTION",
    description:
      "Sets up a production-hardening sweep with branch + commit per step + PR + review-comment self-healing. Audits the codebase, proposes a BULLETPROOF-STEPS.md organized by category (security, performance, accessibility, observability, etc), configures the bulletproof runner, runs pre-flight.",
    whenToUse: "Quarterly production-readiness pass. Pre-launch hardening. Mechanical refactor work that benefits from per-step commits and automated PR review healing.",
  },
];
