import { motion } from "framer-motion";
import { commands } from "../content/commands";

export default function Commands() {
  return (
    <main className="container-narrow py-16">
      <h1 className="section-title">Slash commands</h1>
      <p className="section-subtitle">
        Six commands. Direct triggers inside Claude Code. Or talk naturally — the
        skill maps intent to the right workflow.
      </p>

      <div className="space-y-5">
        {commands.map((c, i) => (
          <motion.div
            key={c.name}
            initial={{ opacity: 0, y: 16 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: "-50px" }}
            transition={{ duration: 0.4, delay: i * 0.05 }}
            className="card card-hover"
          >
            <div className="flex items-center gap-3 mb-3 flex-wrap">
              <code className="font-mono text-base px-3 py-1.5 rounded bg-bg-code border border-border-strong text-accent">
                /{c.name}
              </code>
              <span className="font-mono text-xs text-fg-dim uppercase tracking-wider">
                {c.category}
              </span>
            </div>
            <p className="text-fg-muted leading-relaxed mb-3">{c.description}</p>
            {c.whenToUse && (
              <p className="text-fg text-sm leading-relaxed">
                <strong className="text-fg-muted text-xs uppercase tracking-wider block mb-1">When to use</strong>
                {c.whenToUse}
              </p>
            )}
          </motion.div>
        ))}
      </div>

      <div className="mt-12 card">
        <h3 className="text-lg font-semibold mb-3">Natural language also works</h3>
        <p className="text-fg-muted text-sm mb-3">
          The skill triggers on phrases like:
        </p>
        <ul className="space-y-2 text-fg-muted text-sm">
          <li>&ldquo;Set up a nightshift to add X, Y, Z to my project.&rdquo;</li>
          <li>&ldquo;Review last night&rsquo;s nightshift.&rdquo;</li>
          <li>&ldquo;Is my agent still running?&rdquo;</li>
          <li>&ldquo;Bulletproof this codebase before launch.&rdquo;</li>
          <li>&ldquo;Resume the nightshift — it died.&rdquo;</li>
          <li>&ldquo;Help me debug task 7, it failed 7 times.&rdquo;</li>
        </ul>
      </div>
    </main>
  );
}
