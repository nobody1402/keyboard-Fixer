#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; =====================================================
; کیبورد فیکسر — نسخه ویندوز (با تشخیص خودکار)
; میانبر دستی: Alt+F روی متن انتخاب‌شده
; حالت خودکار: وقتی کلمه‌ی تایپ‌شده انگلیسیِ واقعی نباشه،
;              یه دکمه‌ی کوچیک کنار مکان‌نما ظاهر میشه
; =====================================================

global AutoModeEnabled := true
global MinWordLength := 2
global TypedBuffer := ""
global Dictionary := Map()
global PopupGui := 0
global PopupWord := ""
global PopupWordLen := 0

; =====================================================
; نقشه کیبورد انگلیسی → فارسی
; =====================================================
global FA_MAP := Map(
    "q","ض", "w","ص", "e","ث", "r","ق", "t","ف",
    "y","غ", "u","ع", "i","ه", "o","خ", "p","ح",
    "[","ج", "]","چ",
    "a","ش", "s","س", "d","ی", "f","ب", "g","ل",
    "h","ا", "j","ت", "k","ن", "l","م",
    ";","ک", "'","گ",
    "z","ظ", "x","ط", "c","ز", "v","ر", "b","ذ",
    "n","د", "m","پ",
    ",","و", "/","ژ", "``","ذ",
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
; بارگذاری دیکشنری انگلیسی (برای تشخیص کلمه‌ی واقعی)
; =====================================================
LoadDictionary() {
    global Dictionary

    if (A_IsCompiled) {
        dictPath := A_Temp "\kb_fixer_dictionary.txt"
        if !FileExist(dictPath)
            FileInstall("dictionary.txt", dictPath, true)
    } else {
        dictPath := A_ScriptDir "\dictionary.txt"
    }

    if !FileExist(dictPath) {
        ShowToast("⚠️ فایل دیکشنری پیدا نشد — حالت خودکار غیرفعاله")
        return false
    }

    content := FileRead(dictPath, "UTF-8")
    loop parse, content, "`n", "`r" {
        if (A_LoopField != "")
            Dictionary[A_LoopField] := true
    }
    return true
}

; =====================================================
; بخش تشخیص خودکار حین تایپ
; =====================================================

; کلیدهایی که بخشی از یه کلمه‌ی در حال تایپ محسوب میشن
LetterKeys := ["q","w","e","r","t","y","u","i","o","p","a","s","d","f","g","h","j","k","l",
               "z","x","c","v","b","n","m","[","]",";","'","`",",","/"]

for _, k in LetterKeys {
    Hotkey("~" k, KeyTyped)
}
Hotkey("~Space", WordBoundary)
Hotkey("~Enter", WordBoundary)
Hotkey("~Tab", WordBoundary)
Hotkey("~.", WordBoundary)
Hotkey("~BackSpace", KeyBackspace)
Hotkey("~LButton", ResetBuffer)
Hotkey("~Escape", ResetBuffer)

KeyTyped(hk) {
    global TypedBuffer, AutoModeEnabled
    if !AutoModeEnabled
        return
    ; کلید فعلی رو از نام هات‌کی استخراج می‌کنیم (بدون ~)
    key := SubStr(hk, 2)
    TypedBuffer .= key
    ; اگه کاربر داره تایپ می‌کنه، هر پاپ‌آپ قبلی دیگه معتبر نیست
    DestroyPopup()
}

KeyBackspace(hk) {
    global TypedBuffer
    if (TypedBuffer != "")
        TypedBuffer := SubStr(TypedBuffer, 1, StrLen(TypedBuffer) - 1)
    DestroyPopup()
}

ResetBuffer(hk) {
    global TypedBuffer
    TypedBuffer := ""
    DestroyPopup()
}

WordBoundary(hk) {
    global TypedBuffer, AutoModeEnabled
    word := TypedBuffer
    TypedBuffer := ""
    if !AutoModeEnabled
        return
    CheckWord(word)
}

; بررسی می‌کنه کلمه‌ی تایپ‌شده یه کلمه‌ی واقعیِ انگلیسیه یا نه
CheckWord(word) {
    global Dictionary, MinWordLength

    if (StrLen(word) < MinWordLength)
        return
    ; فقط کلماتی که تماماً از حروف انگلیسیِ نگاشت‌شده تشکیل شدن بررسی میشن
    if !RegExMatch(word, "^[a-zA-Z\[\];',/\x60]+$")
        return

    lw := StrLower(word)

    ; اگه تو دیکشنری انگلیسی وجود داره یعنی احتمالاً عمداً انگلیسی تایپ شده
    if Dictionary.Has(lw)
        return

    ; در غیر این صورت به احتمال زیاد تایپ اشتباهی (فینگلیش) بوده
    ShowConvertPopup(word)
}

; =====================================================
; پاپ‌آپ کوچیک کنار مکان‌نما برای تایید تبدیل
; =====================================================
ShowConvertPopup(word) {
    global PopupGui, PopupWord, PopupWordLen

    DestroyPopup()

    if !CaretGetPos(&cx, &cy) {
        MouseGetPos(&cx, &cy)
        cy += 20
    }

    PopupWord := word
    PopupWordLen := StrLen(word)

    PopupGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "")
    PopupGui.BackColor := "1a1d27"
    PopupGui.SetFont("s10 cWhite", "Tahoma")
    btn := PopupGui.Add("Button", "x4 y4 w170 h32", "🔄 تبدیل به فارسی")
    btn.OnEvent("Click", (*) => ConfirmConvert())

    PopupGui.Show("x" (cx) " y" (cy + 22) " w178 h40 NoActivate")

    ; اگه چند ثانیه کاری نکرد، خودش بسته میشه
    SetTimer(DestroyPopup, -4000)
}

ConfirmConvert() {
    global PopupWord, PopupWordLen

    word := PopupWord
    wlen := PopupWordLen
    DestroyPopup()

    if (word = "" || wlen = 0)
        return

    converted := ConvertToFarsi(word)

    ; حذف کلمه‌ی اشتباه و جایگزینی با نسخه‌ی فارسی
    Send("{Backspace " wlen "}")

    saved := ClipboardAll()
    A_Clipboard := converted
    Send("^v")
    Sleep(300)
    A_Clipboard := saved
}

DestroyPopup(*) {
    global PopupGui
    if (PopupGui != 0) {
        try PopupGui.Destroy()
        PopupGui := 0
    }
}

; =====================================================
; Alt+F — تبدیل متن انتخاب‌شده (دستی)
; =====================================================
!f:: {
    saved := ClipboardAll()
    A_Clipboard := ""
    Send "^c"
    if !ClipWait(0.5) {
        ShowToast("⚠️ اول متن رو انتخاب کن، بعد Alt+F بزن")
        A_Clipboard := saved
        return
    }

    original := A_Clipboard

    if RegExMatch(original, "[\x{0600}-\x{06FF}]") {
        ShowToast("✅ متن فارسیه — نیازی به تبدیل نیست")
        A_Clipboard := saved
        return
    }

    converted := ConvertToFarsi(original)
    A_Clipboard := converted
    Send "^v"

    preview := SubStr(converted, 1, 40)
    if StrLen(converted) > 40
        preview .= "..."
    ShowToast("✓ تبدیل شد: " preview)

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

    if toastGui != 0 {
        try toastGui.Destroy()
    }

    toastGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "")
    toastGui.BackColor := "1a1d27"
    toastGui.SetFont("s11 " "ca78bfa", "Tahoma")
    toastGui.Add("Text", "x12 y10 w320", msg)

    MonitorGetWorkArea(, , , &mRight, &mBottom)
    toastGui.Show("x" (mRight - 370) " y" (mBottom - 70) " w360 h50 NoActivate")

    SetTimer(() => (toastGui.Destroy(), toastGui := 0), -2500)
}

; =====================================================
; آیکون System Tray
; =====================================================
ToggleAutoMode(*) {
    global AutoModeEnabled
    AutoModeEnabled := !AutoModeEnabled
    UpdateTrayMenu()
    ShowToast(AutoModeEnabled ? "✅ حالت خودکار فعال شد" : "⛔ حالت خودکار غیرفعال شد")
}

UpdateTrayMenu() {
    global AutoModeEnabled
    tray := A_TrayMenu
    tray.Delete()
    tray.Add("کیبورد فیکسر ✅ فعاله", (*) => 0)
    tray.Add()
    tray.Add((AutoModeEnabled ? "✔ " : "") "حالت خودکار (تشخیص هوشمند)", ToggleAutoMode)
    tray.Add()
    tray.Add("راهنما", ShowHelp)
    tray.Add("خروج", (*) => ExitApp())
    tray.Default := "راهنما"
}

A_IconTip := "کیبورد فیکسر — Alt+F یا تشخیص خودکار"
UpdateTrayMenu()

ShowHelp(*) {
    MsgBox(
        "کیبورد فیکسر`n`n" .
        "حالت خودکار`n" .
        "    وقتی کلمه‌ای تایپ می‌کنی که یه کلمه‌ی واقعیِ انگلیسی نیست`n" .
        "    (مثل sghl)، یه دکمه‌ی کوچیک کنار مکان‌نما ظاهر میشه.`n" .
        "    روش کلیک کن تا به فارسی تبدیل بشه.`n`n" .
        "    اگه کلمه‌ای واقعاً انگلیسی باشه (مثل book)، دست نمی‌خوره.`n`n" .
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

; =====================================================
; شروع برنامه
; =====================================================
LoadDictionary()
