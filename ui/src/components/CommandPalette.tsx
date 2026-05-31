import { Box, Text } from 'ink';
import { theme } from '../theme';
import type { Command } from '../actions';

// `:` overlay listing every runnable subcommand.
export function CommandPalette({
  commands,
  selected,
  rows,
}: {
  commands: Command[];
  selected: number;
  rows: number;
}) {
  const body: React.ReactNode[] = [];
  for (let i = 0; i < rows; i++) {
    const c = commands[i];
    if (!c) {
      body.push(<Text key={i}> </Text>);
      continue;
    }
    const isSel = i === selected;
    body.push(
      <Text key={i}>
        <Text color={theme.accent}>{isSel ? '› ' : '  '}</Text>
        <Text inverse={isSel} bold={isSel}>
          {c.label.padEnd(14)}
        </Text>
        <Text color={theme.muted}> {c.desc}</Text>
      </Text>,
    );
  }
  return (
    <Box flexDirection="column">
      <Text bold color={theme.accent}>
        Run a command
      </Text>
      {body}
      <Text color={theme.muted}> ↑/↓ select · ⏎ run · q/Esc close</Text>
    </Box>
  );
}
