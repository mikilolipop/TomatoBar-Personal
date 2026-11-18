(function () {
  "use strict";
  var dialog = document.getElementById("preview-dialog");
  document.querySelectorAll("[data-preview]").forEach(function (button) {
    button.addEventListener("click", function () {
      dialog.showModal();
      document.body.classList.add("preview-open");
    });
  });
  document.getElementById("close-preview").addEventListener("click", function () { dialog.close(); });
  dialog.addEventListener("close", function () { document.body.classList.remove("preview-open"); });
  dialog.addEventListener("click", function (event) {
    if (event.target !== dialog) return;
    var bounds = dialog.getBoundingClientRect();
    if (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom) dialog.close();
  });
  var installDetails = document.getElementById("install-details");
  installDetails.addEventListener("toggle", function () {
    installDetails.querySelector(".summary-hint").textContent = installDetails.open ? "收起指南" : "展开安装指南";
  });
  function revealInstall() { if (window.location.hash === "#install") installDetails.open = true; }
  document.querySelectorAll('a[href="#install"]').forEach(function (link) {
    link.addEventListener("click", function () { installDetails.open = true; });
  });
  window.addEventListener("hashchange", revealInstall);
  revealInstall();
  document.getElementById("copy-command").addEventListener("click", async function () {
    var status = document.getElementById("copy-feedback");
    try {
      await navigator.clipboard.writeText(document.getElementById("install-command").textContent);
      status.textContent = "已复制。请在终端粘贴执行。";
    } catch (_) {
      status.textContent = "未能自动复制，请选中上方命令手动复制。";
    }
  });
  // Static URLs work even when the release API is unavailable.
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
        if (match && typeof asset.browser_download_url === "string") {
          var url = new URL(asset.browser_download_url);
          if (url.origin === "https://github.com" && url.pathname.startsWith("/mikilolipop/TomatoBar-Personal/releases/download/")) {
            packages[match[1]] = asset;
          }
        }
        var exeMatch = /^(TomatoBar.*\.exe|.*-setup\.exe)$/i.exec(asset.name);
        if (exeMatch && typeof asset.browser_download_url === "string") {
          packages.exe = asset;
        }
      });
      // Keep the version and package types consistent.
      if (packages.dmg && packages.zip) {
        ["dmg", "zip"].forEach(function (type) {
          document.querySelectorAll('[data-download="' + type + '"]').forEach(function (link) { link.href = packages[type].browser_download_url; });
          if (Number.isFinite(packages[type].size) && packages[type].size > 0) {
            document.querySelectorAll('[data-download-size="' + type + '"]').forEach(function (label) { label.textContent = (packages[type].size / 1048576).toFixed(1) + " MB"; });
          }
        });
      }
      if (packages.exe) {
        document.querySelectorAll('[data-download="exe"]').forEach(function (link) { link.href = packages.exe.browser_download_url; });
        if (Number.isFinite(packages.exe.size) && packages.exe.size > 0) {
          document.querySelectorAll('[data-download-size="exe"]').forEach(function (label) { label.textContent = (packages.exe.size / 1048576).toFixed(1) + " MB"; });
        }
      }
      document.querySelectorAll("[data-release-version]").forEach(function (label) { label.textContent = release.tag_name; });
    })
    .catch(function () { /* The static links remain usable. */ })
    .finally(function () { clearTimeout(timeout); });

  // Tomy v11 8x9 desktop pet interactive showcase
  var companionSection = document.getElementById("companion");
  var petCanvas = document.getElementById("site-tomy-canvas");
  if (companionSection && petCanvas) {
    var petCtx = petCanvas.getContext("2d");
    var petStage = document.getElementById("companion-stage");
    var petPill = document.getElementById("pet-status-pill");
    var petDesc = document.getElementById("pet-stage-desc");
    var petToggle = document.getElementById("pet-motion-toggle");
    var petWaveBtn = document.getElementById("pet-wave-trigger");
    var petChips = document.querySelectorAll("[data-pet-state]");

    var PET_META = {
      idle: { pill: "准备开始 · 待机呼吸", desc: "8 帧接地呼吸 + 自然 3 段眨眼，移动鼠标至附近可看四向眼神跟随。" },
      work: { pill: "正在专注 · 敲键盘", desc: "6 相硬边打字、屏幕微光脉动、轻点头与自然半/全眨眼。" },
      rest: { pill: "正在休息 · 喝茶", desc: "连续升腾热气叠加 5 段平滑抬杯轻抿。" },
      paused: { pill: "专注已暂停 · 打盹", desc: "轻柔睡眠呼吸 + 错落飘升淡出 zZz。" },
      celebrate: { pill: "🍅×4 · 专注完成！", desc: "蓄力压扁、星光凌空跃起与落地回弹定格。" },
      wave: { pill: "你好呀 · 番茄仔", desc: "绕肩轴平滑挥臂并保持开心笑脸。" }
    };

    var PET_STATES = {
      idle: { staticCol: 0 },
      work: { staticCol: 0 },
      rest: { staticCol: 0 },
      paused: { staticCol: 0 },
      celebrate: { staticCol: 4 },
      wave: { staticCol: 3 }
    };

    function buildPetBatch(key) {
      if (key === "idle") {
        var b = [];
        for (var c = 0; c < 8; c++) b.push([0, c, 135]);
        for (var c2 = 0; c2 < 8; c2++) b.push([0, c2, 135]);
        b.push([8, 0, 45], [8, 1, 110], [8, 0, 45]);
        return b;
      }
      if (key === "work") {
        var w = [];
        for (var k = 0; k < 2; k++) {
          for (var c = 0; c <= 5; c++) w.push([1, c, 115]);
        }
        w.push([1, 0, 300], [1, 6, 45], [1, 7, 115], [1, 6, 45], [1, 0, 320]);
        return w;
      }
      if (key === "rest") {
        return [[3, 0, 250], [3, 1, 250], [3, 2, 250], [3, 3, 250], [3, 0, 250], [3, 1, 250], [3, 2, 250], [3, 3, 250], [3, 4, 160], [3, 5, 200], [3, 6, 420], [3, 5, 160], [3, 7, 220]];
      }
      if (key === "paused") {
        return [[2, 0, 220], [2, 1, 220], [2, 2, 220], [2, 3, 220], [2, 4, 220], [2, 5, 220], [2, 6, 220], [2, 7, 220]];
      }
      if (key === "celebrate") {
        return [[4, 0, 85], [4, 1, 85], [4, 2, 95], [4, 3, 115], [4, 4, 115], [4, 5, 90], [4, 6, 95], [4, 7, 110]];
      }
      return [[5, 0, 80], [5, 1, 80], [5, 2, 80], [5, 3, 80], [5, 4, 80], [5, 5, 80], [5, 6, 80], [5, 7, 80]];
    }

    var reducedMotionQuery = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)");
    var petState = "work";
    var petPaused = !!(reducedMotionQuery && reducedMotionQuery.matches);
    var petOffscreen = false;
    var petDocHidden = document.hidden;
    var petWaveReturn = null;
    var petWaveTimer = null;
    var petGlanceCol = null;
    var petBatch = buildPetBatch(petState);
    var petStep = 0;
    var petTimer = null;

    var atlasImg = new Image();
    var triedFallbackAtlas = false;
    atlasImg.addEventListener("error", function () {
      if (!triedFallbackAtlas) {
        triedFallbackAtlas = true;
        atlasImg.src = "assets/tomy-atlas-1x.png";
      }
    });
    atlasImg.addEventListener("load", function () {
      renderPetFrame();
      syncCompanionPlayback();
    });
    atlasImg.src = "assets/tomy-atlas-2x.webp";

    function canAnimatePet() {
      return !petOffscreen && !petDocHidden && (!petPaused || petWaveTimer !== null);
    }

    function updatePetChrome() {
      var activeKey = petWaveTimer !== null ? "wave" : petState;
      petChips.forEach(function (chip) {
        chip.setAttribute("aria-pressed", chip.dataset.petState === activeKey ? "true" : "false");
      });
      petPill.textContent = PET_META[activeKey].pill;
      petDesc.textContent = PET_META[activeKey].desc;
      petToggle.textContent = petPaused ? "播放动画" : "暂停动画";
    }

    function renderPetFrame() {
      var cw = petCanvas.width;
      var ch = petCanvas.height;
      petCtx.clearRect(0, 0, cw, ch);
      if (!atlasImg.complete || atlasImg.naturalWidth <= 0) return;

      var srcCellW = atlasImg.naturalWidth / 8;
      var srcCellH = atlasImg.naturalHeight / 9;
      var row = 0;
      var col = 0;

      if (petPaused && petWaveTimer === null) {
        var idxMap = { idle: 0, work: 1, paused: 2, rest: 3, celebrate: 4, wave: 5 };
        row = idxMap[petState];
        col = (petGlanceCol !== null && petState === "idle") ? petGlanceCol : PET_STATES[petState].staticCol;
        if (petGlanceCol !== null && petState === "idle") row = 8;
      } else {
        if (petBatch.length === 0) petBatch = buildPetBatch(petWaveTimer !== null ? "wave" : petState);
        var cur = petBatch[petStep % petBatch.length];
        row = cur[0];
        col = cur[1];
        if (petState === "idle" && petWaveTimer === null && petGlanceCol !== null && row === 0) {
          row = 8;
          col = petGlanceCol;
        }
      }

      petCtx.imageSmoothingEnabled = true;
      petCtx.imageSmoothingQuality = "high";
      petCtx.drawImage(atlasImg, col * srcCellW, row * srcCellH, srcCellW, srcCellH, 0, 0, cw, ch);
    }

    function stopPetLoop() {
      if (petTimer !== null) {
        clearTimeout(petTimer);
        petTimer = null;
      }
    }

    function schedulePetTick() {
      stopPetLoop();
      if (!canAnimatePet()) return;
      if (petBatch.length === 0) petBatch = buildPetBatch(petWaveTimer !== null ? "wave" : petState);
      var cur = petBatch[petStep % petBatch.length];
      var waitMs = cur ? cur[2] : 135;
      petTimer = setTimeout(function () {
        if (!canAnimatePet()) return;
        petStep += 1;
        if (petStep >= petBatch.length) {
          petBatch = buildPetBatch(petWaveTimer !== null ? "wave" : petState);
          petStep = 0;
        }
        renderPetFrame();
        schedulePetTick();
      }, waitMs);
    }

    function syncCompanionPlayback() {
      updatePetChrome();
      if (canAnimatePet()) {
        renderPetFrame();
        schedulePetTick();
      } else {
        stopPetLoop();
        renderPetFrame();
      }
    }

    function setPetState(nextState) {
      if (petWaveTimer !== null) {
        clearTimeout(petWaveTimer);
        petWaveTimer = null;
        petWaveReturn = null;
      }
      petState = nextState;
      petGlanceCol = null;
      petBatch = buildPetBatch(nextState);
      petStep = 0;
      syncCompanionPlayback();
    }

    petChips.forEach(function (chip) {
      chip.addEventListener("click", function () {
        setPetState(chip.dataset.petState);
      });
    });

    petToggle.addEventListener("click", function () {
      petPaused = !petPaused;
      syncCompanionPlayback();
    });

    petWaveBtn.addEventListener("click", function () {
      if (petWaveTimer !== null) clearTimeout(petWaveTimer);
      else petWaveReturn = petState;
      petGlanceCol = null;
      petBatch = buildPetBatch("wave");
      petStep = 0;
      petWaveTimer = setTimeout(function () {
        var ret = petWaveReturn || "idle";
        petWaveTimer = null;
        petWaveReturn = null;
        petState = ret;
        petBatch = buildPetBatch(ret);
        petStep = 0;
        syncCompanionPlayback();
      }, 1280);
      syncCompanionPlayback();
    });

    petStage.addEventListener("pointermove", function (e) {
      if (petState !== "idle" || petWaveTimer !== null) {
        if (petGlanceCol !== null) {
          petGlanceCol = null;
          renderPetFrame();
        }
        return;
      }
      var rect = petCanvas.getBoundingClientRect();
      var dx = e.clientX - (rect.left + rect.width / 2);
      var dy = (rect.top + rect.height / 2) - e.clientY;
      var dist = Math.hypot(dx, dy);
      var nextCol = null;
      if (dist >= 18 && dist <= 175) {
        var isUp = dy > 24;
        nextCol = dx >= 0 ? (isUp ? 5 : 3) : (isUp ? 4 : 2);
      }
      if (nextCol !== petGlanceCol) {
        petGlanceCol = nextCol;
        renderPetFrame();
      }
    });

    petStage.addEventListener("pointerleave", function () {
      if (petGlanceCol !== null) {
        petGlanceCol = null;
        renderPetFrame();
      }
    });

    document.addEventListener("visibilitychange", function () {
      petDocHidden = document.hidden;
      syncCompanionPlayback();
    });

    if ("contentVisibility" in document.documentElement.style) {
      companionSection.addEventListener("contentvisibilityautostatechange", function (event) {
        petOffscreen = !!event.skipped;
        syncCompanionPlayback();
      });
    } else if ("IntersectionObserver" in window) {
      var io = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          petOffscreen = !entry.isIntersecting;
          syncCompanionPlayback();
        });
      }, { rootMargin: "200px" });
      io.observe(companionSection);
    }

    if (reducedMotionQuery && typeof reducedMotionQuery.addEventListener === "function") {
      reducedMotionQuery.addEventListener("change", function (event) {
        petPaused = !!event.matches;
        syncCompanionPlayback();
      });
    }

    syncCompanionPlayback();
  }
})();
