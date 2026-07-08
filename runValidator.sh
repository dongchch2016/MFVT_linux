#!/usr/bin/env bash
# Entry point for MFVT Linux Validator (with safe fallback for output/log dirs)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export MFVT_HOME="$SCRIPT_DIR"
export PATH="$MFVT_HOME/bin:$PATH"

# Load helpers (if present)
# shellcheck source=/dev/null
. "$MFVT_HOME/bin/config.sh" 2>/dev/null || true
# shellcheck source=/dev/null
. "$MFVT_HOME/bin/common.sh" 2>/dev/null || true
# shellcheck source=/dev/null
. "$MFVT_HOME/bin/logger.sh" 2>/dev/null || true
# shellcheck source=/dev/null
. "$MFVT_HOME/bin/signal.sh" 2>/dev/null || true
# shellcheck source=/dev/null
. "$MFVT_HOME/bin/help.sh" 2>/dev/null || true

# Trap signals (SIGINT/SIGTERM) for graceful shutdown
if type setup_traps >/dev/null 2>&1; then
  setup_traps
fi

# Ensure some project-local runtime directories exist
mkdir -p "$MFVT_HOME/logs" "$MFVT_HOME/output" "$MFVT_HOME/lib" "$MFVT_HOME/menus" "$MFVT_HOME/systems" 2>/dev/null || true

# Default property file (can pass another as arg)
PROPERTY_FILE="${1:-$MFVT_HOME/validator.properties}"

# If user asked for help on CLI, show help
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  if type show_help >/dev/null 2>&1; then
    show_help
  else
    echo "Usage: $0 [path/to/validator.properties]"
  fi
  exit 0
fi

if [ ! -f "$PROPERTY_FILE" ]; then
  echo "ERROR: Property file not found: $PROPERTY_FILE"
  echo "You can use the sample at sample_data/validator.properties or pass a path: $0 /path/to/validator.properties"
  exit 1
fi

# Determine configured dirs with safe defaults
LOG_DIR="$(get_property "$PROPERTY_FILE" "log.path" "$MFVT_HOME/logs")"
OUTPUT_DIR="$(get_property "$PROPERTY_FILE" "output.path" "$MFVT_HOME/output")"

# Try to create configured dirs; if not possible, fall back to project-local dirs
if mkdir -p "$LOG_DIR" "$OUTPUT_DIR" 2>/dev/null; then
  :
else
  echo "Warning: cannot create configured output/log dirs ($OUTPUT_DIR, $LOG_DIR). Falling back to project-local dirs."
  LOG_DIR="$MFVT_HOME/logs"
  OUTPUT_DIR="$MFVT_HOME/output"
  mkdir -p "$LOG_DIR" "$OUTPUT_DIR" 2>/dev/null || true
fi

LOGFILE="$LOG_DIR/validator_$(date +%Y%m%d_%H%M%S).log"

if type log_start >/dev/null 2>&1; then
  log_start "$LOGFILE" "MFVT Linux Validator"
  log_info "$LOGFILE" "Using properties: $PROPERTY_FILE"
else
  echo "Starting MFVT Linux Validator -- logs: $LOGFILE"
fi

# Load menu engine and start main menu (if present)
# shellcheck source=/dev/null
if [ -f "$MFVT_HOME/menu.sh" ]; then
  . "$MFVT_HOME/menu.sh"
  if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    if type show_help >/dev/null 2>&1; then
      show_help
    fi
    exit 0
  fi
  if type main_menu >/dev/null 2>&1; then
    main_menu "$PROPERTY_FILE" "$LOGFILE"
  else
    echo "menu.sh found but main_menu() not defined."
  fi
else
  echo "No menu engine (menu.sh) found in $MFVT_HOME. Exiting."
fi

if type log_end >/dev/null 2>&1; then
  log_end "$LOGFILE" "MFVT Linux Validator"
else
  echo "Finished. Log saved to $LOGFILE"
fi
