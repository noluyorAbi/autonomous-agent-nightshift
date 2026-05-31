import React from 'react';
import { Box, Text } from 'ink';
import { theme } from '../theme';

// Generic right pane: a bold label and `rows` lines, each truncated to width.
// In Milestone 1 it shows either the log tail (summary/events) or a commit
// preview for a selected done task. Milestone 3 turns the label into tabs.
export function RightPane({
  label,
  lines,
  width,
  rows,
}: {
  label: string;
  lines: string[];
  width: number;
  rows: number;
}) {
  const body: React.ReactNode[] = [];
  for (let i = 0; i < rows; i++) {
    const line = lines[i] ?? '';
    body.push(
      <Text key={i} dimColor wrap="truncate">
        {line.slice(0, width)}
      </Text>,
    );
  }
  return (
    <Box flexDirection="column">
      <Text bold color={theme.accent}>
        {label}
      </Text>
      {body}
    </Box>
  );
}
