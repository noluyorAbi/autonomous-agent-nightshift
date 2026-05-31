import React from 'react';
import { Box, Text } from 'ink';
import { theme } from '../theme';

export function Help({ rows }: { rows: number }) {
  const lines: React.ReactNode[] = [
    <Text key="t" bold>
      Keybindings
    </Text>,
    <Text key="b1"> </Text>,
    row('i', 'write a message to the running agent'),
    row('p / r', 'pause / resume the run'),
    row('n', 'skip the current task'),
    row('s / x', 'stop gracefully  ·  K force-kill (last resort)'),
    row('j / k  ↑/↓', 'move the task selection'),
    row('t', 'toggle log source (summary / events)'),
    row('?', 'close this help  ·  q quit the ui'),
    <Text key="b2"> </Text>,
    <Text key="note" color={theme.muted}>
      Messages and pause/skip/stop are cooperative: the runner picks them up at
      the next agent call. Quitting the ui does NOT stop the run.
    </Text>,
  ];
  const out: React.ReactNode[] = [];
  for (let i = 0; i < rows; i++) out.push(lines[i] ?? <Text key={`p${i}`}> </Text>);
  return <Box flexDirection="column">{out}</Box>;
}

function row(k: string, label: string) {
  return (
    <Text key={k}>
      {'  '}
      <Text color={theme.accent}>{k}</Text>
      <Text> {label}</Text>
    </Text>
  );
}
