import { Settings } from "lucide-react";
export function WindowHeader({
  tab,
  onTab,
  onSettings,
}: {
  tab: "overview" | "history";
  onTab: (tab: "overview" | "history") => void;
  onSettings: () => void;
}) {
  return (
    <header className="garden-window-topbar">
      <span className="brand-logo-text">🍅 TomatoBar</span>
      <nav className="garden-nav-tabs" aria-label="主导航">
        <button
          className={`nav-link ${tab === "overview" ? "active" : ""}`}
          aria-current={tab === "overview" ? "page" : undefined}
          onClick={() => onTab("overview")}
        >
          概览
        </button>
        <button
          className={`nav-link ${tab === "history" ? "active" : ""}`}
          aria-current={tab === "history" ? "page" : undefined}
          onClick={() => onTab("history")}
        >
          历史
        </button>
      </nav>
      <div className="garden-top-right">
        <span className="poetic-motto">让专注，慢慢生长</span>
        <button
          className="garden-icon-btn"
          onClick={onSettings}
          aria-label="偏好设置"
          title="偏好设置"
        >
          <Settings size={17} />
        </button>
      </div>
    </header>
  );
}
