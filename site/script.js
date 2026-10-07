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
      }
      document.querySelectorAll("[data-release-version]").forEach(function (label) { label.textContent = release.tag_name; });
    })
    .catch(function () { /* The static links remain usable. */ })
    .finally(function () { clearTimeout(timeout); });
})();
