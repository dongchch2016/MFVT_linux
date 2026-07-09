#!/usr/bin/env bash
# Java invocation wrapper (simplified to pass only the properties file to the validator JAR)
set -euo pipefail

# run_java <property_file>
run_java() {
  local propfile="${1:-}"; shift || true

  local jar="$MFVT_HOME/lib/validator.jar"

  if [ -z "$propfile" ] || [ ! -f "$propfile" ]; then
    echo "ERROR: property file not provided or not found: $propfile" >&2
    return 2
  fi

  if [ ! -f "$jar" ]; then
    echo "WARNING: validator JAR not found at $jar"
    echo "Would run: java -jar $jar \"$propfile\""
    return 0
  fi

  # Execute Java with only the properties file; the Java main will read all parameters from it
  java -jar "$jar" "$propfile"
  return $?
}
