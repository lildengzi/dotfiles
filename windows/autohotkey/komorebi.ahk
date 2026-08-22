#Requires AutoHotkey v2.0
#SingleInstance Force

RunKomo(cmd) {
    Run('"C:\Program Files\komorebi\bin\komorebic.exe" ' cmd, "", "Hide")
}

; ---- launch terminal (mintty + Nushell) ----
!Enter::Run('"C:\Program Files\Git\usr\bin\mintty.exe" -c "C:\Users\lildengzi\.config\mintty\minttyrc" -e nu', "C:\Users\lildengzi")

; ---- reload komorebi config ----
!o::RunKomo('reload-configuration')

; ---- focus ----
!Left::RunKomo('focus left')
!Down::RunKomo('focus down')
!Up::RunKomo('focus up')
!Right::RunKomo('focus right')

; ---- move window ----
!+Left::RunKomo('move left')
!+Down::RunKomo('move down')
!+Up::RunKomo('move up')
!+Right::RunKomo('move right')

; ---- resize ----
!^Left::RunKomo('resize-axis horizontal left')
!^Right::RunKomo('resize-axis horizontal right')
!^Up::RunKomo('resize-axis vertical up')
!^Down::RunKomo('resize-axis vertical down')

; ---- window ops ----
!q::RunKomo('close')
!f::RunKomo('toggle-maximize')
!v::RunKomo('toggle-float')
!x::RunKomo('cycle-layout next')
!+x::RunKomo('cycle-layout previous')
!p::RunKomo('toggle-pause')
!+r::RunKomo('retile')

; ---- workspace cycle ----
!PgDn::RunKomo('cycle-workspace next')
!PgUp::RunKomo('cycle-workspace previous')

; ---- focus workspaces 0-9 ----
!1::RunKomo('focus-workspace 0')
!2::RunKomo('focus-workspace 1')
!3::RunKomo('focus-workspace 2')
!4::RunKomo('focus-workspace 3')
!5::RunKomo('focus-workspace 4')
!6::RunKomo('focus-workspace 5')
!7::RunKomo('focus-workspace 6')
!8::RunKomo('focus-workspace 7')
!9::RunKomo('focus-workspace 8')
!0::RunKomo('focus-workspace 9')

; ---- send to workspace ----
!+1::RunKomo('send-to-workspace 0')
!+2::RunKomo('send-to-workspace 1')
!+3::RunKomo('send-to-workspace 2')
!+4::RunKomo('send-to-workspace 3')
!+5::RunKomo('send-to-workspace 4')
!+6::RunKomo('send-to-workspace 5')
!+7::RunKomo('send-to-workspace 6')
!+8::RunKomo('send-to-workspace 7')
!+9::RunKomo('send-to-workspace 8')
!+0::RunKomo('send-to-workspace 9')