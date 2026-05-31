import React, { useEffect, useRef, useState } from 'react';
import { Box, Text, useApp, useInput, useStdout } from 'ink';
import { useRun } from '../hooks';
import {
  controlSend,
  controlNote,
  forceKillRunner,
  findTaskCommit,
  buildCommitPreview,
  tailLines,
} from '../protocol';
import type { LogMode, Mode } from '../types';
import { theme } from '../theme';
import { Header } from './Header';
import { TaskList } from './TaskList';
import { RightPane } from './RightPane';
import { StatusBar } from './StatusBar';
import { MessageBar } from './MessageBar';
import { Help } from './Help';

const EMPTY = {
  status: 'unknown',
  phase: '',
  taskIndex: 0,
  taskTotal: 0,
  taskName: '',
  iteration: 0,
  maxIterations: 0,
  cost: '',
  lastError: '',
  validationAttempt: 0,
  validationMax: 0,
  chromeEnabled: false,
  chromeAttempt: 0,
  chromeMax: 0,
  summaryLog: '',
  todoFile: '',
  planFile: '',
  activeLog: '',
};

function effectiveSelected(
  selected: number,
  taskCount: number,
  activeIdx: number,
  firstOpen: number,
): number {
  if (selected > 0) return Math.min(selected, Math.max(taskCount, 1));
  if (activeIdx > 0) return activeIdx;
  if (firstOpen > 0) return firstOpen;
  return 1;
}

export function App({ inputActive = true }: { inputActive?: boolean }) {
  const { exit } = useApp();
  const { stdout } = useStdout();
  const snap = useRun();
  const [selected, setSelected] = useState(0); // 0 = auto
  const [logMode, setLogMode] = useState<LogMode>('summary');
  const [mode, setMode] = useState<Mode>('nav');
  const [buffer, setBuffer] = useState('');
  const [showHelp, setShowHelp] = useState(false);
  const [lastAction, setLastAction] = useState('ready');
  const [noteStatus, setNoteStatus] = useState('');
  const [, forceTick] = useState(0);

  // Re-render on terminal resize.
  useEffect(() => {
    const onResize = () => forceTick((n) => n + 1);
    stdout?.on('resize', onResize);
    return () => {
      stdout?.off('resize', onResize);
    };
  }, [stdout]);

  const state = snap.state ?? EMPTY;
  const tasks = snap.tasks;
  const firstOpen = tasks.findIndex((t) => t.box === ' ') + 1;
  const sel = effectiveSelected(selected, tasks.length, state.taskIndex, firstOpen);

  useInput(
    (input, key) => {
      if (mode === 'input') {
        if (key.return) {
          if (controlNote(buffer)) {
            setNoteStatus('queued ✓');
            setLastAction('message sent to agent');
          }
          setBuffer('');
          setMode('nav');
          return;
        }
        if (key.escape) {
          setBuffer('');
          setMode('nav');
          setLastAction('message cancelled');
          return;
        }
        if (key.backspace || key.delete) {
          setBuffer((b) => b.slice(0, -1));
          return;
        }
        if (input && !key.ctrl && !key.meta) setBuffer((b) => b + input);
        return;
      }
      // nav mode
      if (input === 'q') {
        exit();
        return;
      }
      if (input === 'i' || input === '/') {
        setMode('input');
        setBuffer('');
        setLastAction('typing message…');
      } else if (input === 'p') {
        controlSend('pause');
        setLastAction('sent: pause');
      } else if (input === 'r') {
        controlSend('resume');
        setLastAction('sent: resume');
      } else if (input === 'n') {
        controlSend('skip');
        setLastAction('sent: skip');
      } else if (input === 's' || input === 'x') {
        controlSend('stop');
        setLastAction('sent: stop');
      } else if (input === 'K') {
        setLastAction(forceKillRunner());
      } else if (input === '?') {
        setShowHelp((v) => !v);
      } else if (input === 't') {
        setLogMode((m) => (m === 'summary' ? 'events' : 'summary'));
      } else if (input === 'j' || key.downArrow) {
        setSelected(Math.min(sel + 1, tasks.length || 1));
      } else if (input === 'k' || key.upArrow) {
        setSelected(Math.max(sel - 1, 1));
      } else if (input === 'g') {
        setSelected(1);
      } else if (input === 'G') {
        setSelected(tasks.length || 1);
      }
    },
    { isActive: inputActive },
  );

  // ---- layout ----
  const cols = Math.max(stdout?.columns ?? 80, 50);
  const rows = Math.max(stdout?.rows ?? 24, 14);
  const leftWidth = Math.min(Math.floor(cols / 2), 48);
  const rightWidth = Math.max(cols - leftWidth - 5, 10);
  const bodyRows = Math.max(rows - 11, 3);

  // ---- right pane: commit preview for a selected done task, else log tail ----
  const previewCache = useRef<{ idx: number; sha: string; lines: string[] }>({
    idx: -1,
    sha: '',
    lines: [],
  });
  let rightLabel = `LOG (${logMode})`;
  let rightLines: string[] = [];
  let showCommit = false;
  const selTask = tasks[sel - 1];
  if (!showHelp && logMode === 'summary' && selTask && selTask.box === 'x' && selTask.num) {
    if (previewCache.current.idx !== sel) {
      const sha = findTaskCommit(selTask.num);
      previewCache.current = { idx: sel, sha, lines: sha ? buildCommitPreview(sha) : [] };
    }
    if (previewCache.current.lines.length) {
      showCommit = true;
      rightLabel = `COMMIT ${previewCache.current.sha.slice(0, 7)}`;
      rightLines = previewCache.current.lines;
    }
  }
  if (!showCommit) {
    const file = logMode === 'events' ? snap.eventsFile : snap.summaryLog;
    rightLines = tailLines(file, bodyRows);
  }

  const taskIdx = state.taskIndex > 0 ? state.taskIndex : sel;
  const taskTotal = state.taskTotal > 0 ? state.taskTotal : tasks.length;

  const sep: React.ReactNode[] = [];
  for (let i = 0; i < bodyRows + 1; i++)
    sep.push(
      <Text key={i} color={theme.muted}>
        │
      </Text>,
    );

  return (
    <Box flexDirection="column" borderStyle="round" borderColor={theme.muted} paddingX={1}>
      <Header state={state} taskIdx={taskIdx} taskTotal={taskTotal} />
      {snap.stale ? (
        <Text color={theme.warn}> (state stale — runner not updating)</Text>
      ) : (
        <Text> </Text>
      )}
      {showHelp ? (
        <Help rows={bodyRows + 1} />
      ) : (
        <Box flexDirection="row">
          <Box flexDirection="column" width={leftWidth}>
            <Text bold>TASKS</Text>
            <TaskList
              tasks={tasks}
              selected={sel}
              activeIdx={state.taskIndex}
              width={leftWidth}
              rows={bodyRows}
            />
          </Box>
          <Box flexDirection="column" marginX={1}>
            {sep}
          </Box>
          <Box flexDirection="column" width={rightWidth}>
            <RightPane label={rightLabel} lines={rightLines} width={rightWidth} rows={bodyRows} />
          </Box>
        </Box>
      )}
      <Box marginTop={0} flexDirection="column">
        <StatusBar state={state} lastAction={lastAction} />
      </Box>
      <MessageBar mode={mode} buffer={buffer} noteStatus={noteStatus} />
    </Box>
  );
}
