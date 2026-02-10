#!/usr/bin/env bash

################################################################################
# docker-purge.sh — Docker environment cleanup and optimization tool
# * Works with: curl -fsSL <url> | bash (using /dev/tty for input)
# * Works with: ./docker-purge.sh
# * Works with: bash docker-purge.sh
# * Supports: --no-confirm (Skip interactive prompts)
# * Supports: --force (Stop ALL running containers before purging)
################################################################################

# Configuration
readonly APP_NAME="DOCKER PURGE"
readonly GITHUB_URL="https://raw.githubusercontent.com/sam0rr/docker_purge/main/docker_purge.sh"

# Safe terminal tput command
_tput() { command -v tput >/dev/null 2>&1 && tput "$@" 2>/dev/null; }

# Initialize color variables
if [[ $(_tput colors) -ge 8 ]]; then
	readonly NC=$(_tput sgr0)
	readonly BOLD=$(_tput bold)

	# Regular Colors
	readonly Black="${NC}$(_tput setaf 0)"
	readonly Red="${NC}$(_tput setaf 1)"
	readonly Green="${NC}$(_tput setaf 2)"
	readonly Yellow="${NC}$(_tput setaf 3)"
	readonly Blue="${NC}$(_tput setaf 4)"
	readonly Purple="${NC}$(_tput setaf 5)"
	readonly Cyan="${NC}$(_tput setaf 6)"
	readonly White="${NC}$(_tput setaf 7)"

	# Bold Colors
	readonly BBlack="${NC}${BOLD}$(_tput setaf 0)"
	readonly BRed="${NC}${BOLD}$(_tput setaf 1)"
	readonly BGreen="${NC}${BOLD}$(_tput setaf 2)"
	readonly BYellow="${NC}${BOLD}$(_tput setaf 3)"
	readonly BBlue="${NC}${BOLD}$(_tput setaf 4)"
	readonly BPurple="${NC}${BOLD}$(_tput setaf 5)"
	readonly BCyan="${NC}${BOLD}$(_tput setaf 6)"
	readonly BWhite="${NC}${BOLD}$(_tput setaf 7)"

	# High Intensity Colors
	readonly IBlack="${NC}$(_tput setaf 8)"
	readonly IRed="${NC}$(_tput setaf 9)"
	readonly IGreen="${NC}$(_tput setaf 10)"
	readonly IYellow="${NC}$(_tput setaf 11)"
	readonly IBlue="${NC}$(_tput setaf 12)"
	readonly IPurple="${NC}$(_tput setaf 13)"
	readonly ICyan="${NC}$(_tput setaf 14)"
	readonly IWhite="${NC}$(_tput setaf 15)"

	# Bold High Intensity Colors
	readonly BIBlack="${NC}${BOLD}$(_tput setaf 8)"
	readonly BIRed="${NC}${BOLD}$(_tput setaf 9)"
	readonly BIGreen="${NC}${BOLD}$(_tput setaf 10)"
	readonly BIYellow="${NC}${BOLD}$(_tput setaf 11)"
	readonly BIBlue="${NC}${BOLD}$(_tput setaf 12)"
	readonly BIPurple="${NC}${BOLD}$(_tput setaf 13)"
	readonly BICyan="${NC}${BOLD}$(_tput setaf 14)"
	readonly BIWhite="${NC}${BOLD}$(_tput setaf 15)"
else
	# Fallback to no formatting if colors are not supported
	readonly NC='' BOLD=''
	readonly Black='' Red='' Green='' Yellow='' Blue='' Purple='' Cyan='' White=''
	readonly BBlack='' BRed='' BGreen='' BYellow='' BBlue='' BPurple='' BCyan='' BWhite=''
	readonly IBlack='' IRed='' IGreen='' IYellow='' IBlue='' IPurple='' ICyan='' IWhite=''
	readonly BIBlack='' BIRed='' BIGreen='' BIYellow='' BIBlue='' BIPurple='' BICyan='' BIWhite=''
fi

# Logging helpers
log() { echo -e "$(date '+%F %T') | ${*}" >&2; }
info() { echo -e "${IBlue}${*}${NC}" >&2; }
success() { echo -e "${BGreen}${*}${NC}" >&2; }
warning() { echo -e "${BYellow}${*}${NC}" >&2; }
error() { echo -e "\n${BRed}[ERROR] ${*}${NC}" >&2; }
fatal() {
	echo -e "\n${BIRed}[FATAL] ${*}${NC}" >&2
	exit 1
}
debug() { echo -e "\n${BIYellow}[DEBUG] ${*}${NC}" >&2; }

# Formatting helpers
title() { echo -e "${BICyan}${*}${NC}" >&2; }
subtitle() { echo -e "${BBlue}${*}${NC}" >&2; }
label() { echo -e "${IWhite}${*}${NC}"; }
newline() { printf '\n' >&2; }
header() {
	echo -e "${BIBlue}
  ###########################################################
  # "${@}"
  ###########################################################
  ${NC}" >&2
}
bullet() { echo -e "   ${Red}•${NC} ${IWhite}${*}${NC}" >&2; }
bullet_warn() { echo -e "   ${BIRed}• ${*}${NC}" >&2; }
option() { printf "  ${Cyan}%-18s${NC} ${IWhite}%s${NC}\n" "${1}" "${2}" >&2; }
key_value() { printf "   ${IWhite}%-18s${NC} %b\n" "${1}" "${2}" >&2; }

# Convert byte values into human-readable strings (KB, MB, GB, etc.)
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

# Validate required dependencies
validate_requirements() {
	if ! command -v docker >/dev/null 2>&1; then
		fatal "Docker is not installed. Please install Docker first."
	fi

	if ! docker info >/dev/null 2>&1; then
		fatal "Cannot connect to Docker daemon. Is it running?"
	fi
}

# Calculate the total disk usage of all Docker resources in bytes
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

# Ask for user confirmation
confirm_purge() {
	local no_confirm="${1}"
	local force_mode="${2}"

	if [[ "${no_confirm}" == "true" ]]; then
		info "Running in non-interactive mode (--no-confirm detected)"
		return 0
	fi

	newline
	warning "ATTENTION: This will permanently delete:"
	bullet "All stopped containers"
	bullet "All unused networks"
	bullet "All unused images"
	bullet "All build cache"
	bullet "All unused volumes"

	if [[ "${force_mode}" == "true" ]]; then
		newline
		bullet_warn "ALL RUNNING CONTAINERS WILL BE STOPPED (--force active)"
	fi
	newline

	while true; do
		printf "${BYellow}Do you want to proceed? (y/N): ${NC}" >&2
		read -r choice </dev/tty
		choice=$(echo "${choice}" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')

		if [[ "${choice}" == "y" ]]; then return 0; fi
		info "Purge cancelled by user."
		return 1
	done
}

# Perform Docker cleanup and pruning operations
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

# Display a summary report
display_summary() {
	local initial_raw="${1}"
	local final_raw="${2}"
	local saved_raw=$((initial_raw - final_raw))
	[[ ${saved_raw} -lt 0 ]] && saved_raw=0

	newline
	header "${APP_NAME} SUMMARY REPORT"

	subtitle "Space Analysis"
	key_value "Initial Usage" "$(format_bytes "${initial_raw}")"
	key_value "Final Usage" "$(format_bytes "${final_raw}")"
	key_value "Reclaimed Space" "${BGreen}$(format_bytes "${saved_raw}")${NC}"
	newline

	subtitle "Health Assessment"
	printf "   ${IWhite}%-18s${NC} " "Status" >&2
	success "Docker environment optimized and clean"
	newline
	subtitle "==========================================================="
}

# Display the application usage guide and help message
show_help() {
	header "${APP_NAME} — Usage Guide"
	subtitle "USAGE:"
	label "  docker-purge [OPTIONS]"
	newline
	subtitle "OPTIONS:"
	option "-h, --help" "Show this help message and exit"
	option "--no-confirm" "Skip interactive confirmation prompts"
	option "--force" "Stop all running containers before purging"
	newline
	subtitle "EXAMPLES:"
	info "# Standard interactive cleanup"
	label "  docker-purge"
	newline
	info "# Hard reset (Stop all and purge without asking)"
	label "  docker-purge --force --no-confirm"
	newline
	info "# Run directly from GitHub (Interactive)"
	label "  curl -fsSL ${GITHUB_URL} | bash"
	newline
	info "# Run directly from GitHub (With arguments)"
	label "  bash <(curl -fsSL ${GITHUB_URL}) --force --no-confirm"
	newline
}

# Parse command-line arguments and set flags
parse_args() {
	for arg in "${@}"; do
		case ${arg} in
		-h | --help)
			show_help
			exit 0
			;;
		--no-confirm) no_confirm=true ;;
		--force) force_mode=true ;;
		*)
			error "Unknown option: ${arg}"
			show_help
			exit 1
			;;
		esac
	done
}

# main
main() {
	no_confirm=false
	force_mode=false

	parse_args "${@}"

	newline
	header "${APP_NAME} - Optimization Tool"

	validate_requirements

	info "Analyzing Docker disk usage..."
	local initial_usage=$(get_docker_usage)

	if confirm_purge "${no_confirm}" "${force_mode}"; then
		newline
		perform_cleanup "${force_mode}"

		info "Analyzing final usage..."
		local final_usage=$(get_docker_usage)

		display_summary "${initial_usage}" "${final_usage}"
		success "Operation completed successfully"
	fi

	newline
	exit 0
}

# Trap & Execute
trap 'newline; warning "Process interrupted."; exit 1' INT

main "${@}"
