import { useState } from "react";
import { Check, Copy } from "lucide-react";

interface Props {
  command: string;
  prompt?: string;
}

export default function CopyableCommand({ command, prompt = "$" }: Props) {
  const [copied, setCopied] = useState(false);

  const copy = () => {
    navigator.clipboard.writeText(command);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  };

  return (
    <div className="relative bg-bg-code border border-border-strong rounded-lg px-4 py-3.5 pr-14 font-mono text-sm overflow-x-auto group hover:border-accent-dim transition-colors">
      <span className="text-accent select-none mr-2">{prompt}</span>
      <span className="text-fg">{command}</span>
      <button
        onClick={copy}
        className={`absolute top-2 right-2 px-2.5 py-1.5 rounded border text-xs font-mono transition-all ${
          copied
            ? "border-success text-success"
            : "border-border-strong text-fg-muted hover:border-accent hover:text-accent"
        }`}
        aria-label="Copy command"
      >
        {copied ? <Check size={12} /> : <Copy size={12} />}
      </button>
    </div>
  );
}
