import { Box, Text } from 'ink';
import { theme } from '../theme';

// Scrollable capture of a subcommand's output (review/status/etc).
export function OutputModal({
  title,
  lines,
  offset,
  rows,
  width,
  running,
}: {
  title: string;
  lines: string[];
  offset: number;
  rows: number;
  width: number;
  running: boolean;
}) {
  const view = lines.slice(offset, offset + rows);
  const body: React.ReactNode[] = [];
  for (let i = 0; i < rows; i++) {
    const l = view[i] ?? '';
    body.push(
      <Text key={i} wrap="truncate">
        {l.slice(0, width)}
      </Text>,
    );
  }
  const more = lines.length > offset + rows ? ` · ↓ ${lines.length - offset - rows} more` : '';
  return (
    <Box flexDirection="column">
      <Text bold color={theme.accent}>
        {title}
        {running ? <Text color={theme.warn}> (running…)</Text> : null}
      </Text>
      {body}
      <Text color={theme.muted}>
        {' '}
        j/k scroll · q/Esc close{more}
      </Text>
    </Box>
  );
}
