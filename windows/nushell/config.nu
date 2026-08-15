# config.nu - Nushell 配置 (0.114+)

# Starship 提示符
source ~/.config/starship/init.nu

# 界面
$env.config.show_banner = false
$env.config.edit_mode = "emacs"
$env.config.error_style = "fancy"
$env.config.cursor_shape = { emacs: line, vi_insert: block, vi_normal: underscore }

# 修复 WezTerm 下按键时屏幕滚动的 bug（nushell#5585）
# osc133 是终端 prompt 标记，此 wezterm 版本处理有误导致上/下键时光标错位滚动
$env.config.shell_integration.osc133 = false
$env.config.shell_integration.osc633 = false

# 历史
$env.config.history = { max_size: 100000, sync_on_enter: true, file_format: "sqlite", isolation: false }

# 补全
$env.config.completions = {
    case_sensitive: false
    quick: true
    partial: true
    algorithm: "prefix"
    external: { enable: true, max_results: 100 }
}

# 文件与表格
$env.config.ls = { use_ls_colors: true }
$env.config.table = { mode: rounded, index_mode: always, show_empty: false }

# 常用别名
alias ll = ls -l
alias la = ls -la
alias .. = cd ..
alias ... = cd ../..
alias home = cd ~

# 激活 VS 2022 MSVC x64 编译环境（cl/link/nmake/Windows SDK）
def --env vsdev [] {
    let vcvars_cmd = 'C:\Users\lildengzi\.config\vcvars-x64.cmd'
    if not ($vcvars_cmd | path exists) {
        print -e "vsdev: 找不到 vcvars-x64.cmd"
        return
    }
    let res = (cmd /c $vcvars_cmd | complete)
    if $res.exit_code != 0 {
        print -e "vsdev: vcvarsall 执行失败"
        return
    }
    let rows = ($res.stdout | lines | each { |line|
        let trimmed = ($line | str trim)
        let parts = ($trimmed | split row --number 2 "=")
        if ($parts | length) == 2 { { key: ($parts.0 | str trim), value: ($parts.1 | str trim) } } else { null }
    } | where { |r| $r != null })
    let envmap = ($rows | reduce -f {} { |row, acc|
        let existing = ($row.key in ($env | columns))
        if ($existing and $row.key != 'Path') { $acc } else { $acc | upsert $row.key $row.value }
    })
    let envmap = ($envmap | upsert Path { |rec| if (($rec.Path | describe) == string) { $rec.Path | split row ";" } else { $rec.Path } })
    load-env $envmap
    print "MSVC x64 环境已加载 (cl/link/nmake/Windows SDK)"
}
