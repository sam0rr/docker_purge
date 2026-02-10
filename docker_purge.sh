#!/usr/bin/env bash

################################################################################
# DOCKER PURGE - Optimization and Cleanup Tool
#
# A bash script to analyze and reclaim Docker disk space.
#
# Author:  Samorr
# GitHub:  https://github.com/sam0rr/docker_purge
# License: MIT
# Version: 1.1.0
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/sam0rr/docker_purge/main/docker_purge.sh | bash -s -- [OPTIONS]
################################################################################

set -Eeuo pipefail

# Configuration
readonly APP_NAME="DOCKER PURGE"
readonly GITHUB_URL="https://raw.githubusercontent.com/sam0rr/docker_purge/main/docker_purge.sh"

# Safe terminal tput command
_tput() { command -v tput >/dev/null 2>&1 && tput "$@" 2>/dev/null; }

# Initialize color variables
# shellcheck disable=SC2155,SC2034
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
newline() { printf '\n' >&2; }
log() {
	printf "%s | %b" "$(date '+%F %T')" "${*}" >&2
	newline
}
info() {
	printf "%b%b%b" "${IBlue}" "${*}" "${NC}" >&2
	newline
}
success() {
	printf "%b%b%b" "${BGreen}" "${*}" "${NC}" >&2
	newline
}
warning() {
	printf "%b%b%b" "${BYellow}" "${*}" "${NC}" >&2
	newline
}
error() {
	printf "%b[ERROR] %b%b" "${BRed}" "${*}" "${NC}" >&2
	newline
}
fatal() {
	printf "%b[FATAL] %b%b" "${BIRed}" "${*}" "${NC}" >&2
	newline
	exit 1
}
debug() {
	printf "%b[DEBUG] %b%b" "${BIYellow}" "${*}" "${NC}" >&2
	newline
}

# Formatting helpers
title() {
	printf "%b%b%b" "${BBlue}" "${*}" "${NC}" >&2
	newline
}
subtitle() {
	printf "%b%b%b" "${BICyan}" "${*}" "${NC}" >&2
	newline
}
label() {
	printf "%b%b%b" "${IWhite}" "${*}" "${NC}" >&2
	newline
}
header() {
	printf "%b
  ###########################################################
  # %b%b%b
  ###########################################################
  %b" "${BIBlue}" "${BIWhite}" "${*}" "${BIBlue}" "${NC}" >&2
	newline
}
bullet() {
	printf "   %b•%b %b%b%b" "${Red}" "${NC}" "${IWhite}" "${*}" "${NC}" >&2
	newline
}
bullet_warn() {
	printf "   %b• %b%b" "${BIRed}" "${*}" "${NC}" >&2
	newline
}
option() {
	printf "  %b%-18s%b %b%s%b" "${Cyan}" "${1}" "${NC}" "${IWhite}" "${2}" "${NC}" >&2
	newline
}
key_value() {
	printf "   %b%-18s%b %b" "${IWhite}" "${1}" "${NC}" "${2}" >&2
	newline
}

# Display the application usage guide and help message
show_help() {
	header "${APP_NAME} — Usage Guide"
	title "USAGE:"
	label "  docker_purge [OPTIONS]"
	newline
	title "OPTIONS:"
	option "-h, --help" "Show this help message and exit"
	option "--no-confirm" "Skip interactive confirmation prompts"
	option "--force" "Stop all running containers before purging"
	newline
	title "EXAMPLES:"
	info "# Standard interactive cleanup"
	label "  docker_purge"
	newline
	info "# Hard reset (Stop all and purge without asking)"
	label "  docker_purge --force --no-confirm"
	newline
	info "# Run directly from GitHub (Interactive)"
	label "  curl -fsSL ${GITHUB_URL} | bash"
	newline
	info "# Run directly from GitHub (With arguments)"
	label "  curl -fsSL ${GITHUB_URL} | bash -s -- --force --no-confirm"
	newline
}

# Parse command-line arguments and set flags
parse_args() {
	for arg in "${@}"; do
		case "${arg}" in
		-h | --help)
			show_help
			exit 0
			;;
		--no-confirm) no_confirm=true ;;
		--force) force_mode=true ;;
		*)
			newline
			error "Unknown option: ${arg}"
			show_help
			exit 1
			;;
		esac
	done
}

# Validate required dependencies
validate_requirements() {
	if ! command -v docker >/dev/null 2>&1; then
		newline
		fatal "Docker is not installed. Please install Docker first."
	fi

	if ! docker info >/dev/null 2>&1; then
		newline
		fatal "Cannot connect to Docker daemon. Is it running?"
	fi
}

# Convert byte values into human-readable strings (KB, MB, GB, etc.)
format_bytes() {
	printf "%s" "${1}" | LC_ALL=C awk '{
		split("B KB MB GB TB PB", unit, " ");
		i=1;
		while($1>=1024 && i<6) {
			$1/=1024;
			i++;
		}
		printf "%.2f %s", $1, unit[i];
	}'
}

# Calculate the total disk usage of all Docker resources in bytes
get_docker_usage() {
	LC_ALL=C docker system df --format "{{.Size}}" | LC_ALL=C awk '
		function to_bytes(s,    n, m) {
			n = s; gsub(/[^0-9.]/, "", n)
			if (!n) return 0
			m = 1
			if (s ~ /[Tt][Ii]?[Bb]/) m = 1024^4
			else if (s ~ /[Gg][Ii]?[Bb]/) m = 1024^3
			else if (s ~ /[Mm][Ii]?[Bb]/) m = 1024^2
			else if (s ~ /[Kk][Ii]?[Bb]/) m = 1024^1
			return n * m
		}
		{ sum += to_bytes($0) }
		END { printf "%.0f", sum }
	'
}

# Ask for user confirmation
confirm_purge() {
	local no_confirm="${1}"
	local force_mode="${2}"

	if [[ "${no_confirm}" == "true" ]]; then
		newline
		warning "Running in non-interactive mode (--no-confirm detected)"
		return 0
	fi
	newline
	warning "ATTENTION: This will permanently delete:"
	newline
	if [[ "${force_mode}" == "true" ]]; then
		bullet_warn "ALL RUNNING CONTAINERS WILL BE STOPPED (--force active)"
	fi
	bullet "All stopped containers"
	bullet "All unused networks"
	bullet "All unused images"
	bullet "All build cache"
	bullet "All unused volumes"
	newline

	while true; do
		printf "%bDo you want to proceed? (y/N): %b" "${BYellow}" "${NC}" >&2
		read -r choice </dev/tty
		choice=$(printf "%s" "${choice}" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')

		case "${choice}" in
		y) return 0 ;;
		n | "")
			newline
			info "Purge cancelled by user."
			newline
			return 1
			;;
		*)
			newline
			error "Invalid choice: '${choice}'. Please enter 'y' or 'n'."
			newline
			;;
		esac
	done
}

# Perform Docker cleanup and pruning operations
perform_cleanup() {
	local force_mode="${1}"
	subtitle "Cleanup Operations"

	if [[ "${force_mode}" == "true" ]]; then
		local running_containers
		mapfile -t running_containers < <(docker ps -q)
		if [[ ${#running_containers[@]} -gt 0 ]]; then
			info "-> Stopping all running containers..."
			docker stop "${running_containers[@]}" >/dev/null
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
	[[ "${saved_raw}" -lt 0 ]] && saved_raw=0

	header "${APP_NAME} SUMMARY REPORT"

	subtitle "Space Analysis"
	key_value "Initial Usage" "$(format_bytes "${initial_raw}")"
	key_value "Final Usage" "$(format_bytes "${final_raw}")"
	key_value "Reclaimed Space" "${BGreen}$(format_bytes "${saved_raw}")${NC}"
	newline

	subtitle "Health Assessment"
	printf "   %b%-18s%b " "${IWhite}" "Status" "${NC}" >&2
	success "Docker environment optimized and clean"
	newline
}

# main
main() {
	local no_confirm=false
	local force_mode=false

	parse_args "${@}"

	header "${APP_NAME} - Optimization Tool"

	validate_requirements

	info "Analyzing Docker disk usage..."
	local initial_usage
	initial_usage=$(get_docker_usage)

	if confirm_purge "${no_confirm}" "${force_mode}"; then
		newline
		perform_cleanup "${force_mode}"

		newline
		info "Analyzing final usage..."
		local final_usage
		final_usage=$(get_docker_usage)

		display_summary "${initial_usage}" "${final_usage}"
		success "Operation completed successfully"
		newline
	fi

	exit 0
}

# Trap & Execute
trap 'newline; newline; warning "Process interrupted."; newline; exit 1' INT

main "${@}"
