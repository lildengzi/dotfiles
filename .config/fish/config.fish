if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end

# =====================
# Environment profile
# =====================
set -gx EDITOR nvim
set -gx DISTROBOX_DRIVER podman
set -gx DISTROBOX_SANDBOX_DIR ~/sandbox

function __is_portable_shell
    test "$TERM" = linux
    or set -q SSH_CONNECTION
    or set -q SSH_TTY
    or set -q container
    or test -f /.dockerenv
end

function __has_host_path
    test -d /opt/cuda
    and test -d ~/.config/DankMaterialShell
end

# =====================
# Host-only environment
# Avoid leaking desktop/GPU assumptions into SSH and containers.
# =====================
if not __is_portable_shell
    if __has_host_path
        set -gx CUDA_HOME /opt/cuda
        fish_add_path /opt/cuda/bin
        fish_add_path /opt/cuda/lib64
        if set -q LD_LIBRARY_PATH
            if not contains -- /opt/cuda/lib64 $LD_LIBRARY_PATH
                set -gx LD_LIBRARY_PATH /opt/cuda/lib64 $LD_LIBRARY_PATH
            end
        else
            set -gx LD_LIBRARY_PATH /opt/cuda/lib64
        end
    end
else
    set -e CUDA_HOME
    if set -q LD_LIBRARY_PATH
        set -l clean_ld_library_path
        for item in $LD_LIBRARY_PATH
            if test "$item" != /opt/cuda/lib64
                set clean_ld_library_path $clean_ld_library_path $item
            end
        end
        if test (count $clean_ld_library_path) -gt 0
            set -gx LD_LIBRARY_PATH $clean_ld_library_path
        else
            set -e LD_LIBRARY_PATH
        end
    end
end

# =====================
# Prompt profile
# - Host GUI: colorful powerline prompt
# - TTY/SSH/container: conservative ASCII-compatible prompt
# =====================
if __is_portable_shell
    if test -f ~/.config/starship.tty.toml
        set -gx STARSHIP_CONFIG ~/.config/starship.tty.toml
    end
    if test "$TERM" = xterm-kitty
        set -gx TERM xterm-256color
    end
else
    # Clear inherited portable config when returning to GUI terminals.
    set -e STARSHIP_CONFIG
end

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

if not __is_portable_shell
    function fish_greeting
        XDG_CURRENT_DESKTOP="DankMaterialShell" fetch --logo-position top
    end
else
    function fish_greeting
    end
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

        set -l final_args $enter_args

        if test (count $final_args) -eq 0
            set final_args -- bash -lc 'cd "$HOME/sandbox" 2>/dev/null || cd "$HOME"; exec bash -l'
        end

        set -l enter_output (command distrobox enter $container_name $final_args 2>&1)
        set -l enter_status $status

        if test $enter_status -eq 0
            printf '%s\n' $enter_output
            return 0
        end

        set -l enter_text (string join \n -- $enter_output)

        if string match -rq 'unable to find user .*no matching entries in passwd file' -- $enter_text
            command distrobox enter --root $container_name $final_args
            return $status
        end

        if string match -rq 'open /dev/pts/ptmx: no such file or directory' -- $enter_text
            command distrobox enter --no-tty $container_name $final_args
            return $status
        end

        printf '%s\n' $enter_output >&2
        return $enter_status
    end

    command distrobox $argv
end

abbr -a ff fastfetch

# alias fastfetch "fastfetch -s title:-:os:host:kernel:uptime:shell:de:wm:terminal:terminalfont:cpu:gpu:memory:display:locale:break:break:break:break:break"

# Steam XWayland compatibility
alias steam="env STEAM_FORCE_WAYLAND=0 /usr/bin/steam"

alias vi nvim
alias vim nvim
alias zed zeditor
