#!/usr/bin/env bash
# Menu engine: reads simple INI-like menu files in menus/ and presents interactive menus.
# Extended to support explicit input-property mapping: command:inputProperty=Label
# and to pass the resolved input-file path to the Java wrapper.
set -euo pipefail

# shellcheck source=/dev/null
. "$MFVT_HOME/bin/common.sh"
# shellcheck source=/dev/null
. "$MFVT_HOME/bin/logger.sh"
# shellcheck source=/dev/null
. "$MFVT_HOME/bin/java.sh"

# Infer which properties key contains the input file for a given command name.
# Returns the property key (e.g., "marcBib", "marcHolding", "items", "patrons", "loans", "vendors")
infer_input_key_from_cmd() {
  local cmd="$1"
  # Normalize command to lowercase for matching
  local lcmd
  lcmd="$(echo "$cmd" | tr '[:upper:]' '[:lower:]')"

  case "$lcmd" in
    *marcbib*|*bib*) echo "marcBib" ;;
    *marcholding*|*holding*) echo "marcHolding" ;;
    *items*|*item*) echo "items" ;;
    *patron*|*patrons*) echo "patrons" ;;
    *loan*|*loans*) echo "loans" ;;
    *vendor*|*vendors*) echo "vendors" ;;
    *) echo "" ;;  # unknown; no input file passed
  esac
}

# Parse a menu line of the form key[:inputProp]=Label
parse_menu_line() {
  local line="$1"
  local key_part
  local label
  key_part="${line%%=*}"
  label="${line#*=}"
  local key
  local input_prop
  if [[ "$key_part" == *":"* ]]; then
    key="${key_part%%:*}"
    input_prop="${key_part#*:}"
  else
    key="$key_part"
    input_prop=""
  fi
  printf "%s\n" "$key|$input_prop|$label"
}

# show_system_menu <system> <propfile> <logfile>
show_system_menu() {
  local system="$1"; shift
  local propfile="${1:-$MFVT_HOME/validator.properties}"; shift || true
  local logfile="${1:-$MFVT_HOME/logs/validator.log}"; shift || true

  # Normalize system name to a safe filename (lowercase, spaces -> underscores)
  local sys_basename="${system// /_}"
  local sys_lower
  sys_lower="$(echo "$sys_basename" | tr '[:upper:]' '[:lower:]')"

  local fname="$MFVT_HOME/menus/${sys_lower}.menu"
  # If a menu file exists with original capitalization, prefer it
  if [ ! -f "$fname" ] && [ -f "$MFVT_HOME/menus/${sys_basename}.menu" ]; then
    fname="$MFVT_HOME/menus/${sys_basename}.menu"
  fi

  if [ ! -f "$fname" ]; then
    # fallback to existing systems script if present (try lowercase then original)
    if [ -x "$MFVT_HOME/systems/${sys_lower}.sh" ] || [ -f "$MFVT_HOME/systems/${sys_lower}.sh" ]; then
      # shellcheck source=/dev/null
      . "$MFVT_HOME/systems/${sys_lower}.sh"
      local func="${sys_lower}_menu"
      # call the menu function if defined
      if type "$func" >/dev/null 2>&1; then
        "$func" "$propfile" "$logfile"
        return
      fi
    elif [ -x "$MFVT_HOME/systems/${sys_basename}.sh" ] || [ -f "$MFVT_HOME/systems/${sys_basename}.sh" ]; then
      # shellcheck source=/dev/null
      . "$MFVT_HOME/systems/${sys_basename}.sh"
      local func="${sys_basename}_menu"
      if type "$func" >/dev/null 2>&1; then
        "$func" "$propfile" "$logfile"
        return
      fi
    fi
    echo "Menu definition not found for '$system' (tried $fname)."
    pause || true
    return 1
  fi

  # Parse menu file
  local -a CMDS=()
  local -a INPMAP=()
  local -a LABELS=()
  local -a SECTIONS=()
  local current_section=""
  while IFS= read -r line || [ -n "$line" ]; do
    # Trim whitespace
    line="$(echo "$line" | sed -e 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -z "$line" ] && continue
    case "$line" in
      \#*) continue ;; # comment
      \[*\])
        current_section="${line#[}"
        current_section="${current_section%]}"
        continue
        ;;
      *=*)
        # parse the key[:inputProp]=Label form
        local parsed
        parsed="$(parse_menu_line "$line")"
        local key
        local input_prop
        local label
        key="${parsed%%|*}"
        rest="${parsed#*|}"
        input_prop="${rest%%|*}"
        label="${rest#*|}"
        CMDS+=("$key")
        INPMAP+=("$input_prop")
        LABELS+=("$label")
        SECTIONS+=("$current_section")
        ;;
      *)
        continue
        ;;
    esac
  done <"$fname"

  # Interactive loop
  while true; do
    clear
    if type draw_header >/dev/null 2>&1; then
      draw_header "System: $system"
    else
      echo "System: $system"
      echo "----------------"
    fi
    local last_section=""
    local i=0
    for idx in "${!CMDS[@]}"; do
      i=$((idx + 1))
      local sec="${SECTIONS[$idx]}"
      if [ "$sec" != "$last_section" ]; then
        printf "\n%s\n" "$sec"
        last_section="$sec"
      fi
      printf "%2d) %s\n" "$i" "${LABELS[$idx]}"
    done
    printf "\n 0) Back\n\n"
    read -r -p "Choice: " choice
    if [[ ! "$choice" =~ ^[0-9]+$ ]]; then
      echo "Invalid input"
      sleep 1
      continue
    fi
    if [ "$choice" -eq 0 ]; then
      break
    fi
    if [ "$choice" -lt 1 ] || [ "$choice" -gt "${#CMDS[@]}" ]; then
      echo "Choice out of range"
      sleep 1
      continue
    fi
    local sel_index=$((choice - 1))
    local sel_cmd="${CMDS[$sel_index]}"
    local sel_label="${LABELS[$sel_index]}"
    local explicit_input_prop="${INPMAP[$sel_index]}"

    # Determine input property key: explicit mapping preferred, else inference
    local input_prop_key
    if [ -n "$explicit_input_prop" ]; then
      input_prop_key="$explicit_input_prop"
    else
      input_prop_key="$(infer_input_key_from_cmd "$sel_cmd")"
    fi

    local input_file=""
    if [ -n "$input_prop_key" ]; then
      input_file="$(get_property "$propfile" "$input_prop_key" "")"
    fi

    if [ -n "$input_prop_key" ] && [ -z "$input_file" ]; then
      echo "Warning: no input file configured for entity '$sel_label' (expected property: $input_prop_key)."
      read -r -p "Set input file paths now? [y/N] " ans
      case "$ans" in
        [yY]|[yY][eE][sS])
          # call the main menu's path editor if available
          if type set_input_file_paths >/dev/null 2>&1; then
            set_input_file_paths "$propfile" "$logfile"
            input_file="$(get_property "$propfile" "$input_prop_key" "")"
          else
            echo "Path editor not available. Please edit $propfile manually."
            sleep 2
          fi
          ;;
        *)
          echo "Continuing without input file..."
          ;;
      esac
    fi

    log_info "$logfile" "Selected $sel_label (cmd: $sel_cmd) for system $system"
    echo "Running $sel_label..."
    # Pass the input_file (may be empty) as an extra arg to run_java
    run_java "$sel_cmd" "$propfile" "$input_file"
    local rc=$?
    if [ $rc -eq 0 ]; then
      log_info "$logfile" "Validation PASSED: $sel_label"
      echo "PASS"
    else
      log_error "$logfile" "Validation FAILED (rc=$rc): $sel_label"
      echo "FAIL (rc=$rc)"
    fi

    # Offer to open the most recent log file produced by the run
    local logdir
    logdir="$(dirname "$logfile")"
    if [ ! -d "$logdir" ]; then
      logdir="$MFVT_HOME/logs"
    fi
    local recent
    recent="$(ls -1t -- "$logdir" 2>/dev/null | head -n1 || true)"
    if [ -n "$recent" ]; then
      read -r -p "Open most recent log ($recent)? [Y/n] " openans
      case "$openans" in
        [nN]|[nN][oO]) ;;
        *)
          local sel_path="$logdir/$recent"
          if [ ! -f "$sel_path" ]; then
            echo "Log file disappeared: $sel_path"
          else
            if command -v less >/dev/null 2>&1; then
              less -R "$sel_path"
            elif command -v more >/dev/null 2>&1; then
              more "$sel_path"
            else
              tail -n 500 "$sel_path"
              echo "(end of tail output)"
              read -r -p "Press Enter to continue..." _
            fi
          fi
          ;;
      esac
    fi

    if [ $rc -eq 0 ]; then
      log_info "$logfile" "Validation PASSED: $sel_label"
      echo "PASS"
    else
      log_error "$logfile" "Validation FAILED (rc=$rc): $sel_label"
      echo "FAIL (rc=$rc)"
    fi
    pause
  done
}
