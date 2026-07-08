#!/usr/bin/env bash
set -euo pipefail

# mfvt_full_package_builder.sh
# Downloads the latest main branch ZIP of the repo, replaces validator.properties
# with safe sample_data paths (avoids creating /data) and produces a release ZIP.

REPO_OWNER="dongchch2016"
REPO_NAME="MFVT_linux"
BRANCH="main"
ZIPURL="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/heads/${BRANCH}.zip"
TMPDIR="$(mktemp -d)"
OUTDIR="$(pwd)"
WORKDIR="$TMPDIR/work"
ARCHIVE="$TMPDIR/${REPO_NAME}-${BRANCH}.zip"
RELEASE_NAME="MFVT-Linux-Full-Release.zip"

echo "Builder starting: will download $ZIPURL"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

if command -v curl >/dev/null 2>&1; then
  curl -L -o "$ARCHIVE" "$ZIPURL"
elif command -v wget >/dev/null 2>&1; then
  wget -O "$ARCHIVE" "$ZIPURL"
else
  echo "Error: neither curl nor wget is available. Please install one to use this script." >&2
  exit 1
fi

unzip -q "$ARCHIVE"
# Unzipped directory is usually ${REPO_NAME}-${BRANCH}
UNZIPPED_DIR="$(unzip -Z1 "$ARCHIVE" | head -n1 | sed -e 's|/.*$||')"
if [ -z "$UNZIPPED_DIR" ] || [ ! -d "$UNZIPPED_DIR" ]; then
  echo "Failed to find unzipped directory inside archive." >&2
  exit 1
fi
cd "$UNZIPPED_DIR"

# Overwrite validator.properties with safe sample paths (use sample_data paths)
cat > validator.properties <<'EOF'
####################################
# General
####################################

system=Millennium

encoding=UTF-8

date.format=yyyy-MM-dd

price.format=0.00

####################################
# Forms
####################################

migration.form=sample_data/forms/Migration.xlsx

field.mapping.form=sample_data/forms/FieldMapping.xlsx

####################################
# Input Files
####################################

marcBib=sample_data/input/bib.mrc

marcHolding=sample_data/input/holding.mrc

items=sample_data/input/items.txt

patrons=sample_data/input/patrons.txt

loans=sample_data/input/loans.txt

vendors=sample_data/input/vendors.txt

####################################
# Output
####################################

output.path=sample_data/output

log.path=sample_data/logs
EOF

# Ensure sample_data exists and placeholder files are present
mkdir -p sample_data/input sample_data/forms sample_data/output sample_data/logs
: > sample_data/input/bib.mrc
: > sample_data/input/holding.mrc
: > sample_data/input/items.txt
: > sample_data/input/patrons.txt
: > sample_data/input/loans.txt
: > sample_data/input/vendors.txt
# create placeholder forms
touch sample_data/forms/Migration.xlsx sample_data/forms/FieldMapping.xlsx

# Make scripts executable where applicable
chmod +x *.sh 2>/dev/null || true
if [ -d bin ]; then
  chmod +x bin/*.sh 2>/dev/null || true
fi
if [ -d systems ]; then
  chmod +x systems/*.sh 2>/dev/null || true
fi

# Create the release ZIP
cd ..
# The zip should contain the project directory (repo-name-branch)
if command -v zip >/dev/null 2>&1; then
  echo "Creating $RELEASE_NAME ..."
  zip -r "$OUTDIR/$RELEASE_NAME" "$UNZIPPED_DIR" >/dev/null
  echo "Release ZIP created: $OUTDIR/$RELEASE_NAME"
else
  echo "zip not found, creating tar.gz instead"
  tar -czf "$OUTDIR/${RELEASE_NAME%.zip}.tar.gz" "$UNZIPPED_DIR"
  echo "Created: $OUTDIR/${RELEASE_NAME%.zip}.tar.gz"
fi

# Cleanup
rm -rf "$TMPDIR"

echo "Builder finished."
