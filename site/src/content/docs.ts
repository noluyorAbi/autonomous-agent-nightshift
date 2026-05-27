// Auto-synced from docs/*.md at build time.
// Update via: npm run sync
import playbook from "../../../docs/01-playbook.md?raw";
import bulletproofMode from "../../../docs/02-bulletproof-mode.md?raw";
import chromeTesting from "../../../docs/03-chrome-testing.md?raw";
import qaChecklist from "../../../docs/04-qa-checklist.md?raw";
import failureModes from "../../../docs/05-failure-modes.md?raw";
import testLoop from "../../../docs/06-test-loop.md?raw";
import costSafety from "../../../docs/07-cost-and-safety.md?raw";
import faq from "../../../docs/FAQ.md?raw";

export interface DocPage {
  slug: string;
  title: string;
  content: string;
}

export const docPages: DocPage[] = [
  { slug: "playbook", title: "Master playbook", content: playbook },
  { slug: "bulletproof", title: "Bulletproof mode", content: bulletproofMode },
  { slug: "chrome-testing", title: "Chrome MCP testing", content: chromeTesting },
  { slug: "qa-checklist", title: "QA checklist", content: qaChecklist },
  { slug: "failure-modes", title: "Failure modes", content: failureModes },
  { slug: "test-loop", title: "Test loop", content: testLoop },
  { slug: "cost-safety", title: "Cost & safety", content: costSafety },
  { slug: "faq", title: "FAQ", content: faq },
];
