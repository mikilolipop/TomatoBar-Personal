import React, { useState } from 'react';
import type { FocusTodo } from '../types';
import { parseInputWithTags } from '../types';
import { CheckCircle2, Circle, Plus, Trash2, Play, CheckCheck } from 'lucide-react';

interface TodoListProps {
  todos: FocusTodo[];
  activeTodoID?: string | null;
  onAddTodo: (title: string, tags: string[]) => void;
  onToggleTodo: (id: string) => void;
  onDeleteTodo: (id: string) => void;
  onSelectTodoForFocus: (todo: FocusTodo) => void;
}

export const TodoList: React.FC<TodoListProps> = ({
  todos,
  activeTodoID,
  onAddTodo,
  onToggleTodo,
  onDeleteTodo,
  onSelectTodoForFocus,
}) => {
  const [newTitle, setNewTitle] = useState('');

  const handleAddSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTitle.trim()) return;
    const { title, tags } = parseInputWithTags(newTitle);
    onAddTodo(title, tags);
    setNewTitle('');
  };

  const activeTodos = todos.filter((t) => !t.isCompleted);
  const completedTodos = todos.filter((t) => t.isCompleted);

  return (
    <div className="todo-panel">
      <div className="todo-header">
        <h3 className="section-title">待办任务清单</h3>
        <span className="todo-stats">
          {completedTodos.length} / {todos.length} 已完成
        </span>
      </div>

      <form className="add-todo-form" onSubmit={handleAddSubmit}>
        <input
          type="text"
          className="todo-input"
          placeholder="添加新待办，支持空格加 #标签（按 Enter 确认）"
          value={newTitle}
          onChange={(e) => setNewTitle(e.target.value)}
        />
        <button type="submit" className="btn btn-primary btn-icon" disabled={!newTitle.trim()}>
          <Plus size={16} />
        </button>
      </form>

      <div className="todo-list-scroll">
        {activeTodos.length === 0 && completedTodos.length === 0 && (
          <div className="empty-state">暂无待办事项，输入上方即可添加</div>
        )}

        {activeTodos.map((todo) => {
          const isCurrent = todo.id === activeTodoID;
          return (
            <div key={todo.id} className={`todo-item ${isCurrent ? 'todo-item-active' : ''}`}>
              <button
                type="button"
                className="todo-check-btn"
                onClick={() => onToggleTodo(todo.id)}
                title="标记为完成"
              >
                <Circle size={17} className="check-icon-idle" />
              </button>

              <div className="todo-content">
                <span className="todo-title">{todo.title}</span>
                {todo.tags.length > 0 && (
                  <div className="todo-tags">
                    {todo.tags.map((t) => (
                      <span key={t} className="todo-tag-pill">
                        #{t}
                      </span>
                    ))}
                  </div>
                )}
              </div>

              <div className="todo-item-actions">
                <button
                  type="button"
                  className={`btn-icon-action ${isCurrent ? 'btn-active-focus' : ''}`}
                  onClick={() => onSelectTodoForFocus(todo)}
                  title={isCurrent ? '当前专注任务' : '以此任务开始专注'}
                >
                  <Play size={14} />
                </button>
                <button
                  type="button"
                  className="btn-icon-action btn-danger-action"
                  onClick={() => onDeleteTodo(todo.id)}
                  title="删除任务"
                >
                  <Trash2 size={14} />
                </button>
              </div>
            </div>
          );
        })}

        {completedTodos.length > 0 && (
          <div className="completed-group">
            <div className="completed-divider">
              <CheckCheck size={14} /> 已完成 ({completedTodos.length})
            </div>
            {completedTodos.map((todo) => (
              <div key={todo.id} className="todo-item todo-item-completed">
                <button
                  type="button"
                  className="todo-check-btn"
                  onClick={() => onToggleTodo(todo.id)}
                  title="恢复为未完成"
                >
                  <CheckCircle2 size={17} className="check-icon-done" />
                </button>

                <div className="todo-content">
                  <span className="todo-title line-through">{todo.title}</span>
                  {todo.tags.length > 0 && (
                    <div className="todo-tags">
                      {todo.tags.map((t) => (
                        <span key={t} className="todo-tag-pill">
                          #{t}
                        </span>
                      ))}
                    </div>
                  )}
                </div>

                <div className="todo-item-actions">
                  <button
                    type="button"
                    className="btn-icon-action btn-danger-action"
                    onClick={() => onDeleteTodo(todo.id)}
                    title="删除"
                  >
                    <Trash2 size={14} />
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};
