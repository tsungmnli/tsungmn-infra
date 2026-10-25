# db/postgres

홈서버 공용 PostgreSQL(Docker) 설정입니다. travel-planner, skku-notice 등 여러 서비스가 컨테이너 하나(`tsungmn-postgres`)를 같이 씁니다.
**ArgoCD가 관리하지 않습니다.** ArgoCD Application은 `config/overlays` 만 바라보므로 이 폴더는 배포되지 않고, 홈서버에서 직접 실행합니다.

서비스마다 **DB와 역할(role)을 따로** 만들고 비밀번호도 따로 둡니다. 서비스별 생성 스크립트는 각 서비스 infra repo에 둡니다. (예: skku-notice-infra 의 `db/skku-notice/init.sql`)

- `app` (슈퍼유저): 관리용입니다. 서비스 앱은 이 계정으로 접속하지 않습니다. (travel-planner는 현재 이 계정을 씁니다)
- 데이터: `data/pg` 또는 `PG_DATA_DIR` (git 제외). 컨테이너를 지워도 이 폴더가 남아 있으면 안전합니다.
- 백업: `backups/` (git 제외)

> 데이터 폴더가 git 작업 폴더 안에 있으면 `git clean -fdx` 한 번에 지워집니다. 걱정되면 `.env` 의 `PG_DATA_DIR` 로 저장소 밖 경로를 쓰세요.

## 처음 켜기

```bash
cd db/postgres
cp .env.example .env      # POSTGRES_PASSWORD, DB_BIND_IP 채우기
chmod 600 .env
docker compose up -d
docker compose ps         # healthy 가 될 때까지 기다립니다
```

`DB_BIND_IP`는 홈서버가 실제로 가진 IP여야 하고 `0.0.0.0`은 쓰지 않습니다. 5432는 클러스터 노드 IP에서만 접속되도록 방화벽을 설정합니다.

## 자주 쓰는 명령

모두 이 폴더에서 실행합니다.

| 하고 싶은 일 | 명령 |
| --- | --- |
| 상태 / 로그 | `docker compose ps` / `docker compose logs --tail=50 db` |
| DB 안으로 들어가기 | `docker exec -it tsungmn-postgres psql -U app -d postgres` |
| DB·역할 목록 | `docker exec tsungmn-postgres psql -U app -d postgres -c '\l' -c '\du'` |
| 새 서비스 DB 만들기 | 서비스 infra repo의 `init.sql` 을 `docker exec -i -e <변수> tsungmn-postgres psql -U app -d postgres -f - < init.sql` 로 실행 |

## 백업

`backup.sh`가 서버의 **모든 DB**를 각각 `<DB이름>-<시각>.sql.gz`로, 역할 정보는 `globals-<시각>.sql.gz`로 저장하고 14일(`KEEP_DAYS`)이 지난 파일을 지웁니다.

```bash
./backup.sh
crontab -e   # 0 3 * * * /home/<유저>/project/tsungmn-infra/db/postgres/backup.sh >> /home/<유저>/project/tsungmn-infra/db/postgres/backups/backup.log 2>&1
```

복원할 때는 **globals를 먼저**, 그다음 DB를 넣습니다. 역할이 없으면 DB 소유자 지정에서 오류가 납니다.

```bash
gunzip -c backups/globals-<시각>.sql.gz | docker exec -i tsungmn-postgres psql -U app -d postgres
docker exec tsungmn-postgres createdb -U app <DB이름>      # 이미 있으면 생략
gunzip -c backups/<DB이름>-<시각>.sql.gz | docker exec -i tsungmn-postgres psql -U app -d <DB이름>
```

홈서버 디스크가 고장 나면 `backups/`도 같이 사라지므로 다른 컴퓨터나 외부 저장소에도 주기적으로 복사합니다.
