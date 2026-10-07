class_name WebCodeBox
## The save code on the web (phones): a real web page box over the game, with a big text area,
## so a long code can be copied, saved as a file, pasted or loaded from a file properly (the
## browser's little prompt box and the game's own clipboard can't be trusted with it on a
## phone). Loading: the box leaves the pasted code in `window.__bhCode`; `take()` collects it.

const STYLE := "position:fixed;inset:0;z-index:99999;background:rgba(10,30,45,.85);display:flex;align-items:center;justify-content:center;font-family:sans-serif"
const PANEL := "background:#1f3a4d;color:#fff;border-radius:12px;padding:16px;width:min(92vw,640px);box-sizing:border-box"
const AREA := "width:100%;height:38vh;box-sizing:border-box;font-family:monospace;font-size:13px;border-radius:8px;padding:8px;word-break:break-all"
const BUTTON := "font-size:18px;padding:12px 16px;margin:8px 8px 0 0;border:0;border-radius:8px;color:#fff;background:#2a78a8"


## Shows `code` to copy or save as a file.
static func show_code(code: String) -> void:
	JavaScriptBridge.eval(_box_js("Your save code", "Copy it into your notes app (or save it as a file). Keep all of it: it's one long line.",
		code, true))


## Asks for a code: paste it, or load a saved file. The game picks it up with take().
static func ask_code() -> void:
	JavaScriptBridge.eval(_box_js("Load a save code", "Paste your whole save code (it starts with BH1:), or load a save file. This replaces your current progress.",
		"", false))


## The code the ranger loaded in the box ("" while there's none); taken only once.
static func take() -> String:
	var code: Variant = JavaScriptBridge.eval("(function(){var c=window.__bhCode||'';window.__bhCode='';return c;})()", true)
	return code if code is String else ""


static func _box_js(title: String, note: String, code: String, showing: bool) -> String:
	var buttons := ""
	if showing:
		buttons = """
	add('Copy', function(){ area.removeAttribute('readonly'); area.select(); area.setSelectionRange(0, area.value.length);
		var done = false; try { done = document.execCommand('copy'); } catch(e) {}
		if (navigator.clipboard) { navigator.clipboard.writeText(area.value).then(function(){ msg.textContent = 'Copied!'; }, function(){}); }
		area.setAttribute('readonly', 'readonly'); msg.textContent = done ? 'Copied!' : 'Select all the text and copy it.'; });
	add('Save as file', function(){ var a = document.createElement('a');
		a.href = URL.createObjectURL(new Blob([area.value], {type: 'text/plain'})); a.download = 'bluehaven-save.txt';
		document.body.appendChild(a); a.click(); a.remove(); msg.textContent = 'Saved as bluehaven-save.txt'; });
	add('Close', close);"""
	else:
		buttons = """
	add('Load', function(){ window.__bhCode = area.value; close(); });
	var file = document.createElement('input'); file.type = 'file'; file.accept = '.txt,text/plain'; file.style.display = 'none';
	file.onchange = function(){ var f = file.files[0]; if (!f) return; var r = new FileReader();
		r.onload = function(){ area.value = r.result; msg.textContent = 'Loaded the file: tap Load.'; }; r.readAsText(f); };
	panel.appendChild(file);
	add('Load from a file', function(){ file.click(); });
	add('Cancel', close);"""
	return """(function(){
	var old = document.getElementById('bh-code-box'); if (old) old.remove();
	var box = document.createElement('div'); box.id = 'bh-code-box'; box.style.cssText = %s;
	var panel = document.createElement('div'); panel.style.cssText = %s; box.appendChild(panel);
	var h = document.createElement('h2'); h.textContent = %s; h.style.margin = '0 0 8px'; panel.appendChild(h);
	var p = document.createElement('p'); p.textContent = %s; panel.appendChild(p);
	var area = document.createElement('textarea'); area.style.cssText = %s; area.value = %s;
	area.spellcheck = false; area.autocapitalize = 'off'; area.setAttribute('autocorrect', 'off');
	if (%s) { area.setAttribute('readonly', 'readonly'); } else { area.placeholder = 'Paste your save code here'; }
	panel.appendChild(area);
	var msg = document.createElement('div'); msg.style.cssText = 'min-height:1.4em;margin-top:6px;color:#f2d58a'; panel.appendChild(msg);
	var row = document.createElement('div'); panel.appendChild(row);
	function close(){ box.remove(); }
	function add(text, act){ var b = document.createElement('button'); b.textContent = text; b.style.cssText = %s; b.onclick = act; row.appendChild(b); }
	%s
	['touchstart','touchend','mousedown','mouseup','keydown','keyup'].forEach(function(t){ box.addEventListener(t, function(e){ e.stopPropagation(); }); });
	document.body.appendChild(box);
})()""" % [JSON.stringify(STYLE), JSON.stringify(PANEL), JSON.stringify(title), JSON.stringify(note), JSON.stringify(AREA),
		JSON.stringify(code), "true" if showing else "false", JSON.stringify(BUTTON), buttons]
