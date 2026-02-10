#!/usr/bin/env bash

###############################################################################
# docker-purge.sh — Docker environment cleanup and optimization tool
# • Works with: curl -fsSL <url> | bash (using /dev/tty for input)
# • Works with: ./docker-purge.sh
# • Works with: bash docker-purge.sh
# • Supports: --no-confirm (Skip interactive prompts)
# • Supports: --force (Stop ALL running containers before purging)
###############################################################################

# ── Color definitions ─────────────────────────────────────────────────────────
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m'

# ── Logging utility ───────────────────────────────────────────────────────────
log()     { echo -e "$(date '+%F %T') | ${*}" >&2; }
info()    { echo -e "${BLUE}${*}${NC}" >&2; }
success() { echo -e "${GREEN}${*}${NC}" >&2; }
warning() { echo -e "${YELLOW}${*}${NC}" >&2; }
error()   { echo -e "${RED}${*}${NC}" >&2; }
title()   { echo -e "${BOLD}${CYAN}${*}${NC}" >&2; }
subtitle(){ echo -e "${BOLD}${BLUE}${*}${NC}" >&2; }
label() { echo -e "${DIM}${*}${NC}"; }
newline() { printf '\n' >&2; }

# ── Format Bytes to Human Readable (Dependency-Free) ──────────────────────────
format_bytes() {
    echo "${1}" | awk '{
        split("B KB MB GB TB PB", unit, " ");
        i=1;
        while($1>=1024 && i<6) {
            $1/=1024;
            i++;
        }
        printf "%.2f %s", $1, unit[i];
    }'
}

# ── Display Help Message ──────────────────────────────────────────────────────
show_help() {
    title "DOCKER PURGE — Usage Guide"
    newline
    printf "${BOLD}USAGE:${NC}\n"
    printf "  docker-purge [OPTIONS]\n"
    newline
    printf "${BOLD}OPTIONS:${NC}\n"
    printf "  ${CYAN}-h, --help${NC}         Show this help message and exit\n"
    printf "  ${CYAN}--no-confirm${NC}      Skip interactive confirmation prompts\n"
    printf "  ${CYAN}--force${NC}           Stop all running containers before purging\n"
    newline
    printf "${BOLD}EXAMPLES:${NC}\n"
    printf "  ${DIM}# Standard interactive cleanup${NC}\n"
    printf "  docker-purge\n"
    newline
    printf "  ${DIM}# Hard reset (Stop all and purge without asking)${NC}\n"
    printf "  docker-purge --force --no-confirm\n"
    newline
    printf "  ${DIM}# Run via curl (piped)${NC}\n"
    printf "  curl -fsSL https://raw.githubusercontent.com/sam0rr/DOCKER-PURGE/main/docker_purge.sh | bash\n"
    newline
}

# ── Validate system requirements ──────────────────────────────────────────────
validate_requirements() {
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker is not installed. Please install Docker first."
        exit 1
    fi

    if ! docker info >/dev/null 2>&1; then
        error "Cannot connect to Docker daemon. Is it running?"
        exit 1
    fi
}

# ── Get Docker Disk Usage ─────────────────────────────────────────────────────
get_docker_usage() {
    docker system df --format "{{.Size}}" | awk '
        function to_bytes(s) {
            mult=1
            if (s ~ /[Gg][Bb]/) mult=1024*1024*1024
            else if (s ~ /[Mm][Bb]/) mult=1024*1024
            else if (s ~ /[Kk][Bb]/) mult=1024
            gsub(/[A-Za-z]/, "", s)
            return s * mult
        }
        { sum += to_bytes($1) }
        END { printf "%.0f", sum }
    '
}

# ── Confirm Purge Operation ───────────────────────────────────────────────────
confirm_purge() {
    local no_confirm="${1}"
    local force_mode="${2}"
    
    if [[ "${no_confirm}" == "true" ]]; then
        info "Running in non-interactive mode (--no-confirm detected)"
        return 0
    fi

    newline
    warning "ATTENTION: This will permanently delete:"
    echo -e "   ${RED}•${NC} All stopped containers"
    echo -e "   ${RED}•${NC} All unused networks"
    echo -e "   ${RED}•${NC} All unused images"
    echo -e "   ${RED}•${NC} All build cache"
    echo -e "   ${RED}•${NC} All unused volumes"
    
    if [[ "${force_mode}" == "true" ]]; then
        echo -e "   ${RED}${BOLD}• ALL RUNNING CONTAINERS WILL BE STOPPED (--force active)${NC}"
    fi
    newline
    
    while true; do
        echo -n -e "${BOLD}${YELLOW}Do you want to proceed? (y/N): ${NC}" >&2
        read -r choice < /dev/tty
        choice=$(echo "${choice}" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')

        if [[ "${choice}" == "y" ]]; then return 0; fi
        info "Purge cancelled by user."; return 1
    done
}

# ── Execute Purge Steps ───────────────────────────────────────────────────────
perform_cleanup() {
    local force_mode="${1}"
    subtitle "Cleanup Operations"
    
    if [[ "${force_mode}" == "true" ]]; then
        local running_containers
        running_containers=$(docker ps -q)
        if [[ -n "${running_containers}" ]]; then
            info "-> Stopping all running containers..."
            # shellcheck disable=SC2086
            docker stop ${running_containers} >/dev/null
        else
            info "-> No containers running."
        fi
    fi

    info "-> Pruning build cache..."
    docker builder prune --all --force >/dev/null
    
    info "-> Pruning containers..."
    docker container prune --force >/dev/null
    
    info "-> Pruning all images..."
    docker image prune --all --force >/dev/null
    
    info "-> Pruning all volumes..."
    docker volume prune --all --force >/dev/null
    
    info "-> Final system-wide deep prune..."
    docker system prune --all --volumes --force >/dev/null
}

# ── Display Summary Report ────────────────────────────────────────────────────
display_summary() {
    local initial_raw="${1}"
    local final_raw="${2}"
    local saved_raw=$(( initial_raw - final_raw ))
    [[ ${saved_raw} -lt 0 ]] && saved_raw=0

    newline
    title "==============================================================================="
    title "DOCKER PURGE SUMMARY REPORT"
    title "==============================================================================="
    newline
    
    subtitle "Space Analysis"
    echo -e "   $(label 'Initial Usage   :') $(format_bytes "${initial_raw}")"
    echo -e "   $(label 'Final Usage     :') $(format_bytes "${final_raw}")"
    echo -e "   $(label 'Reclaimed Space :') ${GREEN}${BOLD}$(format_bytes "${saved_raw}")${NC}"
    newline
    
    subtitle "Health Assessment"
    printf "   $(label 'Status          :') "
    success "Docker environment optimized and clean"
    newline
    title "==============================================================================="
}

# ── Main execution flow ───────────────────────────────────────────────────────
main() {
    local no_confirm=false
    local force_mode=false
    
    for arg in "${@}"; do
        case ${arg} in
            -h|--help)    show_help; exit 0 ;;
            --no-confirm) no_confirm=true ;;
            --force)      force_mode=true ;;
            *)            error "Unknown option: ${arg}"; show_help; exit 1 ;;
        esac
    done

    newline
    title "Docker System Purge - Optimization Tool"
    newline
    
    validate_requirements
    
    info "Analyzing Docker disk usage..."
    local initial_usage=$(get_docker_usage)
    
    if confirm_purge "${no_confirm}" "${force_mode}"; then
        newline
        perform_cleanup "${force_mode}"
        
        info "Analyzing final usage..."
        local final_usage=$(get_docker_usage)
        
        display_summary "${initial_usage}" "${final_usage}"
        success "Operation completed successfully!"
    fi

    newline
    exit 0
}

trap 'newline; warning "Process interrupted."; exit 1' INT

main "${@}"
