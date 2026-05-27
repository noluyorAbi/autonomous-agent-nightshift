import { NavLink, Routes, Route, Navigate } from "react-router-dom";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import { docPages } from "../content/docs";

export default function Docs() {
  return (
    <main className="container-narrow py-12">
      <div className="grid md:grid-cols-[220px_1fr] gap-10">
        {/* sidebar */}
        <aside className="md:sticky md:top-20 self-start">
          <h2 className="font-mono text-xs uppercase tracking-wider text-fg-dim mb-3">
            Docs
          </h2>
          <ul className="space-y-1">
            {docPages.map((d) => (
              <li key={d.slug}>
                <NavLink
                  to={`/docs/${d.slug}`}
                  className={({ isActive }) =>
                    `block px-3 py-2 rounded text-sm transition-colors ${
                      isActive
                        ? "bg-accent-glow text-accent border-l-2 border-accent"
                        : "text-fg-muted hover:text-fg hover:bg-bg-card"
                    }`
                  }
                >
                  {d.title}
                </NavLink>
              </li>
            ))}
          </ul>
        </aside>

        <article className="prose-night min-w-0">
          <Routes>
            <Route index element={<Navigate to={docPages[0].slug} replace />} />
            {docPages.map((d) => (
              <Route
                key={d.slug}
                path={d.slug}
                element={
                  <>
                    <h1>{d.title}</h1>
                    <ReactMarkdown remarkPlugins={[remarkGfm]}>
                      {d.content}
                    </ReactMarkdown>
                  </>
                }
              />
            ))}
          </Routes>
        </article>
      </div>
    </main>
  );
}
