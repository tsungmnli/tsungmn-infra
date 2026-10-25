# tsungmn-config

`tsungmn.com` 아래 모든 서비스(travel-planner, skku-notice 등)가 **같이 쓰는** 인프라 설정입니다.

| 폴더 | 내용 | 배포 방식 |
| --- | --- | --- |
| `config/` | cert-manager 공통 인증서 발급기(ClusterIssuer). 자세한 내용은 `config/README.md` | ArgoCD (`config/overlays` 만 동기화) |
| `db/postgres/` | 홈서버 공용 PostgreSQL(Docker). 자세한 내용은 `db/postgres/README.md` | 홈서버에서 직접 실행 (ArgoCD 아님) |

서비스 하나에만 쓰는 설정(예: skku-notice의 DB·역할 생성 스크립트)은 이 저장소가 아니라 그 서비스의 infra repo에 둡니다.
