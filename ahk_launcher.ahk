#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon

root := A_Args.Length ? A_Args[1] : EnvGet("OneDrive") "\ドキュメント\AHK_Launcher"
if !DirExist(root)
    root := EnvGet("USERPROFILE") "\OneDrive\ドキュメント\AHK_Launcher"

m := BuildMenu(root)
m.Add()
m.Add("フォルダを開く", (*) => (Run(root), ExitApp()))
SetShellIcon(m, "フォルダを開く", root)

m.Show()       ; 引数なし＝マウスカーソルの位置に表示
Sleep 500
ExitApp

BuildMenu(path) {
    m := Menu()
    Loop Files path "\*", "D" {                      ; サブフォルダ → サブメニュー
        m.Add(A_LoopFileName, BuildMenu(A_LoopFileFullPath))
        SetShellIcon(m, A_LoopFileName, A_LoopFileFullPath)
    }
    Loop Files path "\*", "F" {                      ; ショートカットなど → 項目
        if !(A_LoopFileExt ~= "i)^(lnk|exe|url|bat|ahk)$")
            continue
        name := RegExReplace(A_LoopFileName, "\.[^.]+$")
        full := A_LoopFileFullPath
        m.Add(name, ((p, *) => (Run(p), ExitApp())).Bind(full))
        SetShellIcon(m, name, full)
    }
    return m
}

; エクスプローラーと同じアイコンを取得してメニュー項目に設定する
SetShellIcon(m, item, path) {
    static SHGFI_ICON := 0x100, SHGFI_SMALLICON := 0x1
    sfi := Buffer(A_PtrSize + 688, 0)                 ; SHFILEINFOW 構造体
    if DllCall("shell32\SHGetFileInfoW", "WStr", path, "UInt", 0
             , "Ptr", sfi, "UInt", sfi.Size
             , "UInt", SHGFI_ICON | SHGFI_SMALLICON, "UPtr")
        && (hIcon := NumGet(sfi, 0, "Ptr"))
        try m.SetIcon(item, "HICON:" hIcon)
}
