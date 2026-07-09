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
  # List of property keys to prompt for (extend as needed)
  local keys=(marcBib marcHolding items patrons loans vendors)
  echo "Enter file paths for the following entities (leave blank to keep current):"
  for k in "${keys[@]}"; do
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
