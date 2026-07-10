#!/usr/bin/env bash
# Main menu engine (updated to support configuration-driven menus in menus/*.menu)
set -euo pipefail
# shellcheck source=/dev/null
. "$MFVT_HOME/bin/screen.sh"
# shellcheck source=/dev/null
. "$MFVT_HOME/bin/common.sh"
# shellcheck source=/dev/null
. "$MFVT_HOME/bin/config.sh"
# shellcheck source=/dev/null
. "$MFVT_HOME/bin/logger.sh"
# shellcheck source=/dev/null
. "$MFVT_HOME/bin/menu_engine.sh"

main_menu() {
  local propfile="${1:-$MFVT_HOME/validator.properties}"
  local logfile="${2:-$MFVT_HOME/logs/validator.log}"

  load_properties "$propfile"

  while true; do
    clear_screen
    draw_header "MFVT Linux Validator"
    echo "1) Select System (current: $PROP_SYSTEM)"
    echo "2) Migration Forms (current: ${PROP_MIGRATION_FORM:-<none>})"
    echo "3) Field Mapping (current: ${PROP_FIELD_MAPPING:-<none>})"
    echo "4) Default Formats"
    echo "5) Entity Validation (open selected system menu)"
    echo "6) Run Validation (run last-selection)"
    echo "7) View Properties"
    echo "8) Set Input File Paths"
    echo "9) View Logs"
    echo "0) Exit"
    echo
    read -r -p "Choose an option: " choice
    case "$choice" in
      1)
        select_system_menu "$propfile" "$logfile"
        load_properties "$propfile"
        ;;
      2)
        edit_migration_form "$propfile" "$logfile"
        ;;
      3)
        edit_field_mapping "$propfile" "$logfile"
        ;;
      4)
        configure_formats "$propfile" "$logfile"
        ;;
      5)
        # Launch the selected system menu using the menu engine
        show_system_menu "$PROP_SYSTEM" "$propfile" "$logfile"
        ;;
      6)
        read -r -p "Run full validation for all entities now? [Y/n] " runans
        case "$runans" in
          ""|[yY]|[yY][eE][sS])
            # call Java wrapper with only the properties file; Java reads all params from it
            run_java "$propfile"
            ;;
          *)
            echo "Cancelled."
            ;;
        esac
        pause
        ;;
      7)
        echo "Properties ($propfile):"
        sed -n '1,200p' "$propfile"
        pause
        ;;
      8)
        set_input_file_paths "$propfile" "$logfile"
        load_properties "$propfile"
        ;;
      9)
        view_logs "$propfile" "$logfile"
        ;;
      0)
        echo "Exiting."
        break
        ;;
      *)
        echo "Invalid choice."
        pause
        ;;
    esac
  done
}

select_system_menu() {
  local propfile="$1"; local logfile="$2"
  echo "Select Library System"
  echo "1) Generic"
  echo "2) Millennium"
  echo "3) Horizon"
  echo "4) Symphony"
  echo "5) Talis Alto"
  echo "6) VTLS"
  echo "0) Back"
  read -r -p "Choice: " c
  case "$c" in
    1) set_property "$propfile" "system" "Generic" ;;
    2) set_property "$propfile" "system" "Millennium" ;;
    3) set_property "$propfile" "system" "Horizon" ;;
    4) set_property "$propfile" "system" "Symphony" ;;
    5) set_property "$propfile" "system" "Talis Alto" ;;
    6) set_property "$propfile" "system" "VTLS" ;;
    0) return ;;
    *) echo "Invalid"; pause ;;
  esac
  log_info "$logfile" "System set to $(get_property "$propfile" system)"
}

edit_migration_form() {
  local propfile="$1"; local logfile="$2"
  echo "Current migration form: $(get_property "$propfile" migration.form)"
  read -r -p "Enter path to migration form (or leave blank to cancel): " p
  if [ -n "$p" ]; then
    set_property "$propfile" "migration.form" "$p"
    log_info "$logfile" "Migration form set to $p"
  fi
}

edit_field_mapping() {
  local propfile="$1"; local logfile="$2"
  echo "Current field mapping form: $(get_property "$propfile" field.mapping.form)"
  read -r -p "Enter path to field mapping form (or leave blank to cancel): " p
  if [ -n "$p" ]; then
    set_property "$propfile" "field.mapping.form" "$p"
    log_info "$logfile" "Field mapping form set to $p"
  fi
}

configure_formats() {
  local propfile="$1"; local logfile="$2"
  echo "Date format: $(get_property "$propfile" date.format)"
  read -r -p "Enter date format (or leave blank): " d
  if [ -n "$d" ]; then
    set_property "$propfile" "date.format" "$d"
  fi
  echo "Price format: $(get_property "$propfile" price.format)"
  read -r -p "Enter price format (or leave blank): " pf
  if [ -n "$pf" ]; then
    set_property "$propfile" "price.format" "$pf"
  fi
  log_info "$logfile" "Formats updated"
}

# set_property helper (append or replace)
set_property() {
  local file="$1"; shift
  local key="$1"; shift
  local value="$*"
  if grep -qE "^\s*${key//./\\\.}\s*=" "$file"; then
    # replace existing
    sed -i.bak -E "s|^\s*${key//./\\\.}\s*=.*$|${key}=${value}|" "$file"
  else
    echo "${key}=${value}" >>"$file"
  fi
}

# Prompt operator to input file paths for known entities and save them to properties
set_input_file_paths() {
  local file="$1"; shift
  local logfile="$1"; shift || true

  # Attempt to derive the entity keys from the selected system's menu file
  local system
  system="$(get_property "$file" system)"
  # if not set in properties, fall back to current runtime selection
  if [ -z "$system" ]; then
    system="$PROP_SYSTEM"
  fi

  if [ -z "$system" ]; then
    echo "No system selected. Please select a system first." 
    pause
    return
  fi

  # Normalize system name to match menu filenames
  local sys_basename="${system// /_}"
  local sys_lower
  sys_lower="$(echo "$sys_basename" | tr '[:upper:]' '[:lower:]')"

  local fname="$MFVT_HOME/menus/${sys_lower}.menu"
  if [ ! -f "$fname" ] && [ -f "$MFVT_HOME/menus/${sys_basename}.menu" ]; then
    fname="$MFVT_HOME/menus/${sys_basename}.menu"
  fi

  local -a keys=()

  if [ -f "$fname" ]; then
    # Parse menu file for key[:inputProp]=Label entries and collect input props
    while IFS= read -r line || [ -n "$line" ]; do
      # Trim whitespace
      line="$(echo "$line" | sed -e 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      [ -z "$line" ] && continue
      case "$line" in
        \#*) continue ;;
        \[*\]) continue ;;
        *=*)
          local key_part
          key_part="${line%%=*}"
          if [[ "$key_part" == *":"* ]]; then
            local input_prop
            input_prop="${key_part#*:}"
            if [ -n "$input_prop" ]; then
              keys+=("$input_prop")
            fi
          else
            # No explicit input prop; infer from command name
            local inferred
            inferred="$(infer_input_key_from_cmd "$key_part")"
            if [ -n "$inferred" ]; then
              keys+=("$inferred")
            fi
          fi
          ;;
        *) continue ;;
      esac
    done <"$fname"
  else
    # fallback to a default set if no menu file is found
    keys=(marcBib marcHolding items patrons loans vendors)
  fi

  # Deduplicate keys while preserving order
  local -a uniq_keys=()
  for k in "${keys[@]}"; do
    local found=0
    for u in "${uniq_keys[@]}"; do
      if [ "$u" = "$k" ]; then
        found=1
        break
      fi
    done
    if [ $found -eq 0 ] && [ -n "$k" ]; then
      uniq_keys+=("$k")
    fi
  done

  if [ ${#uniq_keys[@]} -eq 0 ]; then
    echo "No entity input properties could be derived for system $system"
    pause
    return
  fi

  echo "Enter file paths for the following entities (leave blank to keep current):"
  for k in "${uniq_keys[@]}"; do
    local cur
    cur="$(get_property "$file" "$k" "")"
    read -r -p "${k} (current: ${cur:-<none>}): " val
    if [ -n "$val" ]; then
      set_property "$file" "$k" "$val"
      log_info "$logfile" "Set $k = $val"
    fi
  done

  echo "File paths updated in $file"
}

# Allow operator to view recent logs from the configured log directory
view_logs() {
  local propfile="$1"; shift
  local logfile="$1"; shift || true

  local logdir
  logdir="$(dirname "$logfile")"
  if [ ! -d "$logdir" ]; then
    logdir="$MFVT_HOME/logs"
  fi

  echo "Logs directory: $logdir"
  # gather files sorted by modification time
  mapfile -t files < <(ls -1t -- "$logdir" 2>/dev/null || true)
  if [ ${#files[@]} -eq 0 ]; then
    echo "No log files found in $logdir"
    pause
    return
  fi

  while true; do
    echo
    echo "Recent log files:"
    for i in "${!files[@]}"; do
      idx=$((i+1))
      printf "%2d) %s\n" "$idx" "${files[$i]}"
    done
    echo " 0) Back"
    read -r -p "Choose a log file to view (or 0 to return): " choice

    if [[ ! "$choice" =~ ^[0-9]+$ ]]; then
      echo "Invalid choice"
      pause
      return
    fi
    if [ "$choice" -eq 0 ]; then
      return
    fi
    if [ "$choice" -lt 1 ] || [ "$choice" -gt "${#files[@]}" ]; then
      echo "Choice out of range"
      pause
      return
    fi

    local sel_index=$((choice - 1))
    local sel_file="${files[$sel_index]}"
    local sel_path="$logdir/$sel_file"

    if [ ! -f "$sel_path" ]; then
      echo "Selected file not found: $sel_path"
      pause
      return
    fi

    # Viewing options: open once, follow, or back to list
    echo
    echo "Viewing options for $sel_file:"
    echo " 1) Open once"
    echo " 2) Follow (tail -f)"
    echo " 3) Back to log list"
    read -r -p "Choose: [1] " view_choice
    view_choice="${view_choice:-1}"

    case "$view_choice" in
      1)
        if command -v less >/dev/null 2>&1; then
          less -R "$sel_path"
        elif command -v more >/dev/null 2>&1; then
          more "$sel_path"
        else
          tail -n 500 "$sel_path"
          echo "(end of tail output)"
          read -r -p "Press Enter to continue..." _
        fi
        ;;
      2)
        echo "Following $sel_path (press Ctrl-C to stop)"
        tail -f "$sel_path" || true
        ;;
      3)
        # go back to file list
        continue
        ;;
      *)
        echo "Invalid choice"
        ;;
    esac

    # After viewing, let operator choose to return to the list or exit to main menu
    read -r -p "Return to log list? [Y/n] " again
    case "$again" in
      [nN]|[nN][oO]) return ;;
      *) ;;
    esac
  done
}
