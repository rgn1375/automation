# Recon automation

Automated subdomain reconnaissance tool untuk bug bounty dan penetration testing. Script ini mengotomasi proses subdomain enumeration menggunakan **subfinder**, deduplikasi dengan **anew**, dan filtering live hosts dengan **httpx**.

## Daftar isi

- [Fitur](#-fitur)
- [Struktur Direktori](#-struktur-direktori)
- [Setup Environment](#-setup-environment)
- [Cara Menjalankan](#-cara-menjalankan)
- [Contoh Input & Output](#-contoh-input--output)
- [Penjelasan Kode](#-penjelasan-kode)
- [Screenshot](#-screenshot)
- [Tools yang Digunakan](#-tools-yang-digunakan)

## Fitur

- Subdomain enumeration otomatis dengan subfinder
- Deduplikasi subdomain dengan anew
- Filter live hosts dengan httpx
- Logging dengan timestamp (progress & errors)
- Error handling yang proper
- Summary hasil recon

## Struktur direktori

```
recon-automation/
├── input/
│   └── domains.txt          # File input berisi daftar domain
├── output/
│   ├── all-subdomains.txt   # Semua subdomain unik
│   └── live.txt             # Hasil akhir: live hosts
├── scripts/
│   └── recon-auto.sh        # Script utama (executable)
├── logs/
│   ├── progress.log         # Log progress dengan timestamp
│   └── errors.log           # Log error
└── README.md                # Dokumentasi
```

## Setup environment

### Prerequisites

- Linux/macOS/WSL (Windows Subsystem for Linux)
- Go (Golang) versi 1.21+
- Git

### Instalasi Tools

#### Instal Golang

```bash
wget https://go.dev/dl/go1.25.7.linux-amd64.tar.gz    # Atau versi yang terbaru

# Ekstrak dengan nama yang BENAR
sudo tar -C /usr/local -xzf go1.25.7.linux-amd64.tar.gz

# Set PATH Go
export PATH=$PATH:/usr/local/go/bin

# Reload
source ~/.bashrc

# Check versi
go version
```

#### Opsi 1: Menggunakan PDTM (Recommended)

```bash
# Install pdtm (ProjectDiscovery Tool Manager)
go install -v github.com/projectdiscovery/pdtm/cmd/pdtm@latest

# Install semua tools ProjectDiscovery
pdtm -install-all

# Atau install tools spesifik
pdtm -install subfinder
pdtm -install httpx
```

#### Opsi 2: Install manual dengan Go (Pastikan Golang ada di versi yang terbaru)

```bash
# Install subfinder
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest

# Install anew
go install -v github.com/tomnomnom/anew@latest

# Install httpx
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
```

#### Opsi 3: Install dari source

```bash
# Subfinder
git clone https://github.com/projectdiscovery/subfinder.git
cd subfinder/v2/cmd/subfinder
go build .
sudo mv subfinder /usr/local/bin/

# Anew
git clone https://github.com/tomnomnom/anew.git
cd anew
go build .
sudo mv anew /usr/local/bin/

# Httpx
git clone https://github.com/projectdiscovery/httpx.git
cd httpx/cmd/httpx
go build .
sudo mv httpx /usr/local/bin/
```

### Verifikasi instalasi

```bash
subfinder -version
anew -h
httpx -version
```

### Fix PATH Go (Misalnya tools tidak ditemukan)

```bash
export GOPATH=$HOME/go

export PATH=$PATH:$GOPATH/bin

source ~/.bashrc

# Cek dengan command berikut:
which subfinder
which anew
which httpx

# Outputnya harus:
/home/{username}/go/bin/subfinder
/home/{username}/go/bin/anew
/home/{username}/go/bin/httpx
```

### Setup repository

```bash
# Clone repository
git clone https://github.com/rgn1375/automation.git
cd automation

# Beri permission executable pada script
chmod +x scripts/recon-auto.sh
```

## Cara menjalankan

### Basic usage

```bash
# Dari root direktori project
./scripts/recon-auto.sh
```

### Menjalankan dari direktori Manapun

```bash
# Menggunakan path absolut
/path/to/automation/scripts/recon-auto.sh

# Atau masuk ke direktori scripts
cd scripts && ./recon-auto.sh
```

### Menambah domain target

Edit file `input/domains.txt`:

```bash
nano input/domains.txt
```

Tambahkan domain (satu per baris):

```
hackerone.com
bugcrowd.com
example.com
```

## Contoh input & output

### Input (`input/domains.txt`)

```
hackerone.com
bugcrowd.com
intigriti.com
yeswehack.com
synack.com
```

### Output (`output/all-subdomains.txt`)

```
api.hackerone.com
www.hackerone.com
docs.hackerone.com
support.hackerone.com
tracker.bugcrowd.com
www.bugcrowd.com
app.intigriti.com
...
```

### Output (`output/live.txt`)

```
https://www.hackerone.com [200]
https://api.hackerone.com [302]
https://docs.hackerone.com [200]
https://www.bugcrowd.com [402]
https://tracker.bugcrowd.com [403]
...
```

### Log progress (`logs/progress.log`)

```
[2024-01-15 10:30:00] [INFO] Recon dimulai pada: 2024-01-15 10:30:00
[2024-01-15 10:30:00] [INFO] Memeriksa dependensi yang diperlukan...
[2024-01-15 10:30:01] [SUCCESS] Semua dependensi tersedia!
[2024-01-15 10:30:01] [INFO] Menyiapkan direktori...
[2024-01-15 10:30:01] [SUCCESS] Direktori siap!
[2024-01-15 10:30:01] [INFO] Memvalidasi file input...
[2024-01-15 10:30:01] [SUCCESS] Ditemukan 5 domain untuk di-scan
[2024-01-15 10:30:01] [INFO] Memulai subdomain enumeration dengan subfinder...
[2024-01-15 10:35:00] [SUCCESS] Total subdomain unik: 150
[2024-01-15 10:35:00] [INFO] Memeriksa live hosts dengan httpx...
[2024-01-15 10:40:00] [SUCCESS] Total live hosts: 85
[2024-01-15 10:40:00] [SUCCESS] Recon automation selesai!
```

## Penjelasan kode

### 1. Konfigurasi path

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
```

Menentukan path dinamis agar script bisa dijalankan dari direktori manapun.

### 2. Fungsi logging

```bash
log_progress() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${CYAN}[INFO]${NC} $message"
    echo "[$timestamp] [INFO] $message" | tee -a "$PROGRESS_LOG"
}
```

Mencatat progress ke terminal dan file log dengan timestamp menggunakan `tee`.

### 3. Dependency check

```bash
check_dependencies() {
    if ! command -v subfinder &> /dev/null; then
        missing_tools+=("subfinder")
    fi
    ...
}
```

Memastikan semua tools (subfinder, anew, httpx) sudah terinstall sebelum script berjalan.

### 4. Subdomain enumeration

```bash
subfinder -d "$domain" -silent 2>> "$ERROR_LOG" | tee -a "$temp_subs"
```

- Menjalankan subfinder untuk setiap domain
- Output di-redirect ke file temporary
- Error di-log ke `errors.log`

### 5. Deduplikasi dengan Anew

```bash
cat "$temp_subs" | anew "$ALL_SUBS" 2>> "$ERROR_LOG"
```

`anew` hanya menambahkan baris yang belum ada di file, sehingga menghasilkan subdomain unik.

### 6. Live host checking

```bash
cat "$ALL_SUBS" | httpx -silent -threads 50 -timeout 10 2>> "$ERROR_LOG" | anew "$LIVE_HOSTS"
```

- `httpx` memeriksa setiap subdomain apakah merespons
- Menggunakan 50 threads untuk kecepatan
- Timeout 10 detik per request

### 7. Error handling

```bash
2>> "$ERROR_LOG"  # Redirect stderr ke error log
```

Semua error di-redirect ke `logs/errors.log` untuk debugging.

### 8. Trap Ctrl+C

```bash
trap trap_ctrlc INT
```

Menangani interrupt signal untuk cleanup yang graceful.

## Screenshot

### Eksekusi script

```
[INFO] Recon dimulai pada: 2024-01-15 10:30:00
[INFO] Memeriksa dependensi yang diperlukan...
[SUCCESS] Semua dependensi tersedia!
[INFO] Menyiapkan direktori...
[SUCCESS] Direktori siap!
[INFO] Memvalidasi file input...
[SUCCESS] Ditemukan 5 domain untuk di-scan
[INFO] Memulai subdomain enumeration dengan subfinder...
[INFO] [1/5] Scanning: hackerone.com
  [+] api.hackerone.com
  [+] www.hackerone.com
  [+] docs.hackerone.com
...
```

### Hasil summary

```
========================================
           RECON SUMMARY               
========================================
Waktu selesai    : 2024-01-15 10:40:00
Total Subdomain  : 150
Live Hosts       : 85
----------------------------------------
Output Files:
  - Subdomains: /path/to/output/all-subdomains.txt
  - Live Hosts: /path/to/output/live.txt
----------------------------------------
Log Files:
  - Progress: /path/to/logs/progress.log
  - Errors  : /path/to/logs/errors.log
========================================
```

## 🔧 Tools yang digunakan

| Tool | Deskripsi | Repository |
|------|-----------|------------|
| **subfinder** | Fast subdomain enumeration tool | [ProjectDiscovery/subfinder](https://github.com/projectdiscovery/subfinder) |
| **anew** | Append new lines to file, skip duplicates | [tomnomnom/anew](https://github.com/tomnomnom/anew) |
| **httpx** | Fast HTTP probing tool | [ProjectDiscovery/httpx](https://github.com/projectdiscovery/httpx) |
