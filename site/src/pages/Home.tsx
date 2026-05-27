import { motion } from "framer-motion";
import { Link } from "react-router-dom";
import { ArrowRight, Github, Package, BookOpen, Zap, ShieldAlert, Terminal, Clock } from "lucide-react";
import CopyableCommand from "../components/CopyableCommand";
import { meta } from "../content/meta";
import { commands } from "../content/commands";

const fadeUp = {
  initial: { opacity: 0, y: 24 },
  whileInView: { opacity: 1, y: 0 },
  viewport: { once: true, margin: "-80px" },
  transition: { duration: 0.5, ease: [0.16, 1, 0.3, 1] as const },
};

export default function Home() {
  return (
    <main>
      {/* HERO */}
      <section className="container-narrow pt-20 pb-16 text-center">
        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          className="inline-block px-3.5 py-1.5 mb-6 rounded-full bg-accent-glow border border-accent-dim text-accent font-mono text-xs tracking-wider"
        >
          Claude Code skill &middot; npm CLI &middot; bash harness
        </motion.div>

        <motion.h1
          initial={{ opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, delay: 0.1 }}
          className="text-5xl md:text-7xl font-extrabold leading-[1.05] tracking-tight mb-6"
          style={{
            background: "linear-gradient(180deg, #e6e8f0 0%, #aab0c8 100%)",
            WebkitBackgroundClip: "text",
            WebkitTextFillColor: "transparent",
            backgroundClip: "text",
          }}
        >
          Claude Code agents
          <br />
          that work overnight
        </motion.h1>

        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.7, delay: 0.25 }}
          className="text-lg md:text-xl text-fg-muted max-w-2xl mx-auto leading-relaxed mb-10"
        >
          Write a todo file with{" "}
          <strong className="text-fg">Implementation + Validation</strong> pairs.
          Launch the harness. Wake up to validated code &mdash; or a PR with review
          feedback already addressed.
        </motion.p>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, delay: 0.4 }}
          className="max-w-xl mx-auto mb-6"
        >
          <div className="text-xs font-mono uppercase tracking-wider text-fg-dim mb-2">install</div>
          <CopyableCommand command="npm install -g autonomous-agent-nightshift" />
        </motion.div>

        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.7, delay: 0.55 }}
          className="flex flex-wrap items-center justify-center gap-3 mb-10"
        >
          <Link to="/install" className="btn btn-primary">
            All install options
            <ArrowRight size={16} />
          </Link>
          <Link to="/onboarding" className="btn btn-secondary">
            Onboarding walkthrough
          </Link>
          <Link to="/docs/playbook" className="btn btn-secondary">
            <BookOpen size={16} />
            Playbook
          </Link>
        </motion.div>

        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.7, delay: 0.7 }}
          className="flex flex-wrap items-center justify-center gap-2"
        >
          <a href="https://www.npmjs.com/package/autonomous-agent-nightshift">
            <img
              src={`https://img.shields.io/npm/v/autonomous-agent-nightshift?label=npm&color=f59e0b`}
              alt="npm"
              className="h-5"
            />
          </a>
          <img
            src="https://img.shields.io/badge/License-MIT-yellow.svg"
            alt="MIT"
            className="h-5"
          />
          <img
            src="https://github.com/noluyorAbi/autonomous-agent-nightshift/actions/workflows/lint.yml/badge.svg"
            alt="CI"
            className="h-5"
          />
          <img
            src="https://img.shields.io/badge/Claude%20Code-Skill+Plugin-orange"
            alt="Claude Code"
            className="h-5"
          />
        </motion.div>
      </section>

      {/* HOW IT WORKS */}
      <motion.section {...fadeUp} className="container-narrow py-20 border-t border-border">
        <h2 className="section-title">How it works</h2>
        <p className="section-subtitle">Three components. One overnight loop.</p>

        <div className="grid md:grid-cols-3 gap-5">
          {[
            {
              num: "01",
              tag: "YOU WRITE",
              title: "Feature plan",
              icon: <Terminal size={20} className="text-accent" />,
              desc: "Todo file with checkboxes. Each task has an Implementation paragraph and a testable Validation criterion. The runner parses it strictly.",
            },
            {
              num: "02",
              tag: "HARNESS RUNS",
              title: "Runner script",
              icon: <Zap size={20} className="text-accent" />,
              desc: "Bash harness extracts next task, calls claude -p, runs the validation gate, retries on failure up to MAX_FIX_ATTEMPTS, marks done.",
            },
            {
              num: "03",
              tag: "AGENT BUILDS",
              title: "Codebase context",
              icon: <BookOpen size={20} className="text-accent" />,
              desc: "Heredoc with your file map, conventions, forbidden patterns. The agent has no memory between calls — this is its only map.",
            },
          ].map((s, i) => (
            <motion.div
              key={s.num}
              {...fadeUp}
              transition={{ ...fadeUp.transition, delay: i * 0.1 }}
              className="card card-hover"
            >
              <div className="flex items-center gap-2 mb-3">
                {s.icon}
                <span className="font-mono text-xs text-accent tracking-wider">
                  {s.num} &middot; {s.tag}
                </span>
              </div>
              <h3 className="text-lg font-semibold mb-2">{s.title}</h3>
              <p className="text-fg-muted text-sm leading-relaxed">{s.desc}</p>
            </motion.div>
          ))}
        </div>

        <motion.pre
          {...fadeUp}
          className="mt-10 code-block text-sm leading-[1.85]"
        >
{`Phase 1: Implement   Claude writes code + tests
Phase 2: Validate    prettier · tsc · eslint · test runner
  └─ Fix loop        up to MAX_FIX_ATTEMPTS (default 7)
Phase 3: Chrome      optional live browser test via Claude-in-Chrome MCP
  └─ Fix loop        up to MAX_CHROME_FIX_ATTEMPTS (default 3)
Phase 4: Mark done   checkbox [x] in todo file`}
        </motion.pre>

        <p className="mt-6 text-fg-muted text-sm">
          Failed tasks get <code className="code-inline">[x] — NEEDS MANUAL REVIEW</code>{" "}
          and the loop moves on. You triage in the morning.
        </p>
      </motion.section>

      {/* SLASH COMMANDS */}
      <motion.section {...fadeUp} className="container-narrow py-20 border-t border-border">
        <h2 className="section-title">Six slash commands</h2>
        <p className="section-subtitle">Direct triggers inside Claude Code. Or just talk naturally — the skill picks up the intent.</p>

        <div className="grid md:grid-cols-2 gap-3">
          {commands.map((c, i) => (
            <motion.div
              key={c.name}
              {...fadeUp}
              transition={{ ...fadeUp.transition, delay: (i % 6) * 0.06 }}
              className="card card-hover"
            >
              <code className="code-inline mb-2 inline-block">/{c.name}</code>
              <p className="text-fg-muted text-sm leading-relaxed mt-2">
                {c.description}
              </p>
            </motion.div>
          ))}
        </div>

        <div className="text-center mt-8">
          <Link to="/commands" className="btn btn-secondary">
            Full command reference
            <ArrowRight size={16} />
          </Link>
        </div>
      </motion.section>

      {/* COST CALLOUT */}
      <motion.section {...fadeUp} className="container-narrow py-20 border-t border-border">
        <h2 className="section-title">Cost &amp; safety</h2>
        <p className="section-subtitle">Spends real money. Modifies code unsupervised. Read before launching.</p>

        <div
          className="rounded-xl p-6 mb-6"
          style={{
            background:
              "linear-gradient(135deg, rgba(248, 113, 113, 0.08), rgba(245, 158, 11, 0.05))",
            border: "1px solid rgba(248, 113, 113, 0.3)",
            borderLeft: "3px solid #f87171",
          }}
        >
          <div className="flex items-center gap-2 mb-2">
            <ShieldAlert size={18} className="text-danger" />
            <span className="font-mono text-xs uppercase tracking-wider text-danger">Warning</span>
          </div>
          <p className="text-fg mb-2">
            <strong>Default overnight run costs $8&ndash;50 (Sonnet) or $25&ndash;100 (Opus).</strong>{" "}
            A 100-step Bulletproof sweep can hit $500.
          </p>
          <p className="text-fg-muted text-sm mb-2">
            Always set <code className="code-inline">MAX_ITERATIONS</code> — the iteration cap{" "}
            <em>is</em> your worst-case cost cap. Set Anthropic Console spending limits as a hard ceiling.
          </p>
          <p className="text-fg-muted text-sm">
            The agent edits files autonomously. Commit work you care about before launch.
            Protect <code className="code-inline">main</code> via branch protection.
          </p>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-bg-elevated">
              <tr>
                <th className="text-left p-3 border border-border text-fg-dim font-medium uppercase tracking-wider text-xs">
                  Scenario
                </th>
                <th className="text-left p-3 border border-border text-fg-dim font-medium uppercase tracking-wider text-xs">
                  Sonnet cost
                </th>
                <th className="text-left p-3 border border-border text-fg-dim font-medium uppercase tracking-wider text-xs">
                  Opus cost
                </th>
              </tr>
            </thead>
            <tbody>
              {[
                ["5 easy tasks", "~$3", "~$8"],
                ["16 mixed tasks (default)", "$8 – $25", "$25 – $50"],
                ["30+ ambitious tasks", "$20 – $60", "$60 – $150"],
                ["100-step Bulletproof sweep", "$100 – $200", "$250 – $500"],
              ].map(([s, sc, oc]) => (
                <tr key={s} className="hover:bg-bg-elevated transition-colors">
                  <td className="p-3 border border-border text-fg font-medium">{s}</td>
                  <td className="p-3 border border-border text-fg-muted font-mono">{sc}</td>
                  <td className="p-3 border border-border text-fg-muted font-mono">{oc}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </motion.section>

      {/* USE CASES */}
      <motion.section {...fadeUp} className="container-narrow py-20 border-t border-border">
        <h2 className="section-title">What it&rsquo;s for</h2>
        <p className="section-subtitle">
          Multi-task batches where validation can be programmatic. Not for single bugfixes or judgment-heavy decisions.
        </p>

        <div className="grid md:grid-cols-2 gap-4">
          {[
            {
              tag: "PRIMARY",
              title: "Overnight feature batches",
              desc: "5–20 well-spec'd tasks with tests as oracle. Agent implements while you sleep. You review the diff at breakfast.",
              icon: <Clock size={18} className="text-accent" />,
            },
            {
              tag: "BULLETPROOF MODE",
              title: "Production hardening sweeps",
              desc: "Quarterly security / accessibility / perf passes. Branch + commit per step + PR + review-comment self-healing.",
              icon: <ShieldAlert size={18} className="text-accent" />,
            },
            {
              tag: "USE CASE",
              title: "Mechanical migrations",
              desc: "Tailwind v3 → v4, React 18 → 19, dep bumps. File-by-file, validation gate catches regressions.",
              icon: <Zap size={18} className="text-accent" />,
            },
            {
              tag: "USE CASE",
              title: "Test backfilling",
              desc: "Add tests to legacy code one file at a time. Validation = test runs + coverage threshold rise.",
              icon: <Terminal size={18} className="text-accent" />,
            },
          ].map((u, i) => (
            <motion.div
              key={u.title}
              {...fadeUp}
              transition={{ ...fadeUp.transition, delay: i * 0.08 }}
              className="card card-hover"
            >
              <div className="flex items-center gap-2 mb-2">
                {u.icon}
                <span className="font-mono text-xs text-accent tracking-wider">{u.tag}</span>
              </div>
              <h4 className="text-base font-semibold mb-2">{u.title}</h4>
              <p className="text-fg-muted text-sm leading-relaxed">{u.desc}</p>
            </motion.div>
          ))}
        </div>
      </motion.section>

      {/* FINAL CTA */}
      <motion.section {...fadeUp} className="container-narrow py-24 text-center border-t border-border">
        <h2 className="text-3xl md:text-5xl font-bold tracking-tight mb-4">
          Build while you sleep.
        </h2>
        <p className="text-fg-muted text-lg max-w-xl mx-auto mb-8">
          Install once. Write a todo. Wake to validated code.
        </p>
        <div className="flex flex-wrap items-center justify-center gap-3">
          <a
            href="https://www.npmjs.com/package/autonomous-agent-nightshift"
            className="btn btn-primary"
          >
            <Package size={16} />
            npm
          </a>
          <a
            href="https://github.com/noluyorAbi/autonomous-agent-nightshift"
            className="btn btn-secondary"
          >
            <Github size={16} />
            GitHub
          </a>
          <Link to="/onboarding" className="btn btn-secondary">
            Start tutorial
            <ArrowRight size={16} />
          </Link>
        </div>
      </motion.section>
    </main>
  );
}
