#!/usr/bin/env bash
# 홈서버 PostgreSQL 백업: DB마다 pg_dump + 역할(globals) 덤프 -> gzip, 오래된 파일 자동 삭제.
# 사용: db/postgres/backup.sh        (어느 위치에서 실행해도 됩니다)
# cron 예시 (매일 새벽 3시):
#   0 3 * * * /home/<유저>/project/tsungmn-infra/db/postgres/backup.sh >> /home/<유저>/project/tsungmn-infra/db/postgres/backups/backup.log 2>&1
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

KEEP_DAYS="${KEEP_DAYS:-14}"
DIR="${BACKUP_DIR:-$ROOT/backups}"
COMPOSE=(docker compose -f docker-compose.yml)
STAMP="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$DIR"
umask 077
trap 'rm -f "$DIR"/*.partial' EXIT   # 실패하면 임시 파일을 남기지 않는다

# dump <이름> <명령...>  : 명령의 출력을 gzip 으로 저장한다. 빈 출력은 실패로 본다.
dump() {
  local name="$1"; shift
  local out="$DIR/${name}-${STAMP}.sql.gz"
  local tmp="$out.partial"
  "$@" | gzip > "$tmp"
  gzip -t "$tmp"
  if [ "$(stat -c%s "$tmp")" -lt 100 ]; then
    echo "$(date -Is) FAIL 백업 파일이 너무 작습니다: $tmp" >&2
    exit 1
  fi
  mv "$tmp" "$out"
  echo "$(date -Is) ok $out ($(du -h "$out" | cut -f1))"
}

# 백업할 DB 목록 (템플릿과 기본 postgres DB 는 제외)
mapfile -t DBS < <(
  echo "select datname from pg_database where not datistemplate and datname <> 'postgres' order by 1;" |
    "${COMPOSE[@]}" exec -T db sh -c 'psql -U "$POSTGRES_USER" -d postgres -At'
)
if [ "${#DBS[@]}" -eq 0 ]; then
  echo "$(date -Is) FAIL 백업할 DB 목록을 가져오지 못했습니다" >&2
  exit 1
fi

for db in "${DBS[@]}"; do
  dump "$db" "${COMPOSE[@]}" exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" -d "$1"' sh "$db"
done

# 역할(role)과 비밀번호 해시. 복원할 때 DB보다 먼저 넣어야 합니다.
dump globals "${COMPOSE[@]}" exec -T db sh -c 'pg_dumpall -U "$POSTGRES_USER" --globals-only'

find "$DIR" -maxdepth 1 -name '*.sql.gz' -mtime +"$KEEP_DAYS" -delete
