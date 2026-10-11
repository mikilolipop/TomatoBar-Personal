/** Cross-language contract test against the real macOS domain, using temporary synthetic data. */
import { runnerImport } from 'vite';
import { mkdtemp, writeFile, readFile, rm, copyFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { execFileSync } from 'node:child_process';
import assert from 'node:assert/strict';
const root = resolve(import.meta.dirname, '..');
const { module: codec } = await runnerImport(join(root, 'src/core/sessionsCodec.ts'), { configFile: false });
const { module: types } = await runnerImport(join(root, 'src/types.ts'), { configFile: false });
const { module: machine } = await runnerImport(join(root, 'src/core/stateMachine.ts'), { configFile: false });
const dir = await mkdtemp(join(tmpdir(), 'tomatobar-interop-'));
try {
  const now = new Date('2026-10-11T00:00:00Z');
  let state = machine.FocusStateMachine.addProject(types.createDefaultFocusState(), '合成项目', ['学习'], now);
  state = machine.FocusStateMachine.addTodo(state, '合成子任务', [], state.projects[0].id, now);
  state = machine.FocusStateMachine.startWork(state, '', [], 60, state.todos[0].id, now);
  state = machine.FocusStateMachine.tick(state, new Date(now.getTime() + 60000)).nextState;
  state.categoryStyles = { start: 'book|3' };
  await writeFile(join(dir, 'input.json'), codec.encodeSessions(state));
  await copyFile(resolve(root, '../TomatoBar/State.swift'), join(dir, 'State.swift'));
  await copyFile(resolve(root, '../TomatoBar/Analytics.swift'), join(dir, 'Analytics.swift'));
  await writeFile(join(dir, 'main.swift'), `import Foundation
let args = CommandLine.arguments
let state = try JSONDecoder().decode(FocusState.self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
precondition(state.records.count == 1)
precondition(state.records[0].seconds == 60)
precondition(state.records[0].startedAt.timeIntervalSince1970 == 1791676800)
precondition(state.records[0].todoID == state.todos[0].id)
precondition(state.records[0].projectID == state.projects[0].id)
precondition(state.records[0].tags == ["学习"])
precondition(state.categoryStyles["start"] == "book|3")
try JSONEncoder().encode(state).write(to: URL(fileURLWithPath: args[2]))
print("PASS: actual Swift decoder and encoder accepted synthetic desktop state")
`);
  execFileSync('xcrun', ['swiftc', join(dir, 'State.swift'), join(dir, 'Analytics.swift'), join(dir, 'main.swift'), '-o', join(dir, 'interop')], { stdio: 'inherit' });
  execFileSync(join(dir, 'interop'), [join(dir, 'input.json'), join(dir, 'output.json')], { stdio: 'inherit' });
  const returned = codec.decodeSessions(await readFile(join(dir, 'output.json'), 'utf8'));
  assert.equal(types.recordSeconds(returned.records[0]), 60);
  assert.equal(returned.records[0].startedAt, state.records[0].startedAt);
  assert.equal(returned.records[0].todoID.toLowerCase(), state.records[0].todoID.toLowerCase());
  assert.equal(returned.categoryStyles.start, 'book|3');
  console.log('PASS: TypeScript accepted the actual Swift output');
} finally { await rm(dir, { recursive: true, force: true }); }
