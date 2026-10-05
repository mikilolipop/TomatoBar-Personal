(function () {
  "use strict";

  // 1. Screenshot Preview Dialog Modal
  var dialog = document.getElementById("preview-dialog");
  document.querySelectorAll("[data-preview]").forEach(function (button) {
    button.addEventListener("click", function () {
      if (dialog && typeof dialog.showModal === "function") {
        dialog.showModal();
        document.body.classList.add("preview-open");
      }
    });
  });

  var closeBtn = document.getElementById("close-preview");
  if (closeBtn) {
    closeBtn.addEventListener("click", function () { dialog.close(); });
  }

  if (dialog) {
    dialog.addEventListener("close", function () {
      document.body.classList.remove("preview-open");
    });
    dialog.addEventListener("click", function (event) {
      if (event.target !== dialog) return;
      var bounds = dialog.getBoundingClientRect();
      if (event.clientX < bounds.left || event.clientX > bounds.right ||
          event.clientY < bounds.top || event.clientY > bounds.bottom) {
        dialog.close();
      }
    });
  }

  // 2. Installation Guide Toggle & Hash Scroll
  var installDetails = document.getElementById("install-details");
  if (installDetails) {
    function updateInstallHint() {
      var hint = installDetails.querySelector(".summary-hint");
      if (hint) {
        hint.textContent = installDetails.open ? "收起安装指南" : "展开安装指南";
      }
    }
    installDetails.addEventListener("toggle", updateInstallHint);

    function revealInstall() {
      if (window.location.hash === "#install") {
        installDetails.open = true;
        updateInstallHint();
      }
    }
    document.querySelectorAll('a[href="#install"]').forEach(function (link) {
      link.addEventListener("click", function () {
        installDetails.open = true;
        updateInstallHint();
      });
    });
    window.addEventListener("hashchange", revealInstall);
    revealInstall();
  }

  // 3. One-click Copy Terminal Command
  var copyBtn = document.getElementById("copy-command");
  if (copyBtn) {
    copyBtn.addEventListener("click", async function () {
      var status = document.getElementById("copy-feedback");
      var cmdElem = document.getElementById("install-command");
      if (!cmdElem) return;
      try {
        await navigator.clipboard.writeText(cmdElem.textContent.trim());
        if (status) status.textContent = "已复制命令！请在 Mac 终端中粘贴执行。";
        copyBtn.textContent = "已复制 ✓";
        setTimeout(function () { copyBtn.textContent = "复制命令"; }, 2500);
      } catch (_) {
        if (status) status.textContent = "未能自动复制，请手动选中上方命令复制。";
      }
    });
  }

  // 4. Interactive Tag Extraction Playground
  var playgroundInput = document.getElementById("playground-input");
  var titlePreview = document.getElementById("playground-title-preview");
  var tagsPreview = document.getElementById("playground-tags-preview");

  function parseInput(raw) {
    var text = raw.trim();
    if (!text) {
      return { title: "（请输入任务与 #标签）", tags: [] };
    }
    // Match hashtags: # followed by non-space/non-# characters
    var tagMatches = text.match(/#([^\s#]+)/g) || [];
    var tags = tagMatches.map(function (t) { return t.substring(1); });
    // Remove hashtags from title
    var title = text.replace(/#([^\s#]+)/g, "").replace(/\s+/g, " ").trim();
    if (!title) {
      title = "（未命名专注任务）";
    }
    return { title: title, tags: tags };
  }

  function renderPlayground() {
    if (!playgroundInput || !titlePreview || !tagsPreview) return;
    var parsed = parseInput(playgroundInput.value);
    titlePreview.textContent = parsed.title;

    tagsPreview.innerHTML = "";
    if (parsed.tags.length === 0) {
      var emptyNotice = document.createElement("span");
      emptyNotice.className = "tag-empty-hint";
      emptyNotice.textContent = "无标签（将归入默认无分类专注）";
      tagsPreview.appendChild(emptyNotice);
    } else {
      parsed.tags.forEach(function (tag) {
        var badge = document.createElement("span");
        badge.className = "tag-badge";
        // Check for engineering/gear keywords
        var icon = "";
        if (tag.indexOf("⚙️") === -1 && (tag.indexOf("机械") !== -1 || tag.indexOf("工程") !== -1 || tag.indexOf("参数") !== -1 || tag.indexOf("硬件") !== -1)) {
          icon = "⚙️ ";
        } else if (tag.indexOf("🎯") === -1 && (tag.indexOf("大作业") !== -1 || tag.indexOf("项目") !== -1 || tag.indexOf("比赛") !== -1)) {
          icon = "🎯 ";
        } else if (tag.indexOf("📖") === -1 && (tag.indexOf("论文") !== -1 || tag.indexOf("阅读") !== -1 || tag.indexOf("文献") !== -1)) {
          icon = "📖 ";
        }
        badge.textContent = "#" + icon + tag;
        tagsPreview.appendChild(badge);
      });
    }
  }

  if (playgroundInput) {
    playgroundInput.addEventListener("input", renderPlayground);
    // Initial render
    renderPlayground();
  }

  // Preset buttons
  document.querySelectorAll(".preset-tag-btn").forEach(function (btn) {
    btn.addEventListener("click", function () {
      if (!playgroundInput) return;
      playgroundInput.value = btn.dataset.preset || btn.textContent.trim();
      renderPlayground();
      playgroundInput.focus();
    });
  });

  // 5. GitHub Releases Latest Dynamic Version & Fallback
  var controller = new AbortController();
  var timeout = setTimeout(function () { controller.abort(); }, 6000);
  fetch("https://api.github.com/repos/mikilolipop/TomatoBar-Personal/releases/latest", {
    headers: { Accept: "application/vnd.github+json" }, signal: controller.signal
  })
    .then(function (response) { if (!response.ok) throw new Error("Release unavailable"); return response.json(); })
    .then(function (release) {
      if (!Array.isArray(release.assets) || typeof release.tag_name !== "string") return;
      var packages = {};
      release.assets.forEach(function (asset) {
        var match = /^TomatoBarPersonal-[\d.]+\.(dmg|zip)$/.exec(asset.name);
        if (!match || typeof asset.browser_download_url !== "string") return;
        var url = new URL(asset.browser_download_url);
        if (url.origin !== "https://github.com" || !url.pathname.startsWith("/mikilolipop/TomatoBar-Personal/releases/download/")) return;
        packages[match[1]] = asset;
      });
      // Keep the version and both package types consistent.
      if (!packages.dmg || !packages.zip) return;
      ["dmg", "zip"].forEach(function (type) {
        document.querySelectorAll('[data-download="' + type + '"]').forEach(function (link) { link.href = packages[type].browser_download_url; });
        if (Number.isFinite(packages[type].size) && packages[type].size > 0) {
          document.querySelectorAll('[data-download-size="' + type + '"]').forEach(function (label) { label.textContent = (packages[type].size / 1048576).toFixed(1) + " MB"; });
        }
      });
      document.querySelectorAll("[data-release-version]").forEach(function (label) { label.textContent = release.tag_name; });
    })
    .catch(function () { /* The static links remain usable. */ })
    .finally(function () { clearTimeout(timeout); });
})();
