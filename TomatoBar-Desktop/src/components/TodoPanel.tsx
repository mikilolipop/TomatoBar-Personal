import { useState } from "react";
import type { FocusState, FocusTodo } from "../types";
import { parseInputWithTags, recordSeconds } from "../types";
import { canStartWork } from "../core/stateMachine";
import { formatDurationChinese } from "../core/analytics";
import {
  Circle,
  CheckCircle2,
  Play,
  X,
  Plus,
  Folder,
  ChevronDown,
  FolderPlus,
  Trash2,
} from "lucide-react";
import { Modal } from "./Modal";

interface TodoPanelProps {
  state: FocusState;
  onAddTodo: (title: string, tags: string[], projectID?: string | null) => void;
  onToggleTodo: (id: string) => void;
  onDeleteTodo: (id: string) => void;
  onSelectTodoForFocus: (todo: FocusTodo) => void;
  onAddProject: (name: string, tags: string[]) => void;
  onDeleteProject: (id: string) => void;
}
function TodoRow({
  todo,
  state,
  onToggleTodo,
  onDeleteTodo,
  onSelectTodoForFocus,
}: Pick<
  TodoPanelProps,
  "state" | "onToggleTodo" | "onDeleteTodo" | "onSelectTodoForFocus"
> & { todo: FocusTodo }) {
  return (
    <div
      className={`subtask-item ${todo.id === state.currentTodoID ? "active" : ""}`}
    >
      <button
        className="todo-circle-btn"
        aria-label={`${todo.isCompleted ? "恢复" : "完成"}${todo.title}`}
        onClick={() => onToggleTodo(todo.id)}
      >
        {todo.isCompleted ? <CheckCircle2 size={16} /> : <Circle size={16} />}
      </button>
      <span
        className={`subtask-title ${todo.isCompleted ? "line-through" : ""}`}
      >
        {todo.title}
      </span>
      {todo.tags[0] && <span className="todo-subtag">#{todo.tags[0]}</span>}
      <button
        className="btn-play-todo"
        disabled={!canStartWork(state) || todo.isCompleted}
        onClick={() => onSelectTodoForFocus(todo)}
        aria-label={`选择${todo.title}`}
        title="选择为当前任务"
      >
        <Play size={12} fill="currentColor" />
      </button>
      <button
        className="btn-delete-todo"
        onClick={() => onDeleteTodo(todo.id)}
        aria-label={`删除待办${todo.title}`}
        title="删除待办"
      >
        <X size={12} />
      </button>
    </div>
  );
}
export function TodoPanel(props: TodoPanelProps) {
  const { state, onAddTodo, onAddProject, onDeleteProject } = props;
  const [input, setInput] = useState("");
  const [projectID, setProjectID] = useState("");
  const [collapsed, setCollapsed] = useState<Set<string>>(new Set());
  const [showProject, setShowProject] = useState(false);
  const [projectName, setProjectName] = useState("");
  const [projectTags, setProjectTags] = useState("");
  return (
    <section className="garden-card todos-card">
      <div className="todos-card-top">
        <div className="todos-title-row">
          <span className="card-title">待办</span>
          <span className="uncompleted-count">
            {state.todos.filter((t) => !t.isCompleted).length} 项未完成
          </span>
        </div>
        <button
          className="btn-new-project"
          onClick={() => setShowProject(true)}
        >
          <FolderPlus size={13} />
          新建大任务
        </button>
      </div>
      <label className="todo-project-picker">
        添加到
        <select
          className="garden-input"
          aria-label="待办所属大任务"
          value={projectID}
          onChange={(e) => setProjectID(e.target.value)}
        >
          <option value="">独立待办</option>
          {state.projects
            .filter((p) => !p.isArchived)
            .map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
        </select>
      </label>
      <form
        className="add-todo-inline-form"
        onSubmit={(e) => {
          e.preventDefault();
          if (!input.trim()) return;
          const parsed = parseInputWithTags(input);
          onAddTodo(parsed.title, parsed.tags, projectID || null);
          setInput("");
        }}
      >
        <input
          className="garden-input"
          aria-label="添加待办"
          placeholder="添加待办，例如：阅读章节 #学习"
          value={input}
          onChange={(e) => setInput(e.target.value)}
        />
        <button
          type="submit"
          className="btn-add-todo"
          aria-label="确认添加待办"
          disabled={!input.trim()}
        >
          <Plus size={16} />
        </button>
      </form>
      <div className="todos-tree-scroll">
        {state.projects.map((project) => {
          const todos = state.todos.filter((t) => t.projectID === project.id);
          const seconds = state.records
            .filter((r) => r.projectID === project.id)
            .reduce((sum, r) => sum + recordSeconds(r), 0);
          return (
            <div key={project.id} className="project-group">
              <div className="project-folder-header">
                <button
                  className="proj-collapse-arrow"
                  aria-label={`展开或收起${project.name}`}
                  aria-expanded={!collapsed.has(project.id)}
                  onClick={() =>
                    setCollapsed((old) => {
                      const next = new Set(old);
                      if (next.has(project.id)) next.delete(project.id);
                      else next.add(project.id);
                      return next;
                    })
                  }
                >
                  <ChevronDown
                    size={14}
                    style={{
                      transform: collapsed.has(project.id)
                        ? "rotate(-90deg)"
                        : undefined,
                    }}
                  />
                </button>
                <Folder size={15} />
                <span className="proj-title">{project.name}</span>
                <span className="proj-progress-pill">
                  {todos.filter((t) => t.isCompleted).length}/{todos.length}
                </span>
                {seconds > 0 && (
                  <span className="proj-time-pill">
                    {formatDurationChinese(seconds)}
                  </span>
                )}
                <button
                  className="proj-more-btn"
                  aria-label={`删除大任务${project.name}`}
                  onClick={() => {
                    if (
                      window.confirm(
                        `删除大任务「${project.name}」？子任务会保留为独立待办，历史记录保留。`,
                      )
                    ) {
                      onDeleteProject(project.id);
                      if (projectID === project.id) setProjectID("");
                    }
                  }}
                >
                  <Trash2 size={14} />
                </button>
              </div>
              {!collapsed.has(project.id) && (
                <div className="project-subtasks-list">
                  {todos.length ? (
                    todos.map((todo) => (
                      <TodoRow key={todo.id} todo={todo} {...props} />
                    ))
                  ) : (
                    <div className="empty-subtasks">
                      暂无子任务。在“添加到”中选择此大任务后添加。
                    </div>
                  )}
                </div>
              )}
            </div>
          );
        })}
        {state.todos
          .filter(
            (t) =>
              !t.projectID || !state.projects.some((p) => p.id === t.projectID),
          )
          .map((todo) => (
            <TodoRow key={todo.id} todo={todo} {...props} />
          ))}
        {!state.todos.length && !state.projects.length && (
          <p className="empty-hint">添加一项待办，选择后开始专注。</p>
        )}
      </div>
      {showProject && (
        <Modal title="新建大任务" onClose={() => setShowProject(false)}>
          <div className="garden-dialog-card">
            <h3 className="dialog-title">新建大任务</h3>
            <form
              onSubmit={(e) => {
                e.preventDefault();
                if (!projectName.trim()) return;
                onAddProject(
                  projectName,
                  projectTags.split(/[,，\s]+/).filter(Boolean),
                );
                setProjectName("");
                setProjectTags("");
                setShowProject(false);
              }}
            >
              <div className="dialog-field">
                <label htmlFor="project-name">大任务名称</label>
                <input
                  id="project-name"
                  className="garden-input"
                  value={projectName}
                  onChange={(e) => setProjectName(e.target.value)}
                  autoFocus
                />
              </div>
              <div className="dialog-field">
                <label htmlFor="project-tags">默认标签（子任务自动继承）</label>
                <input
                  id="project-tags"
                  className="garden-input"
                  value={projectTags}
                  onChange={(e) => setProjectTags(e.target.value)}
                  placeholder="例如：学习"
                />
              </div>
              <div className="dialog-actions">
                <button
                  type="button"
                  className="garden-btn-secondary"
                  onClick={() => setShowProject(false)}
                >
                  取消
                </button>
                <button
                  className="garden-btn-primary"
                  disabled={!projectName.trim()}
                >
                  创建
                </button>
              </div>
            </form>
          </div>
        </Modal>
      )}
    </section>
  );
}
