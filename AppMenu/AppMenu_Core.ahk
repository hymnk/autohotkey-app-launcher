#Requires AutoHotkey v2.0
; ============================================================
;  AppMenu_Core.ahk
;  カテゴリ別アプリメニューの共通処理（各カテゴリの .ahk から #Include して使う）
;
;  アプリの置き場所: ドキュメント\AHK_Launcher\<カテゴリ名>\
;    ・ショートカット(.lnk) / exe / url / bat / ahk を入れるとメニューに出る
;    ・サブフォルダはクリックで中に入れる（「‹ 戻る」で戻る）
;    ・名前 = ファイル名（拡張子なし）、アイコン = エクスプローラーと同じもの
;
;  Windows標準のメニューは文字サイズを変えられないため、
;  ポップアップ風のウィンドウ（Gui + ListView）で表示している。
;  操作: クリックで起動 / ↑↓+Enter / 文字キーで頭出し / Esc・外側クリックで閉じる
;  （旧・標準メニュー版は old\AppMenu_Core_標準メニュー版.ahk）
; ============================================================

; ===== 見た目の設定 =====
APPMENU_FONT      := "Yu Gothic UI"
APPMENU_FONT_PX   := 16      ; 文字サイズ（表示倍率100%のときのpx）
APPMENU_MIN_WIDTH := 240     ; 最小の幅（表示倍率100%のときのpx）

; アプリ置き場のルートフォルダ
AppMenuRoot() {
    base := EnvGet("OneDrive")
    if (base = "")
        base := EnvGet("USERPROFILE") "\OneDrive"
    return base "\ドキュメント\AHK_Launcher"
}

ShowAppMenu(category) => AppMenu.Open(AppMenuRoot() "\" category)

class AppMenu {
    static Open(root) {
        global APPMENU_FONT, APPMENU_FONT_PX
        if !DirExist(root)
            DirCreate(root)
        this.stack := [root]
        this.scale := A_ScreenDPI / 96
        this.startTick := A_TickCount

        CoordMode "Mouse", "Screen"
        MouseGetPos(&mx, &my)
        this.mx := mx, this.my := my

        g := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale")
        g.BackColor := "FFFFFF"
        g.MarginX := 0, g.MarginY := 0
        g.SetFont("s" Round(APPMENU_FONT_PX * 72 / 96, 1), APPMENU_FONT)   ; px → pt
        lv := g.Add("ListView", "x0 y0 w300 h100 -Hdr -Multi -E0x200 +LV0x20 Report BackgroundFFFFFF", ["名前"])
        DllCall("uxtheme\SetWindowTheme", "Ptr", lv.Hwnd, "WStr", "Explorer", "Ptr", 0)  ; ホバー時の強調表示
        SendMessage(0x127, 0x10001, 0, lv)                                            ; フォーカス枠を非表示
        lv.OnEvent("Click", (ctrl, row) => this.Activate(row))
        g.Add("Button", "Default Hidden w0 h0").OnEvent("Click", (*) => this.Activate(this.lv.GetNext(0, "F")))
        g.OnEvent("Escape", (*) => ExitApp())
        this.gui := g, this.lv := lv

        ; Windows 11: 角丸 + 薄い枠線
        try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", g.Hwnd, "UInt", 33, "Int*", 2, "UInt", 4)
        try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", g.Hwnd, "UInt", 34, "UInt*", 0xC8C8C8, "UInt", 4)

        this.Populate()
        this.watchFn := ObjBindMethod(this, "Watch")
        SetTimer(this.watchFn, 30)
    }

    ; 現在のフォルダの中身で一覧を作り直す
    static Populate() {
        lv := this.lv
        path := this.stack[this.stack.Length]
        lv.Opt("-Redraw")
        lv.Delete()
        il := IL_Create(20, 10, true)                     ; 大きいアイコン(32px相当)
        if (old := lv.SetImageList(il, 1))
            IL_Destroy(old)
        this.il := il, this.items := []

        if (this.stack.Length > 1)
            this.AddRow("‹ 戻る", this.stack[this.stack.Length - 1], "back")
        count := 0
        Loop Files path "\*", "D" {
            this.AddRow(A_LoopFileName "  ›", A_LoopFileFullPath, "dir"), count++
        }
        Loop Files path "\*", "F" {
            if !(A_LoopFileExt ~= "i)^(lnk|exe|url|bat|cmd|ahk)$")
                continue
            this.AddRow(RegExReplace(A_LoopFileName, "\.[^.]+$"), A_LoopFileFullPath, "item"), count++
        }
        if !count
            this.AddRow("（未登録）ショートカットを入れてください", "", "none")
        this.AddRow("フォルダを開く（追加・削除）", path, "open")

        this.Layout()
        lv.Opt("+Redraw")
    }

    static AddRow(text, path, kind) {
        idx := 0
        if (path != "" && (hIcon := this.ShellIcon(path)))
            idx := IL_Add(this.il, "HICON:" hIcon)
        this.lv.Add(idx ? "Icon" idx : "Icon9999", " " text)   ; アイコンと文字の間に余白
        this.items.Push({kind: kind, path: path})
    }

    ; 中身に合わせてサイズを決め、カーソルの近く（画面内）に表示する
    static Layout() {
        global APPMENU_MIN_WIDTH
        lv := this.lv, s := this.scale
        lv.ModifyCol(1, "Auto")
        colW := SendMessage(0x101D, 0, 0, lv)             ; LVM_GETCOLUMNWIDTH
        w := Max(colW + Round(24 * s), Round(APPMENU_MIN_WIDTH * s))
        rc := Buffer(16, 0)                               ; LVM_GETITEMRECT(LVIR_BOUNDS)
        SendMessage(0x100E, 0, rc.Ptr, lv)
        rowH := NumGet(rc, 12, "Int") - NumGet(rc, 4, "Int")
        h := rowH * lv.GetCount() + Round(4 * s)
        lv.Move(0, 0, w, h)
        lv.ModifyCol(1, w - Round(4 * s))

        this.WorkArea(this.mx, this.my, &l, &t, &r, &b)
        x := this.mx - Round(16 * s)
        y := (this.my - h >= t) ? this.my - h : this.my   ; 基本はカーソルの上に出す
        x := Min(Max(x, l), r - w)
        y := Min(Max(y, t), b - h)
        this.gui.Show(Format("x{} y{} w{} h{}", x, y, w, h))
        try WinActivate(this.gui)
    }

    static WorkArea(x, y, &l, &t, &r, &b) {
        Loop MonitorGetCount() {
            MonitorGet(A_Index, &ml, &mt, &mr, &mb)
            if (x >= ml && x < mr && y >= mt && y < mb)
                return MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
        }
        MonitorGetWorkArea(MonitorGetPrimary(), &l, &t, &r, &b)
    }

    static Activate(row) {
        if (!row || row > this.items.Length)
            return
        it := this.items[row]
        switch it.kind {
            case "back":
                this.stack.Pop(), this.Populate()
            case "dir":
                this.stack.Push(it.path), this.Populate()
            case "open":
                Run(it.path), ExitApp()
            case "item":
                SetTimer(this.watchFn, 0)
                this.gui.Hide()
                try Run(it.path)
                catch as e
                    MsgBox("起動できませんでした:`n" it.path "`n`n" e.Message, "AppMenu", "Icon!")
                ExitApp()
        }
    }

    ; 外側がクリックされたら閉じる
    ; （フォーカス喪失では閉じない：通知などにフォーカスを奪われて勝手に消えるのを防ぐ）
    static Watch() {
        if (A_TickCount - this.startTick > 400)
            && (GetKeyState("LButton", "P") || GetKeyState("RButton", "P")) {
            MouseGetPos(,, &win)
            if (win != this.gui.Hwnd)
                ExitApp()
        }
    }

    ; アイコン（大）を取得する。取れなければ次の方法を試す
    ;   1) ショートカットに指定されたアイコンファイル
    ;   2) ショートカットのリンク先（exe など）
    ;   3) ファイルそのもの（エクスプローラーと同じ表示）
    static ShellIcon(path) {
        if (path ~= "i)\.lnk$") {
            target := iconFile := iconNum := ""
            try FileGetShortcut(path, &target, , , , &iconFile, &iconNum)
            if (iconFile != "" && FileExist(iconFile) && (h := this.FileIcon(iconFile, iconNum)))
                return h
            if (target != "" && FileExist(target) && (h := this.SysIcon(target)))
                return h
        }
        return this.SysIcon(path)
    }

    ; アイコンファイル / exe / dll から指定番号のアイコンを読み込む
    static FileIcon(file, num) {
        size := SysGet(11)                                ; SM_CXICON
        try {
            h := LoadPicture(file, "Icon" (num ? num : 1) " w" size " h" size, &imgType)
            if (h && imgType = 1)                         ; 1 = IMAGE_ICON
                return h
        }
        return 0
    }

    ; シェルのシステムイメージリストから取得（ショートカットの矢印は付かない）
    static SysIcon(path) {
        sfi := Buffer(A_PtrSize + 688, 0)                 ; SHFILEINFOW 構造体
        himl := DllCall("shell32\SHGetFileInfoW", "WStr", path, "UInt", 0
                      , "Ptr", sfi, "UInt", sfi.Size, "UInt", 0x4000, "UPtr")   ; SHGFI_SYSICONINDEX
        if (himl && (h := DllCall("comctl32\ImageList_GetIcon", "Ptr", himl
                                 , "Int", NumGet(sfi, A_PtrSize, "Int"), "UInt", 0, "Ptr")))
            return h
        sfi := Buffer(A_PtrSize + 688, 0)                 ; 予備: SHGFI_ICON
        if DllCall("shell32\SHGetFileInfoW", "WStr", path, "UInt", 0
                 , "Ptr", sfi, "UInt", sfi.Size, "UInt", 0x100, "UPtr")
            return NumGet(sfi, 0, "Ptr")
        return 0
    }
}
