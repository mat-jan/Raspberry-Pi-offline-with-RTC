<#
.SYNOPSIS
    Synchronizuje czas komputera z RPi przez SSH, następnie zapisuje do RTC.
.DESCRIPTION
    Użycie: .\sync_time.ps1
    Wymaga: klienta OpenSSH (Windows 10/11: Ustawienia > Aplikacje > Funkcje opcjonalne > OpenSSH Client,
            albo: winget install Microsoft.OpenSSH.Client)
    Wymaga też klucza SSH skonfigurowanego dla logowania bez hasła (ssh-keygen + ssh-copy-id
    lub ręczne dodanie klucza do ~/.ssh/authorized_keys na RPi), inaczej trzeba będzie
    wpisywać hasło ręcznie.

.NOTES
    Różnice względem oryginalnej wersji bashowej (Linux/macOS) tego skryptu:

    - ping -c 1 -W 2   ->   Test-Connection -ComputerName $RPI_HOST -Count 1 -Quiet -TimeoutSeconds 2
      (PowerShellowy odpowiednik jednorazowego pinga z 2-sekundowym timeoutem)

    - date '+%Y-%m-%d %H:%M:%S'   ->   Get-Date -Format "yyyy-MM-dd HH:mm:ss"
      date -u '...'               ->   (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")
      (PowerShell nie ma polecenia "date"; czas pobiera się przez Get-Date)

    - Heredoc bashowy (ssh ... bash << ENDSSH ... ENDSSH) nie istnieje w PowerShell.
      Zamiennik: treść zdalnego skryptu trzymana jest w zmiennej $remoteScript (jako string
      w cudzysłowie "@ ... @"), a następnie przekazywana przez potok (pipe) na stdin do
      "ssh $RPI_USER@$RPI_HOST bash -s" — czyli: $remoteScript | ssh ... "bash -s"

    - Wewnątrz $remoteScript znaki $(...) należące do zdalnego basha (np. $(date ...))
      musiały zostać poprzedzone backtickiem: `$(date ...), żeby PowerShell nie próbował
      zinterpretować ich lokalnie (jako własne zmienne) przed wysłaniem tekstu do SSH.

    - Uruchamianie: .\sync_time.ps1
      Jeśli PowerShell zablokuje wykonanie skryptu (Execution Policy), uruchom najpierw:
      Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

    - Logowanie SSH: skrypt zakłada logowanie kluczem (bez hasła). Jeśli go nie masz:
      ssh-keygen  (wygeneruj parę kluczy na Windows)
      a potem skopiuj zawartość pliku ~/.ssh/id_ed25519.pub (lub id_rsa.pub) do
      ~/.ssh/authorized_keys na Raspberry Pi.
#>

$RPI_HOST = "192.168.1.113"
$RPI_USER = "admin"

Write-Host "=== Synchronizacja czasu RPi ==="
Write-Host ("Aktualny czas komputera: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))

# Sprawdź czy RPi jest dostępne
if (-not (Test-Connection -ComputerName $RPI_HOST -Count 1 -Quiet -TimeoutSeconds 2)) {
    Write-Host "BŁĄD: Nie można połączyć z $RPI_HOST — sprawdź czy RPi jest w sieci" -ForegroundColor Red
    exit 1
}

# Aktualny czas UTC do przesłania na RPi
$TIME_UTC = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")

# Skrypt wykonywany zdalnie na RPi (bash + osadzony python3)
$remoteScript = @"
    # Ustaw czas systemowy (UTC)
    sudo date -u -s '$TIME_UTC' > /dev/null
    # Zapisz do RTC
    sudo python3 - << 'PYEOF'
import fcntl, struct, time
RTC_SET_TIME = 0x4024700a
now = time.gmtime()
buf = struct.pack("8i", now.tm_sec, now.tm_min, now.tm_hour,
                  now.tm_mday, now.tm_mon - 1, now.tm_year - 1900,
                  now.tm_wday, now.tm_yday)
with open("/dev/rtc0", "wb") as f:
    fcntl.ioctl(f, RTC_SET_TIME, buf)
PYEOF
    echo "Czas systemowy: `$(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "Czas w RTC:     `$(cat /sys/class/rtc/rtc0/date) `$(cat /sys/class/rtc/rtc0/time) UTC"
"@

# Prześlij skrypt do RPi przez SSH (stdin), tak jak heredoc w bashu
$remoteScript | ssh "$RPI_USER@$RPI_HOST" "bash -s"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Gotowe — czas ustawiony i zapisany do RTC" -ForegroundColor Green
} else {
    Write-Host "❌ BŁĄD: Nie udało się ustawić czasu" -ForegroundColor Red
    exit 1
}
