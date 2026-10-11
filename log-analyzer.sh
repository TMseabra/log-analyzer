#!/usr/bin/env bash
#
# log-analyzer.sh - Summarize SSH activity from a Linux auth log.
#
# Shows failed login attempts, the IPs and usernames that tried most,
# successful logins, and the busiest days.
#
# Usage: ./log-analyzer.sh [-f LOGFILE] [-n TOP_N]
#
set -uo pipefail

VERSION="1.0.0"
LOG_FILE="/var/log/auth.log"
TOP_N=10

# Use colors only when writing to a terminal.
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  CYAN=$'\033[36m'
  RESET=$'\033[0m'
else
  BOLD="" RED="" GREEN="" YELLOW="" CYAN="" RESET=""
fi

usage() {
  cat <<EOF
log-analyzer $VERSION - summarize SSH activity from an auth log

Usage: $(basename "$0") [options]

Options:
  -f FILE   Log file to analyze (default: $LOG_FILE)
  -n NUM    How many entries to show in each top list (default: $TOP_N)
  -h        Show this help and exit
  -v        Show the version and exit

Examples:
  sudo ./log-analyzer.sh
  ./log-analyzer.sh -f samples/auth.log.sample -n 5
EOF
}

while getopts ":f:n:hv" opt; do
  case "$opt" in
    f) LOG_FILE="$OPTARG" ;;
    n) TOP_N="$OPTARG" ;;
    h) usage; exit 0 ;;
    v) echo "log-analyzer $VERSION"; exit 0 ;;
    :) echo "Error: option -$OPTARG requires an argument." >&2; exit 2 ;;
    \?) echo "Error: unknown option -$OPTARG" >&2; usage >&2; exit 2 ;;
  esac
done

if ! [[ "$TOP_N" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: -n must be a positive integer." >&2
  exit 2
fi

if [[ ! -e "$LOG_FILE" ]]; then
  echo "Error: log file not found: $LOG_FILE" >&2
  echo "Tip: on RHEL/Fedora/CentOS the file is /var/log/secure." >&2
  exit 1
fi

if [[ ! -r "$LOG_FILE" ]]; then
  echo "Error: cannot read $LOG_FILE (try running with sudo)." >&2
  exit 1
fi

section() {
  printf '\n%s%s%s\n' "$BOLD$CYAN" "$1" "$RESET"
}

# Print stdin, or "(none)" when there is nothing to show.
show_or_none() {
  local data
  data=$(cat)
  if [[ -z "$data" ]]; then
    echo "  (none)"
  else
    echo "$data"
  fi
}

failed=$(grep -c 'Failed password' "$LOG_FILE" || true)
invalid=$(grep -c 'Invalid user' "$LOG_FILE" || true)
accepted=$(grep -c 'Accepted ' "$LOG_FILE" || true)

printf '%sSSH log analysis%s - %s\n' "$BOLD" "$RESET" "$LOG_FILE"

section "Summary"
printf '  Failed passwords : %s%s%s\n' "$RED" "$failed" "$RESET"
printf '  Invalid users    : %s%s%s\n' "$YELLOW" "$invalid" "$RESET"
printf '  Accepted logins  : %s%s%s\n' "$GREEN" "$accepted" "$RESET"

section "Top $TOP_N IPs with failed logins"
grep 'Failed password' "$LOG_FILE" \
  | sed -nE 's/.* from ([0-9a-fA-F.:]+) port .*/\1/p' \
  | sort | uniq -c | sort -rn | head -n "$TOP_N" \
  | awk '{ printf "  %-6s %s\n", $1, $2 }' \
  | show_or_none

section "Top $TOP_N usernames tried"
grep 'Failed password' "$LOG_FILE" \
  | sed -nE 's/.*Failed password for (invalid user )?([^ ]+) from .*/\2/p' \
  | sort | uniq -c | sort -rn | head -n "$TOP_N" \
  | awk '{ printf "  %-6s %s\n", $1, $2 }' \
  | show_or_none

section "Successful logins (user from IP)"
grep 'Accepted ' "$LOG_FILE" \
  | sed -nE 's/.*Accepted [a-z-]+ for ([^ ]+) from ([0-9a-fA-F.:]+) port .*/\1 from \2/p' \
  | sort | uniq -c | sort -rn | head -n "$TOP_N" \
  | awk '{ c = $1; $1 = ""; sub(/^ /, ""); printf "  %-6s %s\n", c, $0 }' \
  | show_or_none

section "Failed logins per day"
grep 'Failed password' "$LOG_FILE" \
  | awk '{
      if ($1 ~ /^[0-9][0-9][0-9][0-9]-/) print substr($1, 1, 10)
      else print $1 " " $2
    }' \
  | sort | uniq -c | sort -rn | head -n "$TOP_N" \
  | awk '{ c = $1; $1 = ""; sub(/^ /, ""); printf "  %-6s %s\n", c, $0 }' \
  | show_or_none

echo
