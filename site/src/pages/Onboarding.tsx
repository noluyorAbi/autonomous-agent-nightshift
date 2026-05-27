import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { ArrowLeft, ArrowRight, Check } from "lucide-react";
import CopyableCommand from "../components/CopyableCommand";
import { Link } from "react-router-dom";

const steps = [
  {
    title: "Install the CLI",
    body: (
      <>
        <p className="text-fg-muted mb-4">
          One command on macOS or Linux. The <code className="code-inline">nightshift</code>{" "}
          binary will be on your PATH after this.
        </p>
        <CopyableCommand command="npm install -g autonomous-agent-nightshift" />
        <p className="text-fg-muted text-sm mt-3">
          Verify it landed:
        </p>
        <CopyableCommand command="nightshift version" />
      </>
    ),
  },
  {
    title: "Install Claude Code (if you haven't)",
    body: (
      <>
        <p className="text-fg-muted mb-4">
          Nightshift drives the <code className="code-inline">claude</code> CLI. You need it
          installed and authenticated. Follow the official install:
        </p>
        <a
          href="https://docs.claude.com/en/docs/claude-code"
          className="btn btn-secondary inline-flex"
          target="_blank"
          rel="noopener noreferrer"
        >
          docs.claude.com / claude-code
          <ArrowRight size={14} />
        </a>
        <p className="text-fg-muted text-sm mt-4">Then verify:</p>
        <CopyableCommand command="claude --version" />
      </>
    ),
  },
  {
    title: "Bootstrap a run in your project",
    body: (
      <>
        <p className="text-fg-muted mb-4">
          Go to your project directory. Pick a name for tonight's batch.
        </p>
        <CopyableCommand command="cd your-project" />
        <CopyableCommand command="nightshift init add-dark-mode" />
        <p className="text-fg-muted text-sm mt-4">
          This creates three files in your project:
        </p>
        <ul className="text-fg-muted text-sm space-y-1.5 mt-2 ml-6 list-disc">
          <li><code className="code-inline">todo-2026_MM_DD_add-dark-mode.md</code> — edit this</li>
          <li><code className="code-inline">run-agent-loop.sh</code> — edit this</li>
          <li><code className="code-inline">start-nightshift.sh</code> — no edits</li>
        </ul>
      </>
    ),
  },
  {
    title: "Write the todo file",
    body: (
      <>
        <p className="text-fg-muted mb-4">
          Open the todo file. Add 5–20 tasks. Each one needs <strong className="text-fg">Implementation</strong>{" "}
          and <strong className="text-fg">Validation</strong>:
        </p>
        <pre className="code-block text-xs leading-relaxed">
{`## Phase 1 — Theme Plumbing

- [ ] **Task 1: Add theme context and provider**
  - **Implementation:** Create src/lib/theme-context.tsx.
    Export ThemeProvider with state { theme, setTheme }.
    Persist to localStorage under key 'app-theme'.
  - **Validation:** In src/lib/theme-context.test.tsx, render
    <ThemeProvider> with a child that consumes the context.
    Assert default theme is 'light' when no localStorage.`}
        </pre>
        <p className="text-fg-muted text-sm mt-4">
          <strong className="text-fg">Rule:</strong> if you can't write a testable Validation,
          you can't write the task. The agent works only when the gate is enforceable.
        </p>
      </>
    ),
  },
  {
    title: "Configure the runner",
    body: (
      <>
        <p className="text-fg-muted mb-4">
          Open <code className="code-inline">run-agent-loop.sh</code>. Find the{" "}
          <code className="code-inline">CODEBASE_CONTEXT</code> heredoc. Paste your project's
          file map and conventions there. Update{" "}
          <code className="code-inline">run_full_validation()</code> for your toolchain:
        </p>
        <pre className="code-block text-xs leading-relaxed">
{`# Node/TS default:
run_full_validation() {
  npx prettier --write . && \\
  npx tsc --noEmit && \\
  npx eslint . --quiet && \\
  bun test
}

# Python:
# black . && mypy . && ruff check . && pytest

# Go:
# gofmt -w . && go vet ./... && golangci-lint run && go test ./...`}
        </pre>
      </>
    ),
  },
  {
    title: "Launch",
    body: (
      <>
        <p className="text-fg-muted mb-4">
          Pre-flight check: clean baseline, no uncommitted work you care about, Anthropic
          spending limit set.
        </p>
        <CopyableCommand command="nightshift start" />
        <p className="text-fg-muted text-sm mt-4">Follow the log in another terminal:</p>
        <CopyableCommand command="nightshift tail" />
        <p className="text-fg-muted text-sm mt-4">Sleep.</p>
      </>
    ),
  },
  {
    title: "Morning review",
    body: (
      <>
        <p className="text-fg-muted mb-4">When you wake up:</p>
        <CopyableCommand command="nightshift status" />
        <CopyableCommand command="nightshift review" />
        <p className="text-fg-muted text-sm mt-4">
          You'll see: how many tasks completed, which need review, the diff. Triage manually,
          then commit what you accept:
        </p>
        <CopyableCommand command="git diff --stat" />
        <CopyableCommand command="git add -p && git commit" />
        <p className="text-fg-muted text-sm mt-4">
          If something failed, run <code className="code-inline">/nightshift-debug</code> in
          Claude Code (or read the logs in <code className="code-inline">.agent-logs/</code>).
        </p>
      </>
    ),
  },
];

export default function Onboarding() {
  const [step, setStep] = useState(0);

  return (
    <main className="container-narrow py-16">
      <h1 className="section-title">Onboarding</h1>
      <p className="section-subtitle">
        Step-by-step walkthrough from install to first morning review.
      </p>

      {/* progress */}
      <div className="flex items-center gap-2 mb-10">
        {steps.map((_, i) => (
          <button
            key={i}
            onClick={() => setStep(i)}
            className={`flex-1 h-1.5 rounded-full transition-all ${
              i === step
                ? "bg-accent"
                : i < step
                  ? "bg-accent/50"
                  : "bg-border"
            }`}
            aria-label={`Go to step ${i + 1}`}
          />
        ))}
      </div>

      <div className="text-fg-dim font-mono text-xs uppercase tracking-wider mb-3">
        Step {step + 1} of {steps.length}
      </div>

      <AnimatePresence mode="wait">
        <motion.div
          key={step}
          initial={{ opacity: 0, x: 30 }}
          animate={{ opacity: 1, x: 0 }}
          exit={{ opacity: 0, x: -30 }}
          transition={{ duration: 0.3 }}
          className="card mb-6"
        >
          <h2 className="text-2xl font-bold mb-5">{steps[step].title}</h2>
          {steps[step].body}
        </motion.div>
      </AnimatePresence>

      <div className="flex items-center justify-between gap-3">
        <button
          onClick={() => setStep(Math.max(0, step - 1))}
          disabled={step === 0}
          className="btn btn-secondary disabled:opacity-40 disabled:cursor-not-allowed"
        >
          <ArrowLeft size={14} />
          Back
        </button>

        {step < steps.length - 1 ? (
          <button
            onClick={() => setStep(step + 1)}
            className="btn btn-primary"
          >
            Next
            <ArrowRight size={14} />
          </button>
        ) : (
          <Link to="/docs/playbook" className="btn btn-primary">
            <Check size={14} />
            Read the playbook
          </Link>
        )}
      </div>
    </main>
  );
}
