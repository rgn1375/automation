#!/bin/bash

# Path configuration - dinamis agar script bisa dijalankan dari direktori manapun
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
INPUT_FILE="$BASE_DIR/input/domains.txt"
OUTPUT_DIR="$BASE_DIR/output"
LOGS_DIR="$BASE_DIR/logs"
ALL_SUBS="$OUTPUT_DIR/all-subdomains.txt"
LIVE_HOSTS="$OUTPUT_DIR/live.txt"
PROGRESS_LOG="$LOGS_DIR/progress.log"
ERROR_LOG="$LOGS_DIR/errors.log"

# Color codes untuk output terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions - mencatat progress dan error dengan timestamp
log_progress() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [INFO] $message" | tee -a "$PROGRESS_LOG"
}

log_success() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [SUCCESS] $message" | tee -a "$PROGRESS_LOG"
}

log_warning() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [WARNING] $message" | tee -a "$PROGRESS_LOG"
}

log_error() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [ERROR] $message" | tee -a "$ERROR_LOG"
}

# Cek apakah tools yang diperlukan (subfinder, anew, httpx) sudah terinstall
check_dependencies() {
    log_progress "Memeriksa dependensi yang diperlukan..."
    
    local missing_tools=()
    
    if ! command -v subfinder &> /dev/null; then
        missing_tools+=("subfinder")
    fi
    
    if ! command -v anew &> /dev/null; then
        missing_tools+=("anew")
    fi
    
    if ! command -v httpx &> /dev/null; then
        missing_tools+=("httpx")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Tool berikut tidak ditemukan: ${missing_tools[*]}"
        echo -e "${YELLOW}Silakan install menggunakan:${NC}"
        echo "  go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
        echo "  go install -v github.com/tomnomnom/anew@latest"
        echo "  go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest"
        echo ""
        echo "Atau gunakan pdtm (ProjectDiscovery Tool Manager):"
        echo "  go install -v github.com/projectdiscovery/pdtm/cmd/pdtm@latest"
        echo "  pdtm -install-all"
        exit 1
    fi
    
    log_success "Semua dependensi tersedia!"
}

# Buat direktori output dan logs, reset file output
setup_directories() {
    log_progress "Menyiapkan direktori..."
    
    mkdir -p "$OUTPUT_DIR" 2>> "$ERROR_LOG"
    mkdir -p "$LOGS_DIR" 2>> "$ERROR_LOG"
    
    > "$ALL_SUBS"
    > "$LIVE_HOSTS"
    
    log_success "Direktori siap!"
}

# Validasi file input domains.txt - cek apakah ada dan tidak kosong
validate_input() {
    log_progress "Memvalidasi file input..."
    
    if [ ! -f "$INPUT_FILE" ]; then
        log_error "File input tidak ditemukan: $INPUT_FILE"
        exit 1
    fi
    
    if [ ! -s "$INPUT_FILE" ]; then
        log_error "File input kosong: $INPUT_FILE"
        exit 1
    fi
    
    local domain_count=$(wc -l < "$INPUT_FILE" | tr -d ' ')
    log_success "Ditemukan $domain_count domain untuk di-scan"
}

# Enumerasi subdomain menggunakan subfinder, lalu deduplikasi dengan anew
run_subdomain_enum() {
    log_progress "Memulai subdomain enumeration dengan subfinder..."
    
    local total_domains=$(wc -l < "$INPUT_FILE" | tr -d ' ')
    local current=0
    local temp_subs="$OUTPUT_DIR/temp_subs.txt"
    
    > "$temp_subs"
    
    # Loop setiap domain di input file
    while IFS= read -r domain || [ -n "$domain" ]; do
        [[ -z "$domain" || "$domain" =~ ^# ]] && continue
        
        ((current++))
        log_progress "[$current/$total_domains] Scanning: $domain"
        
        subfinder -d "$domain" -silent 2>> "$ERROR_LOG" | tee -a "$temp_subs" | while read -r sub; do
            echo -e "${BLUE}  [+]${NC} $sub"
        done
        
        if [ ${PIPESTATUS[0]} -ne 0 ]; then
            log_warning "Subfinder mengalami masalah pada domain: $domain"
        fi
        
    done < "$INPUT_FILE"
    
    # Deduplikasi dengan anew - hanya tambahkan subdomain unik
    log_progress "Menghilangkan duplikasi dengan anew..."
    cat "$temp_subs" | anew "$ALL_SUBS" 2>> "$ERROR_LOG"
    
    rm -f "$temp_subs"
    
    local unique_count=$(wc -l < "$ALL_SUBS" | tr -d ' ')
    log_success "Total subdomain unik: $unique_count"
}

# Cek subdomain mana yang live menggunakan httpx (50 threads, timeout 10s)
check_live_hosts() {
    log_progress "Memeriksa live hosts dengan httpx..."
    
    if [ ! -s "$ALL_SUBS" ]; then
        log_warning "Tidak ada subdomain untuk diperiksa"
        return
    fi
    
    cat "$ALL_SUBS" | httpx -silent -nc -threads 50 -timeout 10 -status-code -title 2>> "$ERROR_LOG" | anew "$LIVE_HOSTS" | while read -r live; do
        echo -e "${GREEN}  [LIVE]${NC} $live"
    done
    
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        log_warning "httpx mengalami beberapa error (lihat errors.log)"
    fi
    
    local live_count=$(wc -l < "$LIVE_HOSTS" | tr -d ' ')
    log_success "Total live hosts: $live_count"
}

# Tampilkan ringkasan hasil recon
print_summary() {
    local end_time=$(date '+%Y-%m-%d %H:%M:%S')
    local unique_subs=$(wc -l < "$ALL_SUBS" | tr -d ' ')
    local live_hosts=$(wc -l < "$LIVE_HOSTS" | tr -d ' ')
    
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}           RECON SUMMARY               ${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "${GREEN}Waktu selesai    :${NC} $end_time"
    echo -e "${GREEN}Total Subdomain  :${NC} $unique_subs"
    echo -e "${GREEN}Live Hosts       :${NC} $live_hosts"
    echo -e "${CYAN}----------------------------------------${NC}"
    echo -e "${GREEN}Output Files:${NC}"
    echo -e "  - Subdomains: $ALL_SUBS"
    echo -e "  - Live Hosts: $LIVE_HOSTS"
    echo -e "${CYAN}----------------------------------------${NC}"
    echo -e "${GREEN}Log Files:${NC}"
    echo -e "  - Progress: $PROGRESS_LOG"
    echo -e "  - Errors  : $ERROR_LOG"
    echo -e "${CYAN}========================================${NC}"
    
    log_progress "Recon selesai - Subdomain: $unique_subs, Live: $live_hosts"
}

# Hapus file temporary
cleanup() {
    log_progress "Membersihkan file temporary..."
    rm -f "$OUTPUT_DIR/temp_*.txt" 2>/dev/null
}

# Handler untuk Ctrl+C - cleanup gracefully
trap_ctrlc() {
    echo ""
    log_warning "Script dihentikan oleh user (Ctrl+C)"
    cleanup
    exit 1
}

trap trap_ctrlc INT

# Main function - orchestrate seluruh proses recon
main() {
    local start_time=$(date '+%Y-%m-%d %H:%M:%S')
    
    mkdir -p "$LOGS_DIR"
    > "$PROGRESS_LOG"
    > "$ERROR_LOG"
    
    log_progress "Recon dimulai pada: $start_time"
    
    check_dependencies
    setup_directories
    validate_input
    run_subdomain_enum
    check_live_hosts
    cleanup
    print_summary
    
    log_success "Recon automation selesai!"
}

main "$@"