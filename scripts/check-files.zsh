#!/bin/zsh
 
set -euo pipefail
 
# URL base delle API Hedera
API_BASE="https://mainnet.mirrornode.hedera.com/api/v1"

GZIPPED_FILES_START_DATE="2022-09-27"
 
# Colori per l'output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
 
# Funzione di aiuto
usage() {
    echo "Uso: $0 <data> [directory_base]"
    echo "  data: formato YYYY-MM-DD (es. 2025-08-04)"
    echo "  directory_base: directory contenente le cartelle dei giorni (default: .)"
    echo ""
    echo "Esempi:"
    echo "  $0 2025-08-04"
    echo "  $0 2025-08-04 /path/to/blocks"
    exit 1
}
 
# Funzione per convertire data in timestamp Unix
date_to_timestamp() {
    local date_str="$1"
    local time_str="$2"

    # Test GNU date prima
    if date --version 2>/dev/null | grep -q GNU; then
        local result=$(date -d "${date_str}T${time_str}Z" +%s 2>/dev/null)
        if [[ -n "$result" && "$result" != "" ]]; then
            echo "$result"
            return 0
        fi
    fi
 
    # BSD/macOS date con UTC
    export TZ=UTC
    local result=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "${date_str}T${time_str}Z" +%s 2>/dev/null)
    unset TZ
    if [[ -n "$result" && "$result" != "" ]]; then
        echo "$result"
        return 0
    fi
 
    # Formato alternativo per macOS
    export TZ=UTC
    local result=$(date -j -u "${date_str:0:4}${date_str:5:2}${date_str:8:2}${time_str:0:2}${time_str:3:2}${time_str:6:2}" +%s 2>/dev/null)
    unset TZ
    if [[ -n "$result" && "$result" != "" ]]; then
        echo "$result"
        return 0
    fi
 
    # Calcolo manuale come fallback
    local year month day hour minute second
    IFS='-' read -r year month day <<< "$date_str"
    IFS=':' read -r hour minute second <<< "$time_str"
 
    # Rimuovi zero iniziali
    year=$((10#$year))
    month=$((10#$month))  
    day=$((10#$day))
    hour=$((10#$hour))
    minute=$((10#$minute))
    second=$((10#$second))
 
    # Calcolo giorni dall'epoca Unix
    local days=0
 
    # Anni completi
    for ((y=1970; y<year; y++)); do
        if [[ $((y % 4)) -eq 0 && ( $((y % 100)) -ne 0 || $((y % 400)) -eq 0 ) ]]; then
            days=$((days + 366))
        else
            days=$((days + 365))
        fi
    done
 
    # Mesi dell'anno corrente
    local days_in_month=(31 28 31 30 31 30 31 31 30 31 30 31)
    if [[ $((year % 4)) -eq 0 && ( $((year % 100)) -ne 0 || $((year % 400)) -eq 0 ) ]]; then
        days_in_month[1]=29
    fi
 
    for ((m=1; m<month; m++)); do
        days=$((days + days_in_month[m-1]))
    done
 
    days=$((days + day - 1))
 
    # Converti in timestamp Unix
    local timestamp=$((days * 86400 + hour * 3600 + minute * 60 + second))
    echo "$timestamp"
}
 
# Funzione per estrarre la data dal nome del file
extract_date_from_filename() {
    local filename="$1"
    echo "$filename" | sed -E 's/^([0-9]{4}-[0-9]{2}-[0-9]{2})T.*/\1/'
}
 
# Funzione per ottenere il numero di blocco tramite API
get_block_number() {
    local filename="$1"
 
    # Estrai timestamp dal nome del file (formato: YYYY-MM-DDTHH_mm_ss.ns.rcd or YYYY-MM-DDTHH_mm_ss.ns.rcd.gz)
    local timestamp_part=$(echo "$filename" | sed -E 's/^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}_[0-9]{2}_[0-9]{2})\..*/\1/' | tr '_' ':')
 
    # Converti in timestamp Unix
    local unix_timestamp=$(date_to_timestamp "${timestamp_part:0:10}" "${timestamp_part:11}")
 
    # Chiama l'API per ottenere i blocchi intorno a quel timestamp
    local response=$(curl -s "${API_BASE}/blocks?limit=1&timestamp=gte:${unix_timestamp}&order=asc")
 
    # Estrai il numero di blocco dal JSON
    echo "$response" | jq -r '.blocks[0].number // empty' 2>/dev/null || echo ""
}
 
# Funzione per ottenere informazioni sui blocchi in un range di timestamp
get_blocks_in_range() {
    local start_timestamp="$1"
    local end_timestamp="$2"
    local limit="${3:-1000}"
 
    curl -s "${API_BASE}/blocks?limit=${limit}&timestamp=gte:${start_timestamp}&timestamp=lt:${end_timestamp}&order=asc" | \
    jq -r '.blocks[] | "\(.number)|\(.name)"' 2>/dev/null || echo ""
}
 
# Funzione per trovare il primo e ultimo blocco del giorno tramite API
get_day_boundaries() {
    local date_str="$1"
 
    # Timestamp di inizio e fine giornata
    local start_timestamp=$(date_to_timestamp "$date_str" "00:00:00")
    local end_timestamp=$(date_to_timestamp "$date_str" "23:59:59")
    local next_day_start=$((end_timestamp + 1))
 
    # Trova il primo blocco del giorno
    local first_response=$(curl -s "${API_BASE}/blocks?limit=1&timestamp=gte:${start_timestamp}&timestamp=lt:${next_day_start}&order=asc")
    local first_block=$(echo "$first_response" | jq -r '.blocks[0].number // empty' 2>/dev/null)
    local first_filename=$(echo "$first_response" | jq -r '.blocks[0].name // empty' 2>/dev/null)
 
    # Trova l'ultimo blocco del giorno
    local last_response=$(curl -s "${API_BASE}/blocks?limit=1&timestamp=gte:${start_timestamp}&timestamp=lt:${next_day_start}&order=desc")
    local last_block=$(echo "$last_response" | jq -r '.blocks[0].number // empty' 2>/dev/null)
    local last_filename=$(echo "$last_response" | jq -r '.blocks[0].name // empty' 2>/dev/null)
 
    # Output solo su stdout
    echo "$first_block|$first_filename|$last_block|$last_filename"
}
 
# Funzione principale
main() {
    # Verifica parametri
    if [[ $# -lt 1 ]]; then
        usage
    fi
 
    local target_date="$1"
    local base_dir="${2:-.}"
    local day_dir="${base_dir}/${target_date}"
 
    # Verifica formato data
    if [[ ! "$target_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo -e "${RED}Errore: formato data non valido. Usa YYYY-MM-DD${NC}" >&2
        exit 1
    fi
 
    # Verifica che la directory esista
    if [[ ! -d "$day_dir" ]]; then
        echo -e "${RED}Errore: directory $day_dir non trovata${NC}" >&2
        exit 1
    fi
 
    # Verifica che jq sia installato
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${RED}Errore: jq non è installato. Installalo con: sudo apt install jq${NC}" >&2
        exit 1
    fi
    
    # Conta i file locali (inclusi quelli con estensione incompleta)
    local rcd=".rcd"
    if [[ "$target_date" > "$GZIPPED_FILES_START_DATE" ]]; then
        rcd=".rcd.gz"
    fi

    local local_files=($(find "$day_dir" -name "*$rcd" | grep -v sidecar | cut -d"/" -f5 | sort))
    local local_count=${#local_files[@]}
 
    echo -e "Local files: ${YELLOW}$local_count${NC} in ${YELLOW}$day_dir${NC}"

    if [[ $local_count -eq 0 ]]; then
        echo -e "${RED}Nessun file $rcd trovato nella directory${NC}"
        echo "$target_date # Nessun file $rcd trovato nella directory" >> skip
        exit 0
    fi

    # Verifica i duplicati
    echo -ne "Duplicates:  "
        
    duplicates=$(find "$day_dir" -name "*$rcd" | grep -v sidecar | cut -d"/" -f5 | sort | uniq -d)
    if [[ -n $duplicates ]]; then
	    echo "${RED}Yes"
        echo "$duplicates${NC}"
    else
       echo "${YELLOW}No${NC}"
    fi
 
    # Estrai il primo e ultimo file locale
    local first_local_file=$(basename "${local_files[1]}")
    local last_local_file=$(basename "${local_files[-1]}")
 
    echo -e "First:       ${YELLOW}$first_local_file${NC}"
    echo -e "Last:        ${YELLOW}$last_local_file${NC}"
 
    # Ottieni i confini del giorno dalle API
    local boundaries=$(get_day_boundaries "$target_date")
    IFS='|' read -r first_api_block first_api_filename last_api_block last_api_filename <<< "$boundaries"
 
    if [[ -z "$first_api_block" || -z "$last_api_block" ]]; then
        echo -e "${RED}Errore: impossibile ottenere i confini del giorno dalle API${NC}" >&2
        echo "$target_date # Mismatch with the first and last block file" >> skip
        exit 0
    fi
 
    # Calcola il numero reale di blocchi prodotti
    local actual_blocks_produced=$((last_api_block - first_api_block + 1))
 
    echo -e "Real blocks: ${YELLOW}$actual_blocks_produced${NC}"
    echo -e "First block: ${YELLOW}$first_api_block ($first_api_filename)${NC}"
    echo -e "Last block : ${YELLOW}$last_api_block ($last_api_filename)${NC}"
 
    # Verifica corrispondenza
    if [[ $local_count -eq $actual_blocks_produced ]]; then
        echo -e "${GREEN}✓ Il numero di file corrisponde ai blocchi reali prodotti${NC}"
 
        # Verifica aggiuntiva: confronta primo e ultimo file
        if [[ "$first_local_file" == "$first_api_filename" && "$last_local_file" == "$last_api_filename" ]]; then
            echo -e "${GREEN}✓ Primo e ultimo file corrispondono perfettamente${NC}"
            echo -e "${GREEN}✓ Tutti i blocchi sembrano essere stati scaricati correttamente${NC}"
            exit 0
        else
            echo -e "${YELLOW}⚠ ATTENZIONE: Primo o ultimo file non corrispondono${NC}"
            echo -e "${YELLOW}  API  : $first_api_filename → $last_api_filename${NC}"
            echo -e "${YELLOW}  Local: $first_local_file → $last_local_file${NC}"
            echo "$target_date # Mismatch with the first and last block file" >> skip
            exit 0
        fi
    else
        echo -e "${RED}✗ DISCREPANZA: Mancano $((actual_blocks_produced - local_count)) blocchi${NC}"
        echo "$target_date # Mismatch with the number of blocks" >> skip
        exit 0
    fi
}
 
# Esegui lo script
main "$@"
