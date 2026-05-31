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
  listTodoFiles,
  isInitialized,
  lastRunSummary,
} from '../protocol';
import { COMMANDS, runCapture, startRun, type Command } from '../actions';
import type { LogMode, Mode, RunState } from '../types';
import { theme } from '../theme';
import { Header } from './Header';
import { TaskList } from './TaskList';
import { RightPane } from './RightPane';
import { StatusBar } from './StatusBar';
import { MessageBar } from './MessageBar';
import { Help } from './Help';
import { Home } from './Home';
import { CommandPalette } from './CommandPalette';
import { OutputModal } from './OutputModal';

const EMPTY: RunState = {
  status: '', phase: '', taskIndex: 0, taskTotal: 0, taskName: '', iteration: 0,
  maxIterations: 0, cost: '', lastError: '', validationAttempt: 0, validationMax: 0,
  chromeEnabled: false, chromeAttempt: 0, chromeMax: 0, summaryLog: '', todoFile: '',
  planFile: '', activeLog: '',
};

type Overlay = 'none' | 'palette' | 'modal' | 'init';

function effectiveSelected(sel: number, count: number, active: number, firstOpen: number): number {
  if (sel > 0) return Math.min(sel, Math.max(count, 1));
  if (active > 0) return active;
  if (firstOpen > 0) return firstOpen;
  return 1;
}

export function App({ inputActive = true }: { inputActive?: boolean }) {
  const { exit } = useApp();
  const { stdout } = useStdout();
  const snap = useRun();

  const [selected, setSelected] = useState(0); // task (live)
  const [homeSel, setHomeSel] = useState(1); // todo (home)
  const [logMode, setLogMode] = useState<LogMode>('summary');
  const [mode, setMode] = useState<Mode>('nav'); // live message compose
  const [buffer, setBuffer] = useState('');
  const [showHelp, setShowHelp] = useState(false);
  const [lastAction, setLastAction] = useState('ready');
  const [noteStatus, setNoteStatus] = useState('');
  const [overlay, setOverlay] = useState<Overlay>('none');
  const [palSel, setPalSel] = useState(0);
  const [modal, setModal] = useState({ title: '', lines: [] as string[], offset: 0, running: false });
  const [initBuf, setInitBuf] = useState('');
  const [, forceTick] = useState(0);

  useEffect(() => {
    const onResize = () => forceTick((n) => n + 1);
    stdout?.on('resize', onResize);
    return () => { stdout?.off('resize', onResize); };
  }, [stdout]);

  const state = snap.state ?? EMPTY;
  const isLive = snap.live;
  const tasks = snap.tasks;
  const firstOpen = tasks.findIndex((t) => t.box === ' ') + 1;
  const sel = effectiveSelected(selected, tasks.length, state.taskIndex, firstOpen);
  const todos = isLive ? [] : listTodoFiles();
  const initialized = isInitialized();

  const cols = Math.max(stdout?.columns ?? 80, 50);
  const rows = Math.max(stdout?.rows ?? 24, 14);
  const leftWidth = Math.min(Math.floor(cols / 2), 48);
  const rightWidth = Math.max(cols - leftWidth - 5, 10);
  const bodyRows = Math.max(rows - 11, 3);

  // Dispatch a palette/home command.
  function runCommand(cmd: Command) {
    if (cmd.kind === 'start') {
      const r = startRun();
      setLastAction(r.msg);
      setOverlay('none');
      return;
    }
    if (cmd.kind === 'stop') {
      if (isLive) { controlSend('stop'); setLastAction('sent: stop'); }
      else { runCapture(['stop'], () => {}); setLastAction('stop requested'); }
      setOverlay('none');
      return;
    }
    if (cmd.kind === 'init') {
      setInitBuf('');
      setOverlay('init');
      return;
    }
    // capture
    setModal({ title: `nightshift ${cmd.id}`, lines: [], offset: 0, running: true });
    setOverlay('modal');
    runCapture([cmd.id], (out) => {
      setModal({ title: `nightshift ${cmd.id}`, lines: out.split('\n'), offset: 0, running: false });
    });
  }

  function submitInit() {
    const name = initBuf.trim();
    setOverlay('modal');
    setModal({ title: `nightshift init ${name}`, lines: [], offset: 0, running: true });
    runCapture(['init', name], (out) => {
      setModal({ title: `nightshift init ${name}`, lines: out.split('\n'), offset: 0, running: false });
    });
  }

  useInput((input, key) => {
    // ---- overlays first ----
    if (overlay === 'modal') {
      const max = Math.max(0, modal.lines.length - bodyRows);
      if (key.escape || input === 'q') setOverlay('none');
      else if (input === 'j' || key.downArrow) setModal((m) => ({ ...m, offset: Math.min(m.offset + 1, max) }));
      else if (input === 'k' || key.upArrow) setModal((m) => ({ ...m, offset: Math.max(m.offset - 1, 0) }));
      else if (input === 'g') setModal((m) => ({ ...m, offset: 0 }));
      else if (input === 'G') setModal((m) => ({ ...m, offset: max }));
      return;
    }
    if (overlay === 'init') {
      if (key.return) { submitInit(); return; }
      if (key.escape) { setOverlay('none'); setInitBuf(''); setLastAction('init cancelled'); return; }
      if (key.backspace || key.delete) { setInitBuf((b) => b.slice(0, -1)); return; }
      if (input && !key.ctrl && !key.meta) setInitBuf((b) => b + input);
      return;
    }
    if (overlay === 'palette') {
      if (key.escape || input === 'q') { setOverlay('none'); return; }
      if (input === 'j' || key.downArrow) setPalSel((p) => Math.min(p + 1, COMMANDS.length - 1));
      else if (input === 'k' || key.upArrow) setPalSel((p) => Math.max(p - 1, 0));
      else if (key.return) runCommand(COMMANDS[palSel]);
      return;
    }
    if (showHelp) {
      if (input === '?' || key.escape || input === 'q') setShowHelp(false);
      return;
    }
    // ---- live message compose ----
    if (isLive && mode === 'input') {
      if (key.return) {
        if (controlNote(buffer)) { setNoteStatus('queued ✓'); setLastAction('message sent to agent'); }
        setBuffer(''); setMode('nav'); return;
      }
      if (key.escape) { setBuffer(''); setMode('nav'); setLastAction('message cancelled'); return; }
      if (key.backspace || key.delete) { setBuffer((b) => b.slice(0, -1)); return; }
      if (input && !key.ctrl && !key.meta) setBuffer((b) => b + input);
      return;
    }
    // ---- global nav ----
    if (input === ':') { setPalSel(0); setOverlay('palette'); return; }
    if (input === '?') { setShowHelp(true); return; }
    if (input === 'q') { exit(); return; }

    if (isLive) {
      if (input === 'i' || input === '/') { setMode('input'); setBuffer(''); setLastAction('typing message…'); }
      else if (input === 'p') { controlSend('pause'); setLastAction('sent: pause'); }
      else if (input === 'r') { controlSend('resume'); setLastAction('sent: resume'); }
      else if (input === 'n') { controlSend('skip'); setLastAction('sent: skip'); }
      else if (input === 's' || input === 'x') { controlSend('stop'); setLastAction('sent: stop'); }
      else if (input === 'K') setLastAction(forceKillRunner());
      else if (input === 't') setLogMode((m) => (m === 'summary' ? 'events' : 'summary'));
      else if (input === 'j' || key.downArrow) setSelected(Math.min(sel + 1, tasks.length || 1));
      else if (input === 'k' || key.upArrow) setSelected(Math.max(sel - 1, 1));
      else if (input === 'g') setSelected(1);
      else if (input === 'G') setSelected(tasks.length || 1);
    } else {
      // home
      if (key.return) runCommand(COMMANDS[0]); // start
      else if (input === 'n') runCommand({ id: 'init', label: 'init', desc: '', kind: 'init' });
      else if (input === 'v') runCommand({ id: 'review', label: 'review', desc: '', kind: 'capture' });
      else if (input === 'R') runCommand({ id: 'resume', label: 'resume', desc: '', kind: 'capture' });
      else if (input === 'j' || key.downArrow) setHomeSel((s) => Math.min(s + 1, todos.length || 1));
      else if (input === 'k' || key.upArrow) setHomeSel((s) => Math.max(s - 1, 1));
    }
  }, { isActive: inputActive });

  // ---- live right pane: commit preview vs log ----
  const previewCache = useRef<{ idx: number; sha: string; lines: string[] }>({ idx: -1, sha: '', lines: [] });
  let rightLabel = `LOG (${logMode})`;
  let rightLines: string[] = [];
  let showCommit = false;
  const selTask = tasks[sel - 1];
  if (isLive && !showHelp && logMode === 'summary' && selTask && selTask.box === 'x' && selTask.num) {
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
  if (isLive && !showCommit) {
    rightLines = tailLines(logMode === 'events' ? snap.eventsFile : snap.summaryLog, bodyRows);
  }

  const taskIdx = state.taskIndex > 0 ? state.taskIndex : sel;
  const taskTotal = state.taskTotal > 0 ? state.taskTotal : tasks.length;
  const displayStatus = isLive ? state.status || 'running' : 'idle';

  const subline = snap.stale
    ? <Text color={theme.warn}> (state stale — runner not updating)</Text>
    : !isLive
      ? <Text color={theme.muted}> {lastRunSummary(snap.state) || 'no active run — pick a todo and press Enter to start'}</Text>
      : <Text> </Text>;

  const sep: React.ReactNode[] = [];
  for (let i = 0; i < bodyRows + 1; i++) sep.push(<Text key={i} color={theme.muted}>│</Text>);

  function liveBody() {
    return (
      <Box flexDirection="row">
        <Box flexDirection="column" width={leftWidth}>
          <Text bold>TASKS</Text>
          <TaskList tasks={tasks} selected={sel} activeIdx={state.taskIndex} width={leftWidth} rows={bodyRows} />
        </Box>
        <Box flexDirection="column" marginX={1}>{sep}</Box>
        <Box flexDirection="column" width={rightWidth}>
          <RightPane label={rightLabel} lines={rightLines} width={rightWidth} rows={bodyRows} />
        </Box>
      </Box>
    );
  }

  let body: React.ReactNode;
  if (showHelp) body = <Help rows={bodyRows + 1} />;
  else if (overlay === 'palette') body = <CommandPalette commands={COMMANDS} selected={palSel} rows={bodyRows + 1} />;
  else if (overlay === 'modal') body = <OutputModal title={modal.title} lines={modal.lines} offset={modal.offset} rows={bodyRows} width={cols - 2} running={modal.running} />;
  else if (overlay === 'init') {
    body = (
      <Box flexDirection="column">
        <Text bold color={theme.accent}>Init a new project</Text>
        <Text> </Text>
        <Box>
          <Text color={theme.muted}>  feature name: </Text>
          <Text>{initBuf}</Text><Text inverse> </Text>
        </Box>
        <Text> </Text>
        <Text color={theme.muted}>  creates a todo + runner in this dir. ⏎ create · Esc cancel</Text>
      </Box>
    );
  } else if (isLive) body = liveBody();
  else body = <Home todos={todos} selected={homeSel} initialized={initialized} leftWidth={leftWidth} rows={bodyRows - 1} />;

  // bottom hint line
  let hint: React.ReactNode;
  if (isLive && mode === 'input') hint = <MessageBar mode="input" buffer={buffer} noteStatus={noteStatus} />;
  else if (overlay !== 'none' || showHelp) hint = <Text color={theme.muted}> q/Esc back · : commands</Text>;
  else if (isLive) hint = <MessageBar mode="nav" buffer="" noteStatus={noteStatus} />;
  else hint = <Text> <Text color={theme.accent}>⏎</Text><Text color={theme.muted}> start  </Text><Text color={theme.accent}>n</Text><Text color={theme.muted}> init  </Text><Text color={theme.accent}>v</Text><Text color={theme.muted}> review  </Text><Text color={theme.accent}>:</Text><Text color={theme.muted}> commands  </Text><Text color={theme.accent}>?</Text><Text color={theme.muted}> help  </Text><Text color={theme.accent}>q</Text><Text color={theme.muted}> quit</Text></Text>;

  return (
    <Box flexDirection="column" borderStyle="round" borderColor={theme.muted} paddingX={1}>
      <Header state={state} taskIdx={taskIdx} taskTotal={taskTotal} statusOverride={displayStatus} />
      {subline}
      {body}
      <Box flexDirection="column">
        {isLive && overlay === 'none' && !showHelp
          ? <StatusBar state={state} lastAction={lastAction} />
          : <Text color={theme.muted}> {lastAction}</Text>}
      </Box>
      {hint}
    </Box>
  );
}
