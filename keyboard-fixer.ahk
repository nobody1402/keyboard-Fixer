#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; =====================================================
; کیبورد فیکسر — نسخه ویندوز
; میانبر: Alt+F روی متن انتخاب‌شده
; =====================================================

; نقشه کیبورد انگلیسی → فارسی
global FA_MAP := Map(
    "q","ض", "w","ص", "e","ث", "r","ق", "t","ف",
    "y","غ", "u","ع", "i","ه", "o","خ", "p","ح",
    "[","ج", "]","چ",
    "a","ش", "s","س", "d","ی", "f","ب", "g","ل",
    "h","ا", "j","ت", "k","ن", "l","م",
    ";","ک", "'","گ",
    "z","ظ", "x","ط", "c","ز", "v","ر", "b","ذ",
    "n","د", "m","پ",
    ",","و", "/","ژ", "`","ذ",
    "0","۰", "1","۱", "2","۲", "3","۳", "4","۴",
    "5","۵", "6","۶", "7","۷", "8","۸", "9","۹",
    "?","؟"
)

; تابع تبدیل
ConvertToFarsi(text) {
    result := ""
    loop parse, text {
        ch := StrLower(A_LoopField)
        if FA_MAP.Has(ch)
            result .= FA_MAP[ch]
        else
            result .= A_LoopField
    }
    return result
}

; =====================================================
; Alt+F — تبدیل متن انتخاب‌شده
; =====================================================
!f:: {
    ; کپی متن انتخاب‌شده
    saved := ClipboardAll()
    A_Clipboard := ""
    Send "^c"
    if !ClipWait(0.5) {
        ; چیزی انتخاب نشده — به کاربر بگو
        ShowToast("⚠️ اول متن رو انتخاب کن، بعد Alt+F بزن")
        A_Clipboard := saved
        return
    }
    
    original := A_Clipboard
    
    ; بررسی: آیا فارسی داره؟ (نیازی به تبدیل نیست)
    if RegExMatch(original, "[\x{0600}-\x{06FF}]") {
        ShowToast("✅ متن فارسیه — نیازی به تبدیل نیست")
        A_Clipboard := saved
        return
    }
    
    ; تبدیل
    converted := ConvertToFarsi(original)
    
    ; جایگزین کردن
    A_Clipboard := converted
    Send "^v"
    
    ; نمایش نتیجه
    preview := SubStr(converted, 1, 40)
    if StrLen(converted) > 40
        preview .= "..."
    ShowToast("✓ تبدیل شد: " preview)
    
    ; برگردوندن clipboard اصلی بعد از کمی تاخیر
    Sleep 800
    A_Clipboard := saved
}

; =====================================================
; Ctrl+Alt+F — تبدیل کل clipboard (بدون انتخاب)
; =====================================================
^!f:: {
    text := A_Clipboard
    if !text {
        ShowToast("⚠️ Clipboard خالیه")
        return
    }
    converted := ConvertToFarsi(text)
    A_Clipboard := converted
    preview := SubStr(converted, 1, 40)
    if StrLen(converted) > 40
        preview .= "..."
    ShowToast("📋 Clipboard تبدیل شد: " preview)
}

; =====================================================
; Toast notification سبک
; =====================================================
ShowToast(msg) {
    static toastGui := 0
    static toastTimer := 0
    
    if toastGui != 0 {
        try toastGui.Destroy()
    }
    
    toastGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "")
    toastGui.BackColor := "1a1d27"
    toastGui.SetFont("s11 c" "a78bfa", "Tahoma")
    toastGui.Add("Text", "x12 y10 w320", msg)
    
    ; گوشه پایین راست صفحه
    MonitorGetWorkArea(, , , &mRight, &mBottom)
    toastGui.Show("x" (mRight - 370) " y" (mBottom - 70) " w360 h50 NoActivate")
    
    ; بستن خودکار بعد از ۲.۵ ثانیه
    SetTimer(() => (toastGui.Destroy(), toastGui := 0), -2500)
}

; =====================================================
; آیکون System Tray
; =====================================================
tray := A_TrayMenu
tray.Delete()
tray.Add("کیبورد فیکسر ✅ فعاله", (*) => 0)
tray.Add()
tray.Add("راهنما", ShowHelp)
tray.Add("خروج", (*) => ExitApp())
tray.Default := "راهنما"
A_IconTip := "کیبورد فیکسر — Alt+F"

ShowHelp(*) {
    MsgBox(
        "کیبورد فیکسر`n`n" .
        "Alt + F`n" .
        "    متن انتخاب‌شده رو از انگلیسی (اشتباه) به فارسی تبدیل می‌کنه`n`n" .
        "Ctrl + Alt + F`n" .
        "    محتوای Clipboard رو تبدیل می‌کنه`n`n" .
        "مثال:`n" .
        "    sghl  →  سلام`n" .
        "    ]x,vd  →  چطوری`n" .
        "    fhai ilhik  →  باشه هماهنگ",
        "راهنمای کیبورد فیکسر",
        0x40
    )
}
