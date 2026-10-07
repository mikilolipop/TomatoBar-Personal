import React, { useState } from 'react';
import { parseInputWithTags } from '../types';
import { Tag } from 'lucide-react';

interface TaskInputProps {
  currentName: string;
  currentTags: string[];
  knownTags: string[];
  onCommit: (name: string, tags: string[]) => void;
  disabled?: boolean;
}

export const TaskInput: React.FC<TaskInputProps> = ({
  currentName,
  currentTags,
  knownTags,
  onCommit,
  disabled = false,
}) => {
  const [rawText, setRawText] = useState(
    currentName ? (currentTags.length > 0 ? `${currentName} #${currentTags.join(' #')}` : currentName) : ''
  );
  const [selectedTags, setSelectedTags] = useState<string[]>(currentTags);

  const handleTextChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const text = e.target.value;
    setRawText(text);
    const { title, tags } = parseInputWithTags(text);
    // Combine typed tags with already selected pills
    const allTags = Array.from(new Set([...tags, ...selectedTags]));
    onCommit(title, allTags);
  };

  const handleToggleTag = (tag: string) => {
    if (disabled) return;
    const nextTags = selectedTags.includes(tag)
      ? selectedTags.filter((t) => t !== tag)
      : [...selectedTags, tag];
    setSelectedTags(nextTags);
    const { title } = parseInputWithTags(rawText);
    onCommit(title, nextTags);
  };

  return (
    <div className="task-input-container">
      <div className="input-row">
        <input
          type="text"
          className="task-text-input"
          placeholder="填写专注任务，支持空格加 #标签（例如：设计方案 #工作）"
          value={rawText}
          onChange={handleTextChange}
          disabled={disabled}
        />
      </div>

      {knownTags.length > 0 && (
        <div className="quick-tags-row">
          <span className="quick-tags-label">
            <Tag size={12} /> 快捷标签:
          </span>
          <div className="quick-tags-list">
            {knownTags.map((tag) => {
              const active = selectedTags.includes(tag);
              return (
                <button
                  key={tag}
                  type="button"
                  className={`tag-chip ${active ? 'tag-chip-active' : ''}`}
                  onClick={() => handleToggleTag(tag)}
                  disabled={disabled}
                >
                  {tag}
                </button>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
};
