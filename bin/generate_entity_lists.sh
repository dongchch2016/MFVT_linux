#!/usr/bin/env bash
# Generate static entity lists from menus/*.menu
# Usage:
#   bin/generate_entity_lists.sh            # generate for all menus
#   bin/generate_entity_lists.sh Millennium # generate only for the named system
set -euo pipefail

MFVT_HOME="${MFVT_HOME:-$(pwd)}"
MENU_DIR="$MFVT_HOME/menus"

infer_input_key_from_cmd() {
  local cmd="$1"
  local lcmd
  lcmd="$(echo "$cmd" | tr '[:upper:]' '[:lower:]')"
  case "$lcmd" in
    *marcbib*|*bib*) echo "marcBib" ;;
    *marcholding*|*holding*) echo "marcHolding" ;;
    *items*|*item*) echo "items" ;;
    *patron*|*patrons*) echo "patrons" ;;
    *loan*|*loans*) echo "loans" ;;
    *vendor*|*vendors*) echo "vendors" ;;
    *) echo "" ;;
  esac
}

generate_for_menu_file() {
  local menufile="$1"
  local outfile
  outfile="${menufile%.*}.entities"

  # Parse menu and collect keys
  local -a keys=()
  while IFS= read -r line || [ -n "$line" ]; do
    # trim
    line="$(echo "$line" | sed -e 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -z "$line" ] && continue
    case "$line" in
      \#*) continue ;;
      \[*\]) continue ;;
      *=*)
        local keypart
        keypart="${line%%=*}"
        if [[ "$keypart" == *":"* ]]; then
          local input_prop
          input_prop="${keypart#*:}"
          if [ -n "$input_prop" ]; then
            keys+=("$input_prop")
          fi
        else
          local inferred
          inferred="$(infer_input_key_from_cmd "$keypart")"
          if [ -n "$inferred" ]; then
            keys+=("$inferred")
          fi
        fi
        ;;
      *) continue ;;
    esac
  done <"$menufile"

  # dedupe while preserving order
  local -a uniq=()
  for k in "${keys[@]}"; do
    local found=0
    for u in "${uniq[@]:-}"; do
      if [ "$u" = "$k" ]; then
        found=1; break
      fi
    done
    if [ $found -eq 0 ] && [ -n "$k" ]; then
      uniq+=("$k")
    fi
  done

  # write outfile
  printf "%s\n" "${uniq[@]}" >"$outfile"
  echo "Generated $outfile from $menufile"
}

# Determine which menu files to generate for
if [ $# -ge 1 ]; then
  sys="$1"
  sys_basename="${sys// /_}"
  candidate_lc="$(echo "$sys_basename" | tr '[:upper:]' '[:lower:]')"
  candidates=("$MENU_DIR/${candidate_lc}.menu" "$MENU_DIR/${sys_basename}.menu")
  # TitleCase candidate
  title=""
  IFS='_'
  for w in $sys_basename; do
    title+="$(echo "${w:0:1}" | tr '[:lower:]' '[:upper:]')$(echo "${w:1}" | tr '[:upper:]' '[:lower:]')_"
  done
  unset IFS
  title="${title%_}"
  candidates+=("$MENU_DIR/${title}.menu")

  # last resort case-insensitive find
  found=""
  for c in "${candidates[@]}"; do
    if [ -f "$c" ]; then
      found="$c"; break
    fi
  done
  if [ -z "$found" ]; then
    found="$(find "$MENU_DIR" -maxdepth 1 -type f -iname "${sys_basename}.menu" -print -quit 2>/dev/null || true)"
  fi
  if [ -n "$found" ]; then
    generate_for_menu_file "$found"
  else
    echo "No menu file found for system '$sys' (looked for: ${candidates[*]})" >&2
    exit 1
  fi
else
  # generate for all .menu files
  shopt -s nullglob
  for m in "$MENU_DIR"/*.menu; do
    generate_for_menu_file "$m"
  done
  shopt -u nullglob
fi
