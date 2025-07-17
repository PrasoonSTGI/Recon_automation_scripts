#!/usr/bin/env bash
# shellcheck disable=SC1090,SC2086

set -euo pipefail

HOME_DIR="/home/stgwe"
TEMPLATE="/home/stgwe/template_sql/template.sql"
OUTPUT="/home/stgwe/output_sql/output.sql"
RERUN_DIR="/home/stgwe/re-run"
ENV_FILE="/home/stgwe/.env-pdi"
WAIT_SECS=15

# ── folder to keep quiet logs ───────────────────────────────────────────────────
LOG_DIR="$HOME_DIR/job_logs"
mkdir -p "$LOG_DIR"

# ── path helpers ───────────────────────────────────────────────────────────────
OUTPUT_DIR="$(dirname "$OUTPUT")"
OUTPUT_BASE="$(basename "$OUTPUT" .sql)"
OUTPUT_SQL="$OUTPUT_DIR/${OUTPUT_BASE}.sql"

# ── basic sanity checks ────────────────────────────────────────────────────────
[[ -f $TEMPLATE  ]] || { echo "Template '$TEMPLATE' not found";  exit 1; }
[[ -d $RERUN_DIR ]] || { echo "Directory '$RERUN_DIR' not found"; exit 1; }
[[ -f $ENV_FILE  ]] || { echo "$ENV_FILE missing";                exit 1; }

# ── pick which jobs to run ─────────────────────────────────────────────────────
declare -a JOBS
read -rp $'\nRun (O)ne job or (A)ll jobs? [O/A]: ' CHOICE
case "${CHOICE^^}" in
  O)  read -rp "Enter job name: " ONE_JOB; JOBS=("$ONE_JOB") ;;
  A|*) JOBS=(HELLO_WORLD HELLO_WORLD) ;;
esac

# ── load ENV from .env-pdi ──────────────────────────────────────────────────────
TMP_EXPORT="$(mktemp)"
sed '/^#/! s/^/export /' "$ENV_FILE" > "$TMP_EXPORT"
source "$TMP_EXPORT"
rm -f "$TMP_EXPORT"

# ── helper wrappers ────────────────────────────────────────────────────────────
run_sql() {
  docker run --rm --network host -v "$HOME_DIR":"$HOME_DIR" \
    --env-file "$ENV_FILE" postgres \
    psql --host localhost --port "$DB_PORT_1" \
         --username "$DB_USERNAME_1" --dbname "$DB_NAME_1" \
         -f "$OUTPUT_SQL"
}

run_job() { "$(dirname "$0")/run_docker_job.sh" "$1"; }

filemover_running() {
  docker ps --filter ancestor=filemover --format '{{.ID}}' | grep -q .
}

# ── MAIN LOOP ──────────────────────────────────────────────────────────────────
shopt -s nullglob
echo -e "\n▶  Scanning folders in $RERUN_DIR …"

for DIR in "$RERUN_DIR"/*; do
  [[ -d $DIR ]] || continue
  DATE_TAG="$(basename "$DIR")"

  ## 1️⃣  VALID-DATE CHECK — skip if `date` can’t parse it
  if ! date -d "$DATE_TAG" '+%Y-%m-%d' >/dev/null 2>&1; then
      echo "  ↩︎  Skipping '$DATE_TAG' – invalid calendar date"
      continue
  fi

  ## 2️⃣  FORMAT CHECK — must be exactly YYYY-MM-DD
  if [[ ! $DATE_TAG =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
      echo "  ↩︎  Skipping '$DATE_TAG' – not in yyyy-mm-dd format"
      continue
  fi

  ## ask user for this folder; *skip*, don’t exit, on “no”
  read -rp "Proceed with job rerun on $DATE_TAG ? [y/N]: " RESP
  if [[ ${RESP,,} != y ]]; then
      echo "  ↩︎  Skipping '$DATE_TAG' on user request"
      continue
  fi

  # ── prepare SQL for the chosen date ──────────────────────────────────────────
  sed -E "s/\\<current_date\\>/'$DATE_TAG'::date/g" "$TEMPLATE" > "$OUTPUT_SQL"
  chmod +x "$OUTPUT_SQL"
  echo "Prepared $(basename "$OUTPUT_SQL") for $DATE_TAG"

  # ── quiet log file for this run ──────────────────────────────────────────────
  LOG_FILE="$LOG_DIR/${DATE_TAG}.log"
  echo -e "\n──────── $(date '+%F %T') : ${DATE_TAG} ────────" >>"$LOG_FILE"

  # — optional guard ————————————————————————————————————————————————
  if filemover_running; then
      echo " 'filemover' container already active – skipping SQL+jobs."
      echo "filemover already running – skipped SQL+jobs" >>"$LOG_FILE"
      continue
  fi

  # ── run SQL (logged) ─────────────────────────────────────────────────────────
  if run_sql >>"$LOG_FILE" 2>&1; then
      echo "      SQL done."
  else
      echo "      SQL FAILED – see $LOG_FILE"
      continue                # move on to next folder
  fi

  # ── run each selected job (logged) ───────────────────────────────────────────
  for job in "${JOBS[@]}"; do
      echo "  Executing job: $job (details → $LOG_FILE)"
      if run_job "$job" >>"$LOG_FILE" 2>&1; then
          echo "      Job $job finished."
      else
          echo "      Job $job FAILED – see $LOG_FILE"
      fi
  done

  echo " Completed re-run for $DATE_TAG"
done

echo -e "\nAll dated folders processed. Script finished."
