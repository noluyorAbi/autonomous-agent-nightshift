import { Box, Text } from 'ink';
import { theme } from '../theme';
import type { TodoFileInfo } from '../protocol';

// Launcher screen shown when no run is live (and on bare `nightshift`).
export function Home({
  todos,
  selected,
  initialized,
  leftWidth,
  rows,
}: {
  todos: TodoFileInfo[];
  selected: number; // 1-based index into todos
  initialized: boolean;
  leftWidth: number;
  rows: number;
}) {
  const left: React.ReactNode[] = [<Text key="h" bold>TODO FILES</Text>];
  if (todos.length === 0) {
    left.push(
      <Text key="none" color={theme.muted}>
        {'  '}none found — `init` to create one
      </Text>,
    );
  }
  for (let i = 0; i < todos.length; i++) {
    const t = todos[i];
    const isSel = i + 1 === selected;
    const tag = t.bulletproof ? 'BP' : `${t.done}/${t.total}`;
    const complete = t.total > 0 && t.done === t.total;
    const label = `${t.file}  (${tag})`;
    left.push(
      <Text key={t.file} wrap="truncate">
        <Text color={theme.accent}>{isSel ? '› ' : '  '}</Text>
        <Text inverse={isSel} color={isSel ? undefined : complete ? theme.muted : theme.ok}>
          {label.slice(0, Math.max(leftWidth - 3, 1))}
        </Text>
      </Text>,
    );
  }

  const startLabel = initialized ? '⏎  Start run' : '⏎  Init project first';
  const actions: Array<[string, string]> = [
    [startLabel, ''],
    ['n', 'Init new project'],
    ['v', 'Review last run'],
    ['R', 'Resume after a stop'],
    [':', 'Command palette (all commands)'],
    ['q', 'Quit'],
  ];
  const right: React.ReactNode[] = [<Text key="h" bold>ACTIONS</Text>];
  for (const [k, label] of actions) {
    right.push(
      <Text key={k + label}>
        {'  '}
        <Text color={theme.accent}>{k}</Text>
        {label ? <Text color={theme.muted}> {label}</Text> : null}
      </Text>,
    );
  }

  // pad columns to the body height
  const pad = (arr: React.ReactNode[]) => {
    const o = [...arr];
    while (o.length < rows + 1) o.push(<Text key={`p${o.length}`}> </Text>);
    return o.slice(0, rows + 1);
  };

  return (
    <Box flexDirection="row">
      <Box flexDirection="column" width={leftWidth}>{pad(left)}</Box>
      <Box flexDirection="column" marginX={1}>
        {Array.from({ length: rows + 1 }, (_, i) => (
          <Text key={i} color={theme.muted}>
            │
          </Text>
        ))}
      </Box>
      <Box flexDirection="column">{pad(right)}</Box>
    </Box>
  );
}
