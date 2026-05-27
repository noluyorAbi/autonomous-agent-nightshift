import { Link, NavLink } from "react-router-dom";
import { meta } from "../content/meta";

const links = [
  { to: "/install", label: "Install" },
  { to: "/commands", label: "Commands" },
  { to: "/docs", label: "Docs" },
  { to: "/onboarding", label: "Onboarding" },
];

export default function Nav() {
  return (
    <nav className="sticky top-0 z-50 backdrop-blur-md bg-bg/85 border-b border-border">
      <div className="container-narrow flex items-center justify-between py-3.5 gap-8">
        <Link to="/" className="font-mono font-bold text-base tracking-tight text-accent">
          nightshift{" "}
          <span className="text-fg-muted font-normal">v{meta.version}</span>
        </Link>

        <ul className="hidden md:flex items-center gap-7 text-sm">
          {links.map((l) => (
            <li key={l.to}>
              <NavLink
                to={l.to}
                className={({ isActive }) =>
                  `transition-colors ${isActive ? "text-fg" : "text-fg-muted hover:text-fg"}`
                }
              >
                {l.label}
              </NavLink>
            </li>
          ))}
        </ul>

        <a
          href="https://github.com/noluyorAbi/autonomous-agent-nightshift"
          target="_blank"
          rel="noopener noreferrer"
          className="font-mono text-sm px-4 py-2 border border-border-strong rounded-md text-fg hover:border-accent hover:text-accent hover:bg-accent-glow transition-all"
        >
          GitHub
        </a>
      </div>
    </nav>
  );
}
