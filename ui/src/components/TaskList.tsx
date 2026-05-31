import React from 'react';
import { Box, Text } from 'ink';
import type { Task } from '../types';
import { theme } from '../theme';

// Left pane. `selected` is 1-based; `activeIdx` is the runner's current task
// (1-based, marked [~]). Window scrolls to keep the selection visible.
export function TaskList({
  tasks,
  selected,
  activeIdx,
  width,
  rows,
}: {
  tasks: Task[];
  selected: number;
  activeIdx: number;
  width: number;
  rows: number;
}) {
  let start = 1;
  if (selected > rows) start = selected - rows + 1;
  const out: React.ReactNode[] = [];
  for (let i = 0; i < rows; i++) {
    const pos = start + i;
    if (pos > tasks.length) {
      out.push(<Text key={i}> </Text>);
      continue;
    }
    const t = tasks[pos - 1];
    const isSel = pos === selected;
    const isActive = pos === activeIdx;
    const done = t.box === 'x';
    const box = done ? '[x]' : isActive ? '[~]' : '[ ]';
    const marker = isSel ? '› ' : '  ';
    // fit() already truncates+pads to a fixed width; marker(2) + label keeps the
    // row strictly under the column width so ink never adds its own ellipsis.
    const label = fit(`${box} ${t.title}`, Math.max(width - 3, 1));
    let color: string = theme.muted;
    if (done) color = theme.ok;
    else if (isActive) color = theme.warn;
    out.push(
      <Text key={i}>
        <Text color={theme.accent}>{marker}</Text>
        <Text color={isSel ? undefined : color} inverse={isSel} bold={isActive}>
          {label}
        </Text>
      </Text>,
    );
  }
  return <Box flexDirection="column">{out}</Box>;
}

function fit(s: string, width: number): string {
  if (width <= 0) return '';
  if (s.length > width) return s.slice(0, width);
  return s.padEnd(width, ' ');
}
