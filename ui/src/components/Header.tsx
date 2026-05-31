import { Box, Text } from 'ink';
import Spinner from 'ink-spinner';
import type { RunState } from '../types';
import { theme, statusBadge, progressBar } from '../theme';

export function Header({
  state,
  taskIdx,
  taskTotal,
  statusOverride,
}: {
  state: RunState;
  taskIdx: number;
  taskTotal: number;
  statusOverride?: string;
}) {
  const status = statusOverride ?? state.status;
  const badge = statusBadge(status);
  const idle = status === 'idle';
  const bar = progressBar(taskIdx, taskTotal, 16);
  const cost = state.cost ? `~$${state.cost}` : 'cost n/a';
  return (
    <Box flexDirection="column">
      <Box>
        <Text bold color={theme.accentBright}>
          {' '}
          nightshift{' '}
        </Text>
        <Text> </Text>
        <Text backgroundColor={badge.bg} color={badge.fg} bold>
          {' '}
          {badge.label}{' '}
        </Text>
        {status === 'running' ? (
          <Text color={theme.ok}>
            {' '}
            <Spinner type="dots" />
          </Text>
        ) : null}
        <Box flexGrow={1} />
        {idle ? (
          <Text color={theme.muted}>control center</Text>
        ) : (
          <Text color={theme.muted}>
            task {taskIdx}/{taskTotal} · iter {state.iteration}/
            {state.maxIterations}
          </Text>
        )}
        <Text> </Text>
      </Box>
      {idle ? null : (
        <Box>
          <Text> </Text>
          <Text color={theme.ok}>{bar}</Text>
          <Text color={theme.muted}> {cost}</Text>
        </Box>
      )}
    </Box>
  );
}
