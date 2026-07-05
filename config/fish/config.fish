if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end

# =====================
# Default editor
# =====================
set -gx EDITOR nvim

# =====================
# TTY detection: switch to ASCII-only starship config
# =====================
if test "$TERM" = linux
    set -gx STARSHIP_CONFIG ~/.config/starship.tty.toml
else
    # 清除从父进程（TTY → GUI）继承来的 tty 配置
    set -e STARSHIP_CONFIG
end

# =====================
# Starship: colorful powerline prompt (p10k-style)
# =====================
if command -q starship
    starship init fish | source
end

# =====================
# Fetch compatibility
# - prefer a real fetch binary when available
# - fall back cleanly so distrobox shells do not fail startup
# Backup: ~/.config/fish/config.fish.bak
# =====================
function __codex_fetch_dispatch
    set -l args $argv

    if type -P fastfetch >/dev/null
        command fastfetch $args
        return $status
    end

    return 127
end

function fetch
    __codex_fetch_dispatch $argv
end

for cmd in fastfetch
    if not test -n (type -P $cmd)
        function $cmd --description "Compatibility wrapper for missing fetch command"
            __codex_fetch_dispatch $argv
        end
    end
end

function fish_greeting
    XDG_CURRENT_DESKTOP="DankMaterialShell" fetch --logo-position top
end

# =====================
# Distrobox stabilization
# - Debian fallback: missing passwd entry can still be entered as root
# - Fedora fallback: tty allocation can fail, so retry without tty
# =====================
function distrobox
    if test (count $argv) -ge 2
        and test "$argv[1]" = enter
        set -l container_name $argv[2]
        set -l enter_args $argv[3..-1]

        set -l enter_output (command distrobox enter $container_name $enter_args 2>&1)
        set -l enter_status $status

        if test $enter_status -eq 0
            printf '%s\n' $enter_output
            return 0
        end

        set -l enter_text (string join \n -- $enter_output)

        if string match -rq 'unable to find user .*no matching entries in passwd file' -- $enter_text
            command distrobox enter --root $container_name $enter_args
            return $status
        end

        if string match -rq 'open /dev/pts/ptmx: no such file or directory' -- $enter_text
            command distrobox enter --no-tty $container_name $enter_args
            return $status
        end

        printf '%s\n' $enter_output >&2
        return $enter_status
    end

    command distrobox $argv
end

alias fastfetch "fastfetch -s title:-:os:host:kernel:uptime:shell:de:wm:terminal:terminalfont:cpu:gpu:memory:display:locale:break:break:break:break:break"
