import { meta } from "../content/meta";

export default function Footer() {
  return (
    <footer className="border-t border-border mt-24 py-10 text-fg-dim text-sm">
      <div className="container-narrow flex flex-wrap items-start justify-between gap-6">
        <div className="font-mono text-xs">
          MIT &middot; built by{" "}
          <a
            href="https://github.com/noluyorAbi"
            className="text-fg-muted hover:text-accent transition-colors"
          >
            noluyorAbi
          </a>{" "}
          &middot; v{meta.version}
        </div>
        <div className="flex flex-wrap gap-5">
          <a
            href="https://github.com/noluyorAbi/autonomous-agent-nightshift"
            className="hover:text-accent transition-colors"
          >
            Source
          </a>
          <a
            href="https://www.npmjs.com/package/autonomous-agent-nightshift"
            className="hover:text-accent transition-colors"
          >
            npm
          </a>
          <a
            href="https://github.com/noluyorAbi/autonomous-agent-nightshift/blob/main/docs/01-playbook.md"
            className="hover:text-accent transition-colors"
          >
            Playbook
          </a>
          <a
            href="https://github.com/noluyorAbi/autonomous-agent-nightshift/blob/main/docs/07-cost-and-safety.md"
            className="hover:text-accent transition-colors"
          >
            Cost &amp; safety
          </a>
          <a
            href="https://github.com/noluyorAbi/autonomous-agent-nightshift/blob/main/docs/FAQ.md"
            className="hover:text-accent transition-colors"
          >
            FAQ
          </a>
          <a
            href="https://github.com/noluyorAbi/autonomous-agent-nightshift/releases"
            className="hover:text-accent transition-colors"
          >
            Releases
          </a>
        </div>
      </div>
    </footer>
  );
}
