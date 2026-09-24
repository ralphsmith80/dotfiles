-- Right Alt push-to-talk dictation: hold to record, release to transcribe.
hl.unbind("Alt_R")
o.bind("Alt_R", "Start dictation (push-to-talk)", "voxtype record start")
hl.unbind("ALT + Alt_R")
o.bind("ALT + Alt_R", "Stop dictation (push-to-talk)", "voxtype record stop", { release = true })

-- Bind both keypad symbols so workspace shortcuts work with Num Lock on or off.
-- Keypad 0 selects workspace 10, matching the number row.
local keypad_navigation = { "KP_End", "KP_Down", "KP_Next", "KP_Left", "KP_Begin", "KP_Right", "KP_Home", "KP_Up", "KP_Prior", "KP_Insert" }
for workspace, key in ipairs(keypad_navigation) do
  for _, symbol in ipairs({ "KP_" .. (workspace % 10), key }) do
    hl.unbind("SUPER + " .. symbol)
    hl.unbind("SUPER + SHIFT + " .. symbol)
    hl.unbind("SUPER + SHIFT + ALT + " .. symbol)
    hl.bind("SUPER + " .. symbol, hl.dsp.focus({ workspace = tostring(workspace) }), { description = "Switch to workspace " .. workspace .. " (keypad)" })
    hl.bind("SUPER + SHIFT + " .. symbol, hl.dsp.window.move({ workspace = tostring(workspace) }), { description = "Move window to workspace " .. workspace .. " (keypad)" })
    hl.bind("SUPER + SHIFT + ALT + " .. symbol, hl.dsp.window.move({ workspace = tostring(workspace), follow = false }), { description = "Move window silently to workspace " .. workspace .. " (keypad)" })
  end
end
