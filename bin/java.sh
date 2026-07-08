#!/usr/bin/env bash
# Java invocation wrapper (updated to pass migration form, field mapping, date format, and input file)
set -euo pipefail

# run_java <command> <property_file> [input-file]
run_java() {
  local cmd="$1"; shift
  local propfile="${1:-}"; shift || true
  local input_file="${1:-}"  # optional input file path

  local jar="$MFVT_HOME/lib/validator.jar"

  # Read properties from property file (if provided)
  local migration_form=""
  local field_mapping=""
  local date_format=""

  if [ -n "$propfile" ] && [ -f "$propfile" ]; then
    migration_form="$(get_property "$propfile" "migration.form" "")"
    field_mapping="$(get_property "$propfile" "field.mapping.form" "")"
    date_format="$(get_property "$propfile" "date.format" "")"
  fi

  if [ ! -f "$jar" ]; then
    echo "WARNING: validator JAR not found at $jar"
    echo "Would run: java -jar $jar $cmd \\\"\""
    echo "  --migrationForm \"$migration_form\" \\\"\""
    echo "  --fieldMapping \"$field_mapping\" \\\"\""
    echo "  --dateFormat \"$date_format\" \\\"\""
    if [ -n "$input_file" ]; then
      echo "  --inputFile \"$input_file\" \\\"\""
    fi
    echo "  $propfile"
    return 0
  fi

  # Build argument list
  local args=()
  args+=( "$cmd" )
  if [ -n "$migration_form" ]; then
    args+=( "--migrationForm" "$migration_form" )
  fi
  if [ -n "$field_mapping" ]; then
    args+=( "--fieldMapping" "$field_mapping" )
  fi
  if [ -n "$date_format" ]; then
    args+=( "--dateFormat" "$date_format" )
  fi
  if [ -n "$input_file" ]; then
    args+=( "--inputFile" "$input_file" )
  fi
  if [ -n "$propfile" ]; then
    args+=( "$propfile" )
  fi

  # Execute Java with the assembled arguments
  java -jar "$jar" "${args[@]}"
  return $?
}
