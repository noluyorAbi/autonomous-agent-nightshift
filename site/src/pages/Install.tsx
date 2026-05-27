import { motion } from "framer-motion";
import CopyableCommand from "../components/CopyableCommand";

const channels = [
  {
    name: "npm",
    tag: "recommended",
    desc: "Installs the nightshift CLI globally. Works on macOS, Linux, WSL.",
    install: "npm install -g autonomous-agent-nightshift",
    afterInstall: "nightshift help",
  },
  {
    name: "Homebrew",
    tag: "macOS",
    desc: "Builds from HEAD via the bundled Formula.",
    install:
      "brew install --HEAD https://raw.githubusercontent.com/noluyorAbi/autonomous-agent-nightshift/main/Formula/nightshift.rb",
    afterInstall: "nightshift help",
  },
  {
    name: "curl one-liner",
    tag: "installs as Claude Code skill",
    desc: "Clones the repo into ~/.claude/skills/. Restart Claude Code to pick up the skill and slash commands.",
    install:
      "curl -fsSL https://raw.githubusercontent.com/noluyorAbi/autonomous-agent-nightshift/main/bin/install.sh | bash",
    afterInstall: "# Restart Claude Code, then ask: \"set up a nightshift for X\"",
  },
  {
    name: "Claude Code plugin",
    tag: "in-CC",
    desc: "Adds the marketplace, then installs the plugin. Brings the skill + all 6 slash commands.",
    install:
      "/plugin marketplace add noluyorAbi/autonomous-agent-nightshift",
    afterInstall: "/plugin install autonomous-agent-nightshift",
  },
  {
    name: "Tarball",
    tag: "no deps",
    desc: "Download a tagged release tarball. Useful for air-gapped or vendored installs.",
    install:
      "curl -L https://github.com/noluyorAbi/autonomous-agent-nightshift/releases/latest/download/autonomous-agent-nightshift-1.4.0.tar.gz | tar xz",
    afterInstall: "./bin/nightshift help",
  },
  {
    name: "Git clone",
    tag: "full repo",
    desc: "For contributors and tinkerers. Full source, all branches, all history.",
    install: "git clone https://github.com/noluyorAbi/autonomous-agent-nightshift",
    afterInstall: "cd autonomous-agent-nightshift && ./bin/nightshift help",
  },
];

export default function Install() {
  return (
    <main className="container-narrow py-16">
      <h1 className="section-title">Install</h1>
      <p className="section-subtitle">
        Six channels. Pick whichever matches your tooling. The CLI, skill, and
        slash commands are orthogonal — combine any.
      </p>

      <div className="space-y-5">
        {channels.map((c, i) => (
          <motion.div
            key={c.name}
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: "-50px" }}
            transition={{ duration: 0.4, delay: i * 0.05 }}
            className="card card-hover"
          >
            <div className="flex items-center justify-between mb-2 flex-wrap gap-2">
              <h3 className="text-lg font-semibold">{c.name}</h3>
              <span className="font-mono text-xs px-2.5 py-0.5 rounded bg-accent-glow text-accent tracking-wider">
                {c.tag}
              </span>
            </div>
            <p className="text-fg-muted text-sm mb-3">{c.desc}</p>
            <div className="space-y-2">
              <CopyableCommand command={c.install} />
              <CopyableCommand command={c.afterInstall} prompt={c.afterInstall.startsWith("/") ? ">" : "$"} />
            </div>
          </motion.div>
        ))}
      </div>

      <div className="mt-12 card">
        <h3 className="text-lg font-semibold mb-3">What each channel gives you</h3>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-bg-elevated">
              <tr>
                <th className="text-left p-3 border border-border text-fg-dim font-medium uppercase tracking-wider text-xs">Channel</th>
                <th className="text-left p-3 border border-border text-fg-dim font-medium uppercase tracking-wider text-xs">CLI <code className="code-inline">nightshift</code></th>
                <th className="text-left p-3 border border-border text-fg-dim font-medium uppercase tracking-wider text-xs">Skill</th>
                <th className="text-left p-3 border border-border text-fg-dim font-medium uppercase tracking-wider text-xs">Slash commands</th>
              </tr>
            </thead>
            <tbody>
              <tr><td className="p-3 border border-border text-fg">npm</td><td className="p-3 border border-border text-success">yes</td><td className="p-3 border border-border text-fg-dim">no</td><td className="p-3 border border-border text-fg-dim">no</td></tr>
              <tr><td className="p-3 border border-border text-fg">Homebrew</td><td className="p-3 border border-border text-success">yes</td><td className="p-3 border border-border text-fg-dim">no</td><td className="p-3 border border-border text-fg-dim">no</td></tr>
              <tr><td className="p-3 border border-border text-fg">curl one-liner</td><td className="p-3 border border-border text-fg-dim">no</td><td className="p-3 border border-border text-success">yes</td><td className="p-3 border border-border text-success">yes</td></tr>
              <tr><td className="p-3 border border-border text-fg">Claude Code plugin</td><td className="p-3 border border-border text-fg-dim">no</td><td className="p-3 border border-border text-success">yes</td><td className="p-3 border border-border text-success">yes</td></tr>
              <tr><td className="p-3 border border-border text-fg">Tarball / git clone</td><td className="p-3 border border-border text-success">via PATH</td><td className="p-3 border border-border text-warning">if in ~/.claude/skills/</td><td className="p-3 border border-border text-warning">via plugin</td></tr>
            </tbody>
          </table>
        </div>
        <p className="text-fg-muted text-sm mt-3">
          For full power: install via npm/brew (CLI) <strong className="text-fg">and</strong> the curl one-liner (skill + slash commands).
        </p>
      </div>
    </main>
  );
}
