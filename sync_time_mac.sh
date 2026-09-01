#!/bin/bash
# Synchronizuje czas komputera z RPi przez SSH, następnie zapisuje do RTC
# Użycie: ./sync_time.sh
# Wymaga: ssh zainstalowanego na komputerze

RPI_HOST="192.168.1.113"
RPI_USER="admin"

echo "=== Synchronizacja czasu RPi ==="
echo "Aktualny czas komputera: $(date '+%Y-%m-%d %H:%M:%S')"

# Sprawdź czy RPi jest dostępne
if ! ping -c 1 -W 2 "$RPI_HOST" &>/dev/null; then
    echo "BŁĄD: Nie można połączyć z $RPI_HOST — sprawdź czy RPi jest w sieci"
    exit 1
fi

# Prześlij aktualny czas UTC do RPi i zapisz do RTC
TIME_UTC=$(date -u '+%Y-%m-%d %H:%M:%S')

ssh "$RPI_USER@$RPI_HOST" bash << ENDSSH
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

    echo "Czas systemowy: \$(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "Czas w RTC:     \$(cat /sys/class/rtc/rtc0/date) \$(cat /sys/class/rtc/rtc0/time) UTC"
ENDSSH

if [ $? -eq 0 ]; then
    echo "✅ Gotowe — czas ustawiony i zapisany do RTC"
else
    echo "❌ BŁĄD: Nie udało się ustawić czasu"
    exit 1
fi
