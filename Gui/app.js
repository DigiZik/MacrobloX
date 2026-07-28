(function () {
  var state = {};
  var rows = [];
  var selected = [];
  var lastSelected = -1;
  var settingsDirty = false;

  var eventOptions = [
    "Send",
    "Sleep",
    "MouseClick",
    "MouseDown",
    "MouseUp",
    "MouseWheel",
    "KeyDown",
    "KeyUp"
  ];

  function $(id) {
    return document.getElementById(id);
  }

  function hasSelection(index) {
    for (var i = 0; i < selected.length; i++) {
      if (selected[i] === index) return true;
    }
    return false;
  }

  function sortSelection() {
    selected.sort(function (a, b) { return a - b; });
  }

  function encodeRows() {
    var parts = [];
    for (var i = 0; i < rows.length; i++) {
      parts.push([
        encodeURIComponent(rows[i].event || ""),
        encodeURIComponent(rows[i].key || ""),
        encodeURIComponent(rows[i].x || ""),
        encodeURIComponent(rows[i].y || "")
      ].join("\t"));
    }
    $("editorPayload").value = parts.join("\n");
  }

  function sendAction(action) {
    encodeRows();
    $("bridgePayload").value = action;
    document.title = "MacrobloXBridge:" + action + ":" + new Date().getTime();
  }

  function setText(id, value) {
    var el = $(id);
    if (el) el.innerText = value || "";
  }

  function setValue(id, value) {
    var el = $(id);
    if (el) el.value = value == null ? "" : value;
  }

  function setChecked(id, value) {
    var el = $(id);
    if (el) el.checked = !!value;
  }

  function switchTab(tabId) {
    var tabs = document.querySelectorAll(".tab");
    var buttons = document.querySelectorAll(".nav button");
    var i;
    for (i = 0; i < tabs.length; i++) tabs[i].className = tabs[i].className.replace(/\s?active/g, "");
    for (i = 0; i < buttons.length; i++) buttons[i].className = buttons[i].className.replace(/\s?active/g, "");
    $(tabId).className += " active";
    var button = document.querySelector('.nav button[data-tab="' + tabId + '"]');
    if (button) button.className += " active";
  }

  function setEditorHidden(hidden) {
    var shell = $("dashboardShell");
    var button = $("editorToggleButton");
    if (!shell) return;
    var fixed = shell.className.indexOf("workspace-fixed") >= 0;
    if (hidden) {
      shell.className = "dashboard-shell editor-hidden" + (fixed ? " workspace-fixed" : "");
      if (button) button.innerText = "Show Editor";
    } else {
      shell.className = "dashboard-shell" + (fixed ? " workspace-fixed" : "");
      if (button) button.innerText = "Hide Editor";
    }
    sendAction("syncWorkspace");
  }

  function toggleEditor() {
    var shell = $("dashboardShell");
    if (!shell) return;
    setEditorHidden(shell.className.indexOf("editor-hidden") < 0);
  }

  function bind(id, eventName, action) {
    var el = $(id);
    if (el) el.addEventListener(eventName, function () { sendAction(action); });
  }

  function applyTheme(theme) {
    document.body.className = theme === "light" ? "theme-light" : "theme-dark";
  }

  function markSettingsDirty() {
    settingsDirty = true;
    setText("settingsState", "Unsaved settings changes");
  }

  function setScreenshotCrop(crop, markDirty) {
    crop = crop || {};
    setValue("screenshotCropEnabled", crop.enabled ? "true" : "false");
    setValue("screenshotCropX", crop.x || 0);
    setValue("screenshotCropY", crop.y || 0);
    setValue("screenshotCropW", crop.w || 0);
    setValue("screenshotCropH", crop.h || 0);
    setText("screenshotCropSummary", crop.summary || "Full current screen");
    updateScreenshotControls();
    if (markDirty) markSettingsDirty();
  }

  function updateScreenshotControls() {
    var controls = $("screenshotCropControls");
    var enabled = $("discordScreenshots") && $("discordScreenshots").checked;
    if (controls) controls.style.display = enabled ? "block" : "none";
  }

  function getInputSelection(input) {
    if (typeof input.selectionStart === "number")
      return { start: input.selectionStart, end: input.selectionEnd };
    try {
      var range = document.selection.createRange();
      var copy = range.duplicate();
      copy.moveToElementText(input);
      copy.setEndPoint("EndToStart", range);
      return { start: copy.text.length, end: copy.text.length + range.text.length };
    } catch (err) {
      return { start: input.value.length, end: input.value.length };
    }
  }

  function setInputSelection(input, start, end) {
    if (input.setSelectionRange) {
      input.setSelectionRange(start, end);
      return;
    }
    try {
      var range = input.createTextRange();
      range.collapse(true);
      range.moveStart("character", start);
      range.moveEnd("character", end - start);
      range.select();
    } catch (err) {
    }
  }

  function replaceInputSelection(input, text) {
    var selection = getInputSelection(input);
    input.value = input.value.substring(0, selection.start) + text + input.value.substring(selection.end);
    setInputSelection(input, selection.start + text.length, selection.start + text.length);
    markSettingsDirty();
  }

  function bindClipboardShortcuts(input) {
    if (!input) return;
    input.addEventListener("keydown", function (evt) {
      if (!evt.ctrlKey) return;
      var key = String.fromCharCode(evt.keyCode || evt.which).toLowerCase();
      if (key === "a") {
        input.select();
        evt.preventDefault ? evt.preventDefault() : (evt.returnValue = false);
        return false;
      }
      if (key === "c" || key === "x") {
        if (!window.clipboardData) return true;
        var selection = getInputSelection(input);
        var text = input.value.substring(selection.start, selection.end);
        if (text !== "") window.clipboardData.setData("Text", text);
        if (key === "x" && text !== "") replaceInputSelection(input, "");
        evt.preventDefault ? evt.preventDefault() : (evt.returnValue = false);
        return false;
      }
      if (key === "v") {
        if (!window.clipboardData) return true;
        var pasted = "";
        pasted = window.clipboardData.getData("Text");
        if (pasted !== "") replaceInputSelection(input, pasted);
        evt.preventDefault ? evt.preventDefault() : (evt.returnValue = false);
        return false;
      }
    });
  }

  function focusedTextInput() {
    var el = document.activeElement;
    if (!el || !el.tagName) return null;
    var tag = el.tagName.toLowerCase();
    if (tag !== "input" && tag !== "textarea") return null;
    return el;
  }

  window.MacrobloXCopyFocusedInput = function (cut) {
    var input = focusedTextInput();
    var payload = $("clipboardPayload");
    if (!input || !payload) return false;
    var selection = getInputSelection(input);
    var text = input.value.substring(selection.start, selection.end);
    payload.value = text;
    if (cut && text !== "") replaceInputSelection(input, "");
    return true;
  };

  window.MacrobloXPasteFocusedInput = function (text) {
    var input = focusedTextInput();
    if (!input) return false;
    replaceInputSelection(input, text || "");
    return true;
  };

  function rowTemplate(eventName) {
    if (eventName === "Sleep") return { event: "Sleep", key: "", x: "500", y: "" };
    if (eventName === "Send") return { event: "Send", key: "{Enter}", x: "", y: "" };
    if (eventName === "KeyDown") return { event: "KeyDown", key: "Shift", x: "", y: "" };
    if (eventName === "KeyUp") return { event: "KeyUp", key: "Shift", x: "", y: "" };
    if (eventName === "MouseWheel") return { event: "MouseWheel", key: "Up", x: "0", y: "0" };
    return { event: eventName, key: "L", x: "0", y: "0" };
  }

  function normalizeRow(row) {
    row = row || {};
    var eventName = row.event || "Sleep";
    var key = row.key || "";
    if (eventName.indexOf("MouseClick ") === 0) {
      key = eventName.substring(11) || key || "L";
      eventName = "MouseClick";
    } else if (eventName.indexOf("MouseDown ") === 0) {
      key = eventName.substring(10) || key || "L";
      eventName = "MouseDown";
    } else if (eventName.indexOf("MouseUp ") === 0) {
      key = eventName.substring(8) || key || "L";
      eventName = "MouseUp";
    }
    if ((eventName === "Send" || eventName === "KeyDown" || eventName === "KeyUp") && key === "")
      key = row.x || "{Enter}";
    if (eventName === "MouseWheel") {
      key = String(key).toLowerCase() === "down" ? "Down" : "Up";
      return { event: eventName, key: key, x: row.x || "0", y: row.y || "0" };
    }
    if (eventName === "Sleep")
      return { event: eventName, key: "", x: row.x || "500", y: "" };
    if (eventName === "Send" || eventName === "KeyDown" || eventName === "KeyUp")
      return { event: eventName, key: key, x: "", y: "" };
    return { event: eventName, key: key || "L", x: row.x || "0", y: row.y || "0" };
  }

  function isMouseEvent(eventName) {
    return eventName === "MouseClick" || eventName === "MouseDown" || eventName === "MouseUp" || eventName === "MouseWheel";
  }

  function isKeyEvent(eventName) {
    return eventName === "Send" || eventName === "KeyDown" || eventName === "KeyUp";
  }

  function locked(field, eventName) {
    if (field === "key") return eventName === "Sleep";
    if (field === "x") return isKeyEvent(eventName);
    if (field === "y") return eventName === "Sleep" || isKeyEvent(eventName);
    return false;
  }

  function fieldHint(field, eventName) {
    if (eventName === "Sleep") {
      if (field === "key") return "Locked for Sleep. Type the pause duration in X.";
      if (field === "x") return "Milliseconds to pause, for example 500.";
      if (field === "y") return "Locked for Sleep.";
    }
    if (eventName === "Send") {
      if (field === "key") return "Text or a key token to send, for example abc, {Enter}, or {Space}.";
      if (field === "x") return "Locked for Send. Type the key or text in Key.";
      if (field === "y") return "Locked for Send.";
    }
    if (eventName === "KeyDown" || eventName === "KeyUp") {
      if (field === "key") return "Key name to hold or release, for example Shift, Ctrl, E, or Space.";
      if (field === "x") return "Locked for key hold events. Type the key name in Key.";
      if (field === "y") return "Locked for key hold events.";
    }
    if (isMouseEvent(eventName)) {
      if (field === "key") return eventName === "MouseWheel" ? "Wheel direction: Up or Down." : "Mouse button: L, R, or M.";
      if (field === "x") return "Mouse X coordinate.";
      if (field === "y") return "Mouse Y coordinate.";
    }
    return "";
  }

  function renderInputCell(field, row) {
    var isLocked = locked(field, row.event);
    var value = row[field] || "";
    var title = fieldHint(field, row.event);
    var placeholder = isLocked ? "Locked" : "";
    return '<div class="macro-cell' + (isLocked ? " locked" : "") + '" title="' + escapeAttr(title) + '"><input data-field="' + field + '" value="' + escapeAttr(value) + '" placeholder="' + placeholder + '"' + (isLocked ? " disabled" : "") + '></div>';
  }

  function optionHtml(value, selectedValue) {
    return '<option value="' + value + '"' + (value === selectedValue ? " selected" : "") + ">" + value + "</option>";
  }

  function renderRows() {
    var html = "";
    for (var i = 0; i < rows.length; i++) {
      var row = normalizeRow(rows[i]);
      rows[i] = row;
      var selectedClass = hasSelection(i) ? " selected" : "";
      html += '<div class="macro-row' + selectedClass + '" data-index="' + i + '">';
      html += '<div class="macro-cell" title="Choose the action type for this row."><select data-field="event">';
      for (var j = 0; j < eventOptions.length; j++) html += optionHtml(eventOptions[j], row.event);
      html += '</select></div>';
      html += renderInputCell("key", row);
      html += renderInputCell("x", row);
      html += renderInputCell("y", row);
      html += "</div>";
    }
    $("macroRows").innerHTML = html;
    setText("visibleRowCount", rows.length + (rows.length === 1 ? " row" : " rows"));
    encodeRows();
  }

  function applySelectionClasses() {
    var rowEls = $("macroRows").getElementsByTagName("div");
    for (var i = 0; i < rowEls.length; i++) {
      if ((" " + rowEls[i].className + " ").indexOf(" macro-row ") < 0) continue;
      var index = parseInt(rowEls[i].getAttribute("data-index"), 10);
      rowEls[i].className = "macro-row" + (hasSelection(index) ? " selected" : "");
    }
  }

  function escapeAttr(value) {
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/"/g, "&quot;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }

  function readRowInputs(rowEl) {
    var index = parseInt(rowEl.getAttribute("data-index"), 10);
    if (isNaN(index) || !rows[index]) return;
    var inputs = rowEl.getElementsByTagName("input");
    var selects = rowEl.getElementsByTagName("select");
    rows[index].event = selects.length ? selects[0].value : rows[index].event;
    rows[index].key = inputs.length > 0 ? inputs[0].value : "";
    rows[index].x = inputs.length > 1 ? inputs[1].value : "";
    rows[index].y = inputs.length > 2 ? inputs[2].value : "";
    rows[index] = normalizeRow(rows[index]);
    encodeRows();
  }

  function findRowElement(el) {
    while (el && el !== document.body) {
      if ((" " + el.className + " ").indexOf(" macro-row ") >= 0) return el;
      el = el.parentNode;
    }
    return null;
  }

  function isNativeEditable(el) {
    if (!el || !el.tagName) return false;
    var tag = el.tagName.toLowerCase();
    return tag === "input" || tag === "textarea";
  }

  function selectRow(index, evt, skipRender) {
    if (evt && evt.shiftKey && lastSelected >= 0) {
      selected = [];
      var start = Math.min(lastSelected, index);
      var end = Math.max(lastSelected, index);
      for (var i = start; i <= end; i++) selected.push(i);
    } else if (evt && evt.ctrlKey) {
      if (hasSelection(index)) {
        var next = [];
        for (var j = 0; j < selected.length; j++) if (selected[j] !== index) next.push(selected[j]);
        selected = next;
      } else {
        selected.push(index);
      }
      lastSelected = index;
    } else {
      selected = [index];
      lastSelected = index;
    }
    sortSelection();
    if (skipRender) applySelectionClasses();
    else renderRows();
  }

  function addRow(eventName) {
    if (!eventName) return;
    var insertAt = selected.length ? selected[selected.length - 1] + 1 : rows.length;
    rows.splice(insertAt, 0, rowTemplate(eventName));
    selected = [insertAt];
    lastSelected = insertAt;
    renderRows();
    sendAction("editorDirty");
  }

  function deleteSelected() {
    if (!selected.length) return;
    sortSelection();
    for (var i = selected.length - 1; i >= 0; i--) rows.splice(selected[i], 1);
    selected = [];
    lastSelected = -1;
    renderRows();
    sendAction("editorDirty");
  }

  function moveSelected(direction) {
    if (!selected.length) return;
    sortSelection();
    var i;
    if (direction === "up") {
      if (selected[0] === 0) return;
      for (i = 0; i < selected.length; i++) swapRows(selected[i], selected[i] - 1);
      for (i = 0; i < selected.length; i++) selected[i] -= 1;
    } else if (direction === "down") {
      if (selected[selected.length - 1] >= rows.length - 1) return;
      for (i = selected.length - 1; i >= 0; i--) swapRows(selected[i], selected[i] + 1);
      for (i = 0; i < selected.length; i++) selected[i] += 1;
    } else if (direction === "top") {
      moveBlock(0);
    } else if (direction === "bottom") {
      moveBlock(rows.length - selected.length);
    }
    sortSelection();
    renderRows();
    sendAction("editorDirty");
  }

  function swapRows(a, b) {
    var temp = rows[a];
    rows[a] = rows[b];
    rows[b] = temp;
  }

  function moveBlock(target) {
    var block = [];
    var keep = [];
    var i;
    for (i = 0; i < rows.length; i++) {
      if (hasSelection(i)) block.push(rows[i]);
      else keep.push(rows[i]);
    }
    if (target > keep.length) target = keep.length;
    rows = keep.slice(0, target).concat(block).concat(keep.slice(target));
    selected = [];
    for (i = 0; i < block.length; i++) selected.push(target + i);
  }

  function hideContextMenu() {
    $("editorContextMenu").style.display = "none";
  }

  function showContextMenu(x, y) {
    var menu = $("editorContextMenu");
    menu.style.left = x + "px";
    menu.style.top = y + "px";
    menu.style.display = "block";
  }

  window.MacrobloXApplyState = function (nextState) {
    state = nextState || {};
    if (!settingsDirty) applyTheme(state.theme || "light");
    setText("versionLabel", state.version || "");
    setText("aboutVersion", "Version " + (state.version || ""));
    setText("statusPill", state.status || "Idle");
    setText("statusDetail", state.statusDetail || "Ready");
    setText("robloxStatus", state.robloxStatus || "");
    setText("macroPath", state.currentMacroFile || "");
    setText("macroFolder", state.macroDir || "");
    setText("saveState", state.saveState || "");
    setText("workspaceMessage", state.robloxAttached ? "" : (state.robloxStatus || "Roblox will overlay here when detected."));

    setText("recordButton", state.recordButton || "Record");
    setText("playButton", state.playButton || "Play");
    setText("loopButton", state.loopButton || "Loop");
    setText("toggleHotkeysButton", state.toggleButton || "Disable hotkeys");

    if (!settingsDirty) {
      setChecked("themeToggle", state.theme === "light");
      setValue("mouseMode", state.mouseMode || "screen");
      setChecked("updateStartup", state.checkUpdatesOnStartup === "true");
      setChecked("discordEnabled", state.discordEnabled === "true");
      setValue("discordWebhookUrl", state.discordWebhookUrl || "");
      setValue("discordUserId", state.discordUserId || "");
      setChecked("discordScreenshots", state.discordSendScreenshots === "true");
      setScreenshotCrop({
        enabled: state.discordScreenshotCropEnabled === "true",
        x: state.discordScreenshotCropX || 0,
        y: state.discordScreenshotCropY || 0,
        w: state.discordScreenshotCropW || 0,
        h: state.discordScreenshotCropH || 0,
        summary: state.discordScreenshotCropSummary || "Full current screen"
      }, false);
      setText("settingsState", "Changes are saved only when you click Save Settings.");
    }
    setValue("loopDelay", state.loopDelay || 2000);
    setValue("loopSpeed", state.loopSpeed || "1x");
    updateScreenshotControls();
  };

  window.MacrobloXSetWorkspaceSize = function (width, height) {
    var shell = $("dashboardShell");
    var panel = document.querySelector(".workspace-panel");
    var workspace = $("robloxWorkspace");
    if (!shell || !panel || !workspace) return;

    width = Math.round(width || 0);
    height = Math.round(height || 0);
    if (width > 0 && height > 0) {
      width = Math.max(320, width);
      height = Math.max(240, height);
      if (shell.className.indexOf("workspace-fixed") < 0) shell.className += " workspace-fixed";
      panel.style.width = width + "px";
      panel.style.minWidth = width + "px";
      panel.style.maxWidth = width + "px";
      workspace.style.width = width + "px";
      workspace.style.height = height + "px";
      return;
    }

    shell.className = shell.className.replace(/\s?workspace-fixed/g, "");
    panel.style.width = "";
    panel.style.minWidth = "";
    panel.style.maxWidth = "";
    workspace.style.width = "";
    workspace.style.height = "";
  };

  window.MacrobloXSetScreenshotCrop = function (crop) {
    setScreenshotCrop(crop, true);
  };

  window.MacrobloXMarkSettingsSaved = function () {
    settingsDirty = false;
    setText("settingsState", "Changes are saved only when you click Save Settings.");
  };

  window.MacrobloXSetEditor = function (payload) {
    payload = payload || {};
    rows = [];
    var nextRows = payload.rows || [];
    for (var i = 0; i < nextRows.length; i++) rows.push(normalizeRow(nextRows[i]));
    selected = [];
    lastSelected = -1;
    setValue("loopDelay", payload.loopDelay || 2000);
    setValue("loopSpeed", payload.loopSpeed || "1x");
    setText("hiddenLineCount", (payload.hiddenLineCount || 0) + " hidden");
    renderRows();
  };

  window.MacrobloXInsertRow = function (eventName, x, y) {
    var insertAt = selected.length ? selected[selected.length - 1] + 1 : rows.length;
    rows.splice(insertAt, 0, normalizeRow({ event: eventName || "Sleep", key: arguments.length > 3 ? arguments[1] : "", x: arguments.length > 3 ? arguments[2] : x || "", y: arguments.length > 3 ? arguments[3] : y || "" }));
    selected = [insertAt];
    lastSelected = insertAt;
    renderRows();
    sendAction("editorDirty");
  };

  window.MacrobloXSerializeEditor = function () {
    encodeRows();
    return $("editorPayload").value || "";
  };

  document.addEventListener("DOMContentLoaded", function () {
    var navButtons = document.querySelectorAll(".nav button");
    for (var i = 0; i < navButtons.length; i++) {
      navButtons[i].addEventListener("click", function () {
        switchTab(this.getAttribute("data-tab"));
      });
    }

    bind("recordButton", "click", "record");
    bind("playButton", "click", "play");
    bind("loopButton", "click", "loop");
    bind("resetButton", "click", "reset");
    bind("toggleHotkeysButton", "click", "toggleHotkeys");
    bind("saveButton", "click", "save");
    bind("reloadButton", "click", "reload");
    bind("saveSettingsButton", "click", "saveSettings");
    bind("testWebhookButton", "click", "testWebhook");
    bind("setScreenshotCropButton", "click", "setScreenshotCrop");
    bind("clearScreenshotCropButton", "click", "clearScreenshotCrop");

    $("editorToggleButton").addEventListener("click", toggleEditor);

    var menuButtons = document.querySelectorAll("[data-action]");
    for (var j = 0; j < menuButtons.length; j++) {
      menuButtons[j].addEventListener("click", function () {
        var action = this.getAttribute("data-action");
        if (action === "focusEditor") {
          switchTab("dashboard");
          setEditorHidden(false);
        }
        sendAction(action);
      });
    }

    $("addAction").addEventListener("change", function () {
      addRow(this.value);
      this.value = "";
    });
    $("loopDelay").addEventListener("change", function () { sendAction("loopControls"); });
    $("loopSpeed").addEventListener("change", function () { sendAction("loopControls"); });

    $("macroRows").addEventListener("click", function (evt) {
      hideContextMenu();
      var rowEl = findRowElement(evt.target);
      if (!rowEl) return;
      var tag = evt.target.tagName ? evt.target.tagName.toLowerCase() : "";
      selectRow(parseInt(rowEl.getAttribute("data-index"), 10), evt, tag === "input" || tag === "select");
    });
    $("macroRows").addEventListener("change", function (evt) {
      var rowEl = findRowElement(evt.target);
      if (!rowEl) return;
      readRowInputs(rowEl);
      renderRows();
      sendAction("editorDirty");
    });
    $("macroRows").addEventListener("contextmenu", function (evt) {
      var rowEl = findRowElement(evt.target);
      if (!rowEl) return;
      evt.preventDefault ? evt.preventDefault() : (evt.returnValue = false);
      var index = parseInt(rowEl.getAttribute("data-index"), 10);
      if (!hasSelection(index)) selectRow(index, evt);
      showContextMenu(evt.clientX, evt.clientY);
      return false;
    });

    $("editorContextMenu").addEventListener("click", function (evt) {
      var action = evt.target.getAttribute("data-context");
      if (!action) return;
      hideContextMenu();
      if (action === "delete") deleteSelected();
      else if (action === "moveTop") moveSelected("top");
      else if (action === "moveUp") moveSelected("up");
      else if (action === "moveDown") moveSelected("down");
      else if (action === "moveBottom") moveSelected("bottom");
    });

    document.addEventListener("click", function (evt) {
      if (evt.target && evt.target.getAttribute && evt.target.getAttribute("data-context")) return;
      if (!findRowElement(evt.target)) hideContextMenu();
    });

    document.addEventListener("contextmenu", function (evt) {
      if (findRowElement(evt.target)) return;
      if (isNativeEditable(evt.target)) return true;
      evt.preventDefault ? evt.preventDefault() : (evt.returnValue = false);
      hideContextMenu();
      return false;
    });

    $("themeToggle").addEventListener("change", function () {
      applyTheme(this.checked ? "light" : "dark");
      markSettingsDirty();
    });
    $("mouseMode").addEventListener("change", markSettingsDirty);
    $("updateStartup").addEventListener("change", markSettingsDirty);
    $("discordEnabled").addEventListener("change", markSettingsDirty);
    $("discordWebhookUrl").addEventListener("input", markSettingsDirty);
    bindClipboardShortcuts($("discordWebhookUrl"));
    $("discordUserId").addEventListener("input", markSettingsDirty);
    $("discordScreenshots").addEventListener("change", function () {
      updateScreenshotControls();
      markSettingsDirty();
    });
    updateScreenshotControls();
  });
})();
