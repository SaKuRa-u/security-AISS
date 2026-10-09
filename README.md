# security-AISS — infrastruktur keamanan VPS (UTS AISS DCSM)

Edge security stack di 1 VPS: **HAProxy 3.4 LTS** (reverse proxy + rate-limit
instan) → **Coraza SPOA + OWASP CRS v4** (WAF) → **CrowdSec LAPI + bouncer Lua**
(IP reputation/stream, fail-open). Ditambah: NetBird self-hosted (overlay),
Authentik + LLDAP (SSO/IAM), voter SeaweedFS/etcd (joint dengan node),
Trivy (audit).

```text
VPS/
  haproxy/    # edge reverse proxy: haproxy.cfg, Coraza SPOA, docker-compose
  crowdsec/   # LAPI SQLite: acquis, skenario kustom, conf bouncer (placeholder)
  netbird/    # server+dashboard self-hosted (config.yaml = CHANGEME semua secret)
  authentik/  # SSO/IAM + LLDAP (secret via .env, JANGAN commit)
  voters/     # SeaweedFS master + etcd voter (JOINT dengan node, jangan up sendiri)
  trivy/      # audit sekali-jalan: image + repo + SBOM
```

## Urutan setup (ringkas; detail per folder di README masing-masing)

```bash
docker network create edge                              # sekali saja
cd authentik && cp .env.example .env && nano .env       # isi SEMUA secret
cd ../netbird && cp .env.example .env && nano .env      # isi bila perlu
# netbird/config.yaml: ganti SEMUA nilai CHANGEME (authSecret, sessionCookie..., encryptionKey)
sudo certbot certonly --standalone -d <domain>          # lalu gabung ke haproxy/certs/*.pem
cd ../crowdsec && docker compose up -d                  # LAPI dulu
docker compose exec crowdsec cscli bouncers add haproxy-l7   # catat key SEKALI
# render key ke conf/crowdsec-haproxy-bouncer.conf (di VPS saja, jangan commit!)
cd ../haproxy && docker compose up -d --build           # build coraza-spoa pertama kali
```

## Aturan secret (repo ini PUBLIK)

| File | Status |
|---|---|
| `*/.env` | JANGAN commit (gitignored). Isi dari `.env.example` + `openssl rand` |
| `haproxy/certs/*.pem` | JANGAN commit (fullchain+key, gitignored). Buat via certbot di host |
| `crowdsec/conf/*.conf` | placeholder `${...}` saja. Key asli hanya di VPS |
| `netbird/config.yaml` | `CHANGEME` semua. Nilai asli hanya di VPS |
| `*.bak*`, `data/`, `*.db` | JANGAN commit (gitignored) |

## Verifikasi inti

```bash
docker compose -f crowdsec/docker-compose.yml config --quiet && echo OK
docker compose -f haproxy/docker-compose.yml config --quiet && echo OK
docker compose exec crowdsec cscli bouncers list
curl -sk -o /dev/null -w "%{http_code}\n" https://<domain>/
```

## Catatan desain (singkat, sadar)

- Fail-open di semua lapis (Coraza `set-on-error`, bouncer stream-cache,
  rate-limit hanya 429): ketersediaan didahulukan.
- `be_app` primary-only (`healthz.php` 200 hanya primary; replica 503).
- NetBird relay permanen (NAT site simetris); anti-DDoS volumetrik = residu
  hulu (butuh Cloudflare/proxy), bukan lapis ini.
- Bouncer Lua di repo = stub fail-open; pin upstream `cs-haproxy-bouncer
  v0.0.6` ikut `haproxy/lua/README.md` (seperti di VPS produksi).
- Ret-code: template ban HTML selalu 200 di v0.0.6; `RET_CODE=403` untuk
  klien non-HTML.
