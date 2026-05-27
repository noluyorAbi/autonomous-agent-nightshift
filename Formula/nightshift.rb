class Nightshift < Formula
  desc "Run Claude Code agents overnight on your codebase"
  homepage "https://github.com/noluyorAbi/autonomous-agent-nightshift"
  url "https://github.com/noluyorAbi/autonomous-agent-nightshift/archive/refs/tags/v1.4.0.tar.gz"
  # sha256 set by `brew bump-formula-pr` or computed manually on release:
  # shasum -a 256 v1.4.0.tar.gz
  sha256 "REPLACE_ON_RELEASE"
  license "MIT"
  head "https://github.com/noluyorAbi/autonomous-agent-nightshift.git", branch: "main"

  depends_on "bash"

  def install
    libexec.install Dir["*"]
    bin.write_exec_script libexec/"bin/nightshift"
    (bin/"nightshift").chmod 0755
  end

  def caveats
    <<~EOS
      nightshift requires the Claude Code CLI:
        Install: https://docs.claude.com/en/docs/claude-code

      For the Claude Code skill + slash commands, also install as a skill:
        git clone #{homepage} ~/.claude/skills/autonomous-agent-nightshift

      Read before first launch:
        #{opt_libexec}/docs/07-cost-and-safety.md
    EOS
  end

  test do
    assert_match "nightshift", shell_output("#{bin}/nightshift version")
  end
end
