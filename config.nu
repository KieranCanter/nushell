$env.XDG_SESSION_TYPE = "wayland"

# Auto-start hyprland on tty1 login
if (tty) == "/dev/tty1" {
    start-hyprland
}

$env.LANG = "en_US.UTF-8"
$env.LC_ALL = "en_US.UTF-8"
$env.LESS = "-RF"
$env.LESSCHARSET = "utf-8"

$env.config.show_banner = false
$env.config.use_kitty_protocol = true

$env.PATH ++= [
"/usr/bin"
"/usr/sbin"
"/usr/local/bin"
"/bin"
"/sbin"
($env.HOME | path join ".local/bin")
($env.HOME | path join ".pyenv/bin")
($env.HOME | path join ".pyenv/shims")
]

# Set Neovim as default text editor
$env.config.buffer_editor = "nvim"
$env.EDITOR = $env.config.buffer_editor
$env.VISUAL = $env.EDITOR

$env.config.keybindings ++= [
    # Autocomplete history hint with ctrl-y
    {
        name: autocomplete_history_hint
        modifier: control
        keycode: char_y
        mode: [emacs, vi_normal, vi_insert]
        event: { send: historyhintcomplete }
    }
    # Autocomplete by word with ctrl+l and ctrl+h
    {
        name: autocomplete_history_hint_word
        modifier: control
        keycode: char_l
        mode: [emacs, vi_normal, vi_insert]
        event: { send: historyhintwordcomplete }
    }
    {
        name: backspace_word
        modifier: control
        keycode: char_h
        mode: [emacs, vi_normal, vi_insert]
        event: { edit: backspaceword }
    }
    # Unbind ctrl+d for exiting shell
    {
        name: unbind_quit_shell
        modifier: control
        keycode: char_d
        mode: [emacs, vi_normal, vi_insert]
        event: null
    }
]

# General =====================================================================
$env.config.footer_mode = "auto"
$env.config.bracketed_paste = true

$env.config.table.mode = "rounded"
$env.config.table.header_on_separator = true
$env.config.table.missing_value_symbol = '×'
$env.config.table.trim = { methodology: "truncating", truncating_suffix: "…" }

$env.config.datetime_format.table = "%b %d %Y %H:%M:%S"
$env.config.datetime_format.normal = "%b %d %Y %H:%M:%S"

$env.config.filesize.unit = "binary"

$env.config.completions.algorithm = "fuzzy"
$env.config.completions.case_sensitive = false
$env.config.completions.external.max_results = 20

$env.config.history.file_format = "sqlite"
$env.config.history.isolation = true

# Vi mode =====================================================================
$env.config.edit_mode = 'vi'
$env.config.cursor_shape.vi_insert = 'line'
$env.config.cursor_shape.vi_normal = 'block'

$env.config.keybindings ++= [
  {
    # mimic's Neovim's keymap '[' = 'Esc'
    name: nvim_to_normal_mode
    modifier: control
    keycode: char_u5b
    mode: vi_insert
    event: {
        send: vichangemode,
        mode: normal
    }
  },
]

# Theme =======================================================================
const theme = "catppuccin_mocha.nu"
source ($nu.default-config-dir | path join $theme)

# Menus =======================================================================
$env.config.menus ++= [{
  name: completion_menu
  only_buffer_difference: false # Match on text typed after menu is activated
  marker: "| "
  type: {
    # Source: https://github.com/nushell/reedline/blob/main/src/menu/ide_menu.rs
    layout: ide
    cursor_offset: -10000 # Always show at left edge with desc on right
    description_mode: 'right'
    description_offset: 0
    max_completion_height: 20 # Limit entry number not shift when shown at window bottom
  }
  style: { selected_text: { attr: 'r' } }
}]

# Environment variables =======================================================
# XDG_***
$env.XDG_CONFIG_HOME = $env.HOME | path join '.config'
$env.XDG_DATA_HOME = $env.HOME | path join '.local' 'share'
$env.XDG_STATE_HOME = $env.HOME | path join '.local' 'state'
$env.XDG_CACHE_HOME = $env.HOME | path join '.cache'

# Pager
$env.MANPAGER = 'nvim +Man!'
$env.PAGER = 'nvim +Man!'

# `rg` config
$env.RIPGREP_CONFIG_PATH = $env.HOME | path join '.config/ripgrep/.ripgreprc'

# Prompt ======================================================================
plugin add nu_plugin_gstat

use ($nu.default-config-dir | path join "priority-prompt.nu") *

# Closures to define prompt command colors
let pwd = { $env.config.color_config.shape_block }
let gitbranch = { ||
  let gstat = gstat --no-tag
  let diff = $gstat.ahead - $gstat.behind
  if ($diff > 0 and $gstat.behind == 0) {
    $env.config.color_config.shape_int
  } else if ($diff < 0 and $gstat.ahead == 0) {
    $env.config.color_config.shape_garbage
  } else if ($gstat.ahead != 0 and $gstat.behind != 0) {
    $env.config.explore.status.warn
  } else {
    $env.config.color_config.shape_match_pattern
  }
}
let gitstatus = { ||
  let gstat = gstat --no-tag
  let staged = (
    $gstat.idx_added_staged +
    $gstat.idx_modified_staged +
    $gstat.idx_deleted_staged +
    $gstat.idx_renamed +
    $gstat.idx_type_changed
  )
  let unstaged = (
    $gstat.wt_untracked +
    $gstat.wt_modified +
    $gstat.wt_deleted +
    $gstat.wt_renamed +
    $gstat.wt_type_changed
  )

  if ($gstat.conflicts > 0) {
    $env.config.color_config.shape_garbage
  } else if ($unstaged > 0 or $gstat.stashes > 0) {
    $env.config.explore.status.warn
  } else if ($staged > 0) {
    $env.config.color_config.shape_int
  } else {
    $env.config.color_config.shape_match_pattern
  }
}
let duration = { ||
  if ($env.LAST_EXIT_CODE == 0) {
    $env.config.color_config.shape_match_pattern
  } else {
    $env.config.color_config.shape_garbage
  }
}
let time = { $env.config.color_config.shape_block }

let prompt_parts = [
  # Think about making it work. Right now it results in extra ' ' and affects
  # the overall budget during part combination. Ideally it should start just
  # add an empty line before the full prompt.
  # {part: {(char newline)}, priority : infinity}

  (prompt_part_pwd --color $pwd --priority infinity --trunc_char $"(ansi white_dimmed)…"),
  (prompt_part_gitbranch --color $gitbranch --priority 4),
  (prompt_part_gitstatus --color $gitstatus --priority 0),
  (prompt_part_fill --char ' '),
  (prompt_part_cmdduration --color $duration --priority 1),
  (prompt_part_time --color $time --priority 2),
]
let prompt = $prompt_parts | prompt_make

$env.PROMPT_COMMAND = $prompt
$env.PROMPT_COMMAND_RIGHT = ''
$env.PROMPT_INDICATOR = (ansi $env.config.color_config.shape_block) + '> '
$env.PROMPT_INDICATOR_VI_INSERT = (ansi $env.config.color_config.shape_block) + '> '
$env.PROMPT_INDICATOR_VI_NORMAL = (ansi $env.config.color_config.shape_block) + '< '
$env.PROMPT_MULTILINE_INDICATOR = (ansi $env.config.color_config.shape_block) + ': '
$env.config.render_right_prompt_on_last_line = true

$env.TRANSIENT_PROMPT_COMMAND = $prompt
$env.TRANSIENT_PROMPT_COMMAND_RIGHT = ''
$env.TRANSIENT_PROMPT_INDICATOR = ''
$env.TRANSIENT_PROMPT_INDICATOR_VI_INSERT = (ansi $env.config.color_config.shape_block) + '> '
$env.TRANSIENT_PROMPT_INDICATOR_VI_NORMAL = ''
$env.TRANSIENT_PROMPT_MULTILINE_INDICATOR = ''

# LS_COLORS ===================================================================
$env.LS_COLORS = (vivid generate catppuccin-mocha)

# Directory jumping ===========================================================
source ($nu.default-config-dir | path join "dirjump.nu")

# Run fastfetch on new shell
fastfetch
