# tsungmn-config

`tsungmn.com` 의 **공통 인증서 발급기**(cert-manager `ClusterIssuer`)를 두는 저장소입니다.
travel-planner, skku-notice 등 모든 서비스가 같은 발급기를 씁니다.

| 이름 | 용도 |
| --- | --- |
| `letsencrypt-tsungmn` | 실제 발급 (Let's Encrypt, DNS-01 / Cloudflare) |

## 처음 한 번만 (순서대로)

1. **cert-manager 네임스페이스 확인**: `kubectl get deploy -A | grep cert-manager`.
   `cert-manager` 가 아니면 아래 2번의 `-n` 값을 그 네임스페이스로 바꿉니다.
2. **Cloudflare 토큰 Secret** 을 cert-manager 네임스페이스에 만듭니다. ClusterIssuer는 Secret을 서비스 네임스페이스가 아니라 이곳에서 찾습니다.
   토큰은 Cloudflare → My Profile → API Tokens → **Edit zone DNS** 템플릿, Zone Resources는 `tsungmn.com` 하나로 제한합니다.
   ```bash
   read -s CF_TOKEN
   printf %s "$CF_TOKEN" | kubectl -n cert-manager create secret generic cloudflare-api-token --from-file=api-token=/dev/stdin
   unset CF_TOKEN
   ```
3. 이 repo를 push 한 뒤 서버에서 `kubectl apply -f config/application.yaml`.
4. 확인: `kubectl get clusterissuer` 에서 두 발급기 모두 `READY=True`.

## 서비스에서 쓰는 방법

각 서비스의 Ingress에 어노테이션 하나와 `tls` 를 둡니다. Issuer가 아니라 **cluster-issuer** 입니다.

```yaml
metadata:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-tsungmn
spec:
  tls:
    - hosts: [travel.tsungmn.com]
      secretName: travel-tls
```

## 순서 주의

서비스 repo의 Ingress를 `cluster-issuer` 로 바꾸기 **전에** 이 repo를 먼저 배포해 ClusterIssuer가 `READY=True` 인지 확인하세요.
