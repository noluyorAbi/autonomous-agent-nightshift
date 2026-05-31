import { Box, Text } from 'ink';
import { theme } from '../theme';

// Bottom bar. In input mode: a compose prompt with the live buffer + cursor.
// In nav mode: the keybinding hint line, with the last note's delivery status
// on the right (queued/delivered — full ack lands in Milestone 4).
export function MessageBar({
  mode,
  buffer,
  noteStatus,
}: {
  mode: 'nav' | 'input';
  buffer: string;
  noteStatus: string;
}) {
  if (mode === 'input') {
    return (
      <Box>
        <Text color={theme.warn} bold>
          {'› '}
        </Text>
        <Text>{buffer}</Text>
        <Text inverse> </Text>
        <Text color={theme.muted}> (Enter send · Esc cancel)</Text>
      </Box>
    );
  }
  return (
    <Box>
      <Hint k="i" label="msg" />
      <Hint k="p" label="pause" />
      <Hint k="r" label="resume" />
      <Hint k="n" label="skip" />
      <Hint k="s" label="stop" />
      <Hint k="t" label="logs" />
      <Hint k="?" label="help" />
      <Hint k="q" label="quit" />
      <Box flexGrow={1} />
      {noteStatus ? <Text color={theme.muted}>{noteStatus} </Text> : null}
    </Box>
  );
}

function Hint({ k, label }: { k: string; label: string }) {
  return (
    <Text>
      {' '}
      <Text color={theme.accent}>{k}</Text>
      <Text color={theme.muted}> {label}</Text>
    </Text>
  );
}
