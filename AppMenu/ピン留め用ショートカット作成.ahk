#Requires AutoHotkey v2.0
; ============================================================
;  ピン留め用ショートカット作成.ahk
;  5カテゴリ分のショートカット(.lnk)を「ピン留め用」フォルダに作成する。
;  各ショートカットに固有の AppUserModelID を設定し、
;  同じ AutoHotkey64.exe でもタスクバーに別々にピン留めできるようにする。
;  （カテゴリを増やしたら下の一覧に追記して再実行）
; ============================================================

categories := [
    ["開発",       "AutoHotkey.AppMenu.Dev"],
    ["ゲーム",     "AutoHotkey.AppMenu.Game"],
    ["AI",         "AutoHotkey.AppMenu.AI"],
    ["作業効率化", "AutoHotkey.AppMenu.Productivity"],
    ["ブラウザ",   "AutoHotkey.AppMenu.Browser"],
]

outDir := A_ScriptDir "\ピン留め用"
DirCreate(outDir)
made := ""
for c in categories {
    name := c[1], appId := c[2]
    script := A_ScriptDir "\" name ".ahk"
    icon   := A_ScriptDir "\icons\" name ".ico"
    lnk    := outDir "\" name ".lnk"
    if !FileExist(script)
        continue
    FileCreateShortcut(A_AhkPath, lnk, A_ScriptDir, '"' script '"'
                     , name " メニュー", FileExist(icon) ? icon : "")
    SetAppUserModelId(lnk, appId)
    made .= "・" name "`n"
}

if !(A_Args.Length && A_Args[1] = "/silent")
    MsgBox("作成しました:`n" made "`n場所: " outDir "`n`n右クリック →「タスクバーにピン留めする」で使えます。", "AppMenu")

; .lnk に System.AppUserModel.ID を書き込む
SetAppUserModelId(lnkPath, appId) {
    iid := Buffer(16)
    DllCall("ole32\CLSIDFromString", "WStr", "{886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99}", "Ptr", iid, "HRESULT") ; IID_IPropertyStore
    pps := 0
    DllCall("shell32\SHGetPropertyStoreFromParsingName", "WStr", lnkPath, "Ptr", 0
          , "Int", 2, "Ptr", iid, "Ptr*", &pps, "HRESULT")                                  ; GPS_READWRITE
    try {
        key := Buffer(20, 0)                                                                   ; PKEY_AppUserModel_ID
        DllCall("ole32\CLSIDFromString", "WStr", "{9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3}", "Ptr", key, "HRESULT")
        NumPut("UInt", 5, key, 16)
        pv := Buffer(24, 0)                                                                    ; PROPVARIANT
        NumPut("UShort", 31, pv, 0)                                                            ; VT_LPWSTR
        NumPut("Ptr", StrPtr(appId), pv, 8)
        ComCall(6, pps, "Ptr", key, "Ptr", pv, "HRESULT")                                      ; IPropertyStore::SetValue
        ComCall(7, pps, "HRESULT")                                                             ; IPropertyStore::Commit
    } finally {
        ObjRelease(pps)
    }
}

