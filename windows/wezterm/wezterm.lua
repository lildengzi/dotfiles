local wezterm = require("wezterm")
local config = {}

-- 默认 shell：Nushell
config.default_prog = { "C:\\Users\\lildengzi\\AppData\\Local\\Programs\\nu\\bin\\nu.exe" }

-- 渲染：WebGpu（虚拟机无 GPU，Software 前端仍需 OpenGL 会直接打不开窗口）
-- WARP 软件渲染在 TUI 大量重绘时会闪，这是无 GPU 环境的已知上限
config.front_end = "WebGpu"
config.webgpu_power_preference = "LowPower"
config.max_fps = 10

-- 外观主题（Tokyo Night）
config.color_scheme = "Tokyo Night"

-- 字体：JetBrainsMono Nerd Font（starship 图标必需）
config.font = wezterm.font_with_fallback({
	"JetBrainsMono Nerd Font",
	"Cascadia Code",
})

config.font_size = 11.0

-- 窗口
config.window_padding = { left = 8, right = 8, top = 4, bottom = 4 }
config.initial_cols = 120
config.initial_rows = 32
config.native_macos_fullscreen_mode = false

-- Tab 栏
config.enable_tab_bar = true
config.show_tab_index_in_tab_bar = true

-- 复制粘贴（Windows 习惯）
config.keys = {
	-- Ctrl+Shift+C 复制
	{ key = "C", mods = "CTRL|SHIFT", action = wezterm.action.CopyTo("ClipboardAndPrimarySelection") },
	-- Ctrl+Shift+V 粘贴
	{ key = "V", mods = "CTRL|SHIFT", action = wezterm.action.PasteFrom("Clipboard") },
	-- Ctrl+Shift+N 新窗口
	{ key = "N", mods = "CTRL|SHIFT", action = wezterm.action.SpawnWindow },
}

-- 鼠标选择即复制
config.mouse_bindings = {
	{
		event = { Up = { streak = 1, button = "Left" } },
		mods = "NONE",
		action = wezterm.action.CompleteSelection("ClipboardAndPrimarySelection"),
	},
}

-- 光标
config.cursor_blink_rate = 800
config.default_cursor_style = "BlinkingBar"

-- 滚动
config.scrollback_lines = 10000

return config
