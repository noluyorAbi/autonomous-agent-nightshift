import { Box, Text } from 'ink';
import type { RunState } from '../types';
import { theme } from '../theme';

export function StatusBar({
  state,
  lastAction,
}: {
  state: RunState;
  lastAction: string;
}) {
  return (
    <Box flexDirection="column">
      <Box>
        <Text color={theme.muted}> phase </Text>
        <Text color={theme.magenta}>{state.phase || 'n/a'}</Text>
        <Text color={theme.muted}> · val </Text>
        <Text>
          {state.validationAttempt}/{state.validationMax}
        </Text>
        <Text color={theme.muted}> · chrome </Text>
        <Text color={state.chromeEnabled ? theme.ok : theme.muted}>
          {state.chromeEnabled ? 'on' : 'off'}
        </Text>
        <Text color={theme.muted}> · </Text>
        <Text color={theme.accent}>{lastAction}</Text>
      </Box>
      <Box>
        <Text color={theme.muted}> task </Text>
        <Text wrap="truncate">{state.taskName || 'n/a'}</Text>
      </Box>
      <Box>
        <Text color={theme.muted}> error </Text>
        <Text color={state.lastError ? theme.err : theme.muted} wrap="truncate">
          {state.lastError || 'none'}
        </Text>
      </Box>
    </Box>
  );
}
