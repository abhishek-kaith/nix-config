hl.monitor({
  output   = "",
  mode     = "preferred",
  position = "auto",
  scale    = "auto",
})

hl.on("hyprland.start", function()
  hl.exec_cmd("noctalia")
end)

hl.config({
  general = {
    gaps_in          = 5,
    gaps_out         = 10,
    border_size      = 2,
    resize_on_border = true,
    layout           = "dwindle",
  },
  decoration = {
    rounding = 8,
    blur     = { enabled = true, size = 3, passes = 1 },
  },
  animations = { enabled = true },
  input = {
    kb_layout    = "us",
    follow_mouse = 1,
    touchpad     = { natural_scroll = true },
  },
  misc = { disable_hyprland_logo = true },
  dwindle = { preserve_split = true },
})

hl.animation({ leaf = "global",     enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "windows",    enabled = true, speed = 4.79, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "default" })

local S  = "SUPER"
local SS = "SUPER + SHIFT"
local SC = "SUPER + CTRL"

-- apps / session
hl.bind(S  .. " + RETURN",    hl.dsp.exec_cmd("alacritty"))
hl.bind(S  .. " + Q",         hl.dsp.window.close())
hl.bind(SS .. " + E",         hl.dsp.exec_cmd("hyprctl dispatch exit"))

-- window state
hl.bind(S .. " + F", hl.dsp.window.fullscreen())
hl.bind(S .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(S .. " + P", hl.dsp.window.pseudo())

-- focus — vim keys + arrows
hl.bind(S .. " + H",     hl.dsp.focus({ direction = "left"  }))
hl.bind(S .. " + L",     hl.dsp.focus({ direction = "right" }))
hl.bind(S .. " + K",     hl.dsp.focus({ direction = "up"    }))
hl.bind(S .. " + J",     hl.dsp.focus({ direction = "down"  }))
hl.bind(S .. " + LEFT",  hl.dsp.focus({ direction = "left"  }))
hl.bind(S .. " + RIGHT", hl.dsp.focus({ direction = "right" }))
hl.bind(S .. " + UP",    hl.dsp.focus({ direction = "up"    }))
hl.bind(S .. " + DOWN",  hl.dsp.focus({ direction = "down"  }))

-- move windows — vim keys + arrows
hl.bind(SS .. " + H",     hl.dsp.window.move({ direction = "left"  }))
hl.bind(SS .. " + L",     hl.dsp.window.move({ direction = "right" }))
hl.bind(SS .. " + K",     hl.dsp.window.move({ direction = "up"    }))
hl.bind(SS .. " + J",     hl.dsp.window.move({ direction = "down"  }))
hl.bind(SS .. " + LEFT",  hl.dsp.window.move({ direction = "left"  }))
hl.bind(SS .. " + RIGHT", hl.dsp.window.move({ direction = "right" }))
hl.bind(SS .. " + UP",    hl.dsp.window.move({ direction = "up"    }))
hl.bind(SS .. " + DOWN",  hl.dsp.window.move({ direction = "down"  }))

-- workspaces 1-9
for i = 1, 9 do
  hl.bind(S  .. " + " .. i, hl.dsp.focus({ workspace = i }))
  hl.bind(SS .. " + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- scroll through workspaces with mouse wheel
hl.bind(S .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(S .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- screenshot (grimblast)
hl.bind(SS .. " + S", hl.dsp.exec_cmd("grimblast copy area"))
hl.bind(S  .. " + S", hl.dsp.exec_cmd("grimblast copy screen"))

-- lock screen
hl.bind(S .. " + BACKSPACE", hl.dsp.exec_cmd("noctalia lock"))

-- mouse: move and resize floating windows
hl.bind(S .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(S .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
