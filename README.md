# Raspberry-Pi-offline-with-RTC

# DS3231 RTC on Raspberry Pi (no hwclock) / DS3231 RTC na Raspberry Pi (bez hwclock)

---

## English

### The problem

Some Raspberry Pi models (especially Zero WH running lightweight Raspbian) don't have `hwclock` installed, even though the `util-linux` package is present. This makes the standard DS3231 setup guides fail.

This guide shows how to read/write the DS3231 RTC using Python and `ioctl` directly — no extra packages needed, works fully offline.

### Hardware

- Raspberry Pi (tested on Zero WH)
- DS3231 RTC module
- CR2032 battery (insert **plus side up**)

**Wiring:**
```
DS3231    →    Raspberry Pi
VCC       →    Pin 1  (3.3V)
GND       →    Pin 6  (GND)
SDA       →    Pin 3  (GPIO2)
SCL       →    Pin 5  (GPIO3)
SQW, 32K  →    not connected
```

### Setup

**1. Enable I2C:**
```bash
sudo raspi-config
# Interface Options → I2C → Yes
```

**2. Add DS3231 overlay:**
```bash
echo "dtoverlay=i2c-rtc,ds3231" | sudo tee -a /boot/firmware/config.txt
sudo reboot
```

**3. Verify RTC is detected:**
```bash
ls /dev/rtc0          # should exist
cat /sys/class/rtc/rtc0/name  # should show: rtc-ds1307 1-0068
```

**4. Allow sudo python3 without password prompt**

This is required so the RTC sync works automatically without asking for a password:

```bash
sudo visudo
```

Add this line at the **end** of the file (replace `admin` with your username if different):

```
admin ALL=(ALL) NOPASSWD: /usr/bin/python3
```

Save with `Ctrl+X`, `Y`, `Enter`.

### Write system time to RTC

Run this after setting the correct system time:

```bash
sudo python3 - << 'PYEOF'
import fcntl, struct, time
RTC_SET_TIME = 0x4024700a
now = time.gmtime()
buf = struct.pack("8i", now.tm_sec, now.tm_min, now.tm_hour,
                  now.tm_mday, now.tm_mon - 1, now.tm_year - 1900,
                  now.tm_wday, now.tm_yday)
with open("/dev/rtc0", "wb") as f:
    fcntl.ioctl(f, RTC_SET_TIME, buf)
print("Time written to RTC")
PYEOF
```

### Read RTC and set system time

```bash
sudo python3 - << 'PYEOF'
import fcntl, struct, subprocess
RTC_RD_TIME = 0x80247009
with open("/dev/rtc0", "rb") as f:
    buf = bytearray(32)
    fcntl.ioctl(f, RTC_RD_TIME, buf)
s, m, h, d, mo, y = struct.unpack_from("6i", buf)
t = f"{1900+y}-{mo+1:02d}-{d:02d} {h:02d}:{m:02d}:{s:02d}"
print("RTC (UTC):", t)
subprocess.run(["date", "-u", "-s", t])
PYEOF
```

### Auto-sync on boot (systemd)

Create `/etc/systemd/system/rtc-sync.service`:

```ini
[Unit]
Description=Sync system time from DS3231 RTC
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/python3 -c "
import fcntl, struct, subprocess
RTC_RD_TIME = 0x80247009
with open(\"/dev/rtc0\",\"rb\") as f:
    buf=bytearray(32); fcntl.ioctl(f,RTC_RD_TIME,buf)
s,m,h,d,mo,y=struct.unpack_from(\"6i\",buf)
t=f\"{1900+y}-{mo+1:02d}-{d:02d} {h:02d}:{m:02d}:{s:02d}\"
subprocess.run([\"date\",\"-u\",\"-s\",t])
"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Enable it:
```bash
sudo systemctl enable rtc-sync
sudo systemctl start rtc-sync
```

### Verify

```bash
cat /sys/class/rtc/rtc0/time   # UTC time in RTC
cat /sys/class/rtc/rtc0/date   # date in RTC
date                            # system local time
```

---

## Polski

### Problem

Na niektórych modelach Raspberry Pi (szczególnie Zero WH z lekkim Raspbianem) polecenie `hwclock` nie jest dostępne, mimo że pakiet `util-linux` jest zainstalowany. Przez to standardowe poradniki konfiguracji DS3231 nie działają.

Ten poradnik pokazuje jak odczytywać i zapisywać czas do DS3231 przez Pythona i `ioctl` — bez dodatkowych pakietów, działa w pełni offline.

### Sprzęt

- Raspberry Pi (testowane na Zero WH)
- Moduł RTC DS3231
- Bateria CR2032 (włożyć **plusem do góry**)

**Podłączenie:**
```
DS3231    →    Raspberry Pi
VCC       →    Pin 1  (3.3V)
GND       →    Pin 6  (GND)
SDA       →    Pin 3  (GPIO2)
SCL       →    Pin 5  (GPIO3)
SQW, 32K  →    nie podłączać
```

### Konfiguracja

**1. Włącz I2C:**
```bash
sudo raspi-config
# Interface Options → I2C → Yes
```

**2. Dodaj overlay DS3231:**
```bash
echo "dtoverlay=i2c-rtc,ds3231" | sudo tee -a /boot/firmware/config.txt
sudo reboot
```

**3. Sprawdź czy RTC jest widoczny:**
```bash
ls /dev/rtc0
cat /sys/class/rtc/rtc0/name  # powinno pokazać: rtc-ds1307 1-0068
```

**4. Zezwól na sudo python3 bez hasła**

Wymagane żeby synchronizacja RTC działała automatycznie bez pytania o hasło:

```bash
sudo visudo
```

Dopisz na **końcu** pliku (zamień `admin` na swoją nazwę użytkownika jeśli inna):

```
admin ALL=(ALL) NOPASSWD: /usr/bin/python3
```

Zapisz przez `Ctrl+X`, `Y`, `Enter`.

### Zapis czasu systemowego do RTC

Uruchom po ustawieniu poprawnego czasu systemowego:

```bash
sudo python3 - << 'PYEOF'
import fcntl, struct, time
RTC_SET_TIME = 0x4024700a
now = time.gmtime()
buf = struct.pack("8i", now.tm_sec, now.tm_min, now.tm_hour,
                  now.tm_mday, now.tm_mon - 1, now.tm_year - 1900,
                  now.tm_wday, now.tm_yday)
with open("/dev/rtc0", "wb") as f:
    fcntl.ioctl(f, RTC_SET_TIME, buf)
print("Zapisano czas do RTC")
PYEOF
```

### Odczyt z RTC i ustawienie czasu systemowego

```bash
sudo python3 - << 'PYEOF'
import fcntl, struct, subprocess
RTC_RD_TIME = 0x80247009
with open("/dev/rtc0", "rb") as f:
    buf = bytearray(32)
    fcntl.ioctl(f, RTC_RD_TIME, buf)
s, m, h, d, mo, y = struct.unpack_from("6i", buf)
t = f"{1900+y}-{mo+1:02d}-{d:02d} {h:02d}:{m:02d}:{s:02d}"
print("RTC (UTC):", t)
subprocess.run(["date", "-u", "-s", t])
PYEOF
```

### Automatyczna synchronizacja przy starcie (systemd)

Utwórz `/etc/systemd/system/rtc-sync.service`:

```ini
[Unit]
Description=Synchronizacja czasu z RTC DS3231
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/python3 -c "
import fcntl, struct, subprocess
RTC_RD_TIME = 0x80247009
with open(\"/dev/rtc0\",\"rb\") as f:
    buf=bytearray(32); fcntl.ioctl(f,RTC_RD_TIME,buf)
s,m,h,d,mo,y=struct.unpack_from(\"6i\",buf)
t=f\"{1900+y}-{mo+1:02d}-{d:02d} {h:02d}:{m:02d}:{s:02d}\"
subprocess.run([\"date\",\"-u\",\"-s\",t])
"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Włącz:
```bash
sudo systemctl enable rtc-sync
sudo systemctl start rtc-sync
```

### Weryfikacja

```bash
cat /sys/class/rtc/rtc0/time   # czas UTC w RTC
cat /sys/class/rtc/rtc0/date   # data w RTC
date                            # czas systemowy (lokalny)
```