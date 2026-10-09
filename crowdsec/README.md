# CrowdSec LAPI (edge, single container, SQLite default)

One `crowdsec` container: log processor + LAPI. One L7 consumer: the HAProxy
Lua classic bouncer (`MODE=stream`, fail-open). No firewall bouncer, no UDP
3478, no second SPOA. Canonical HAProxy stays at `VPS/haproxy/`.

## Layout

```text
crowdsec/
  docker-compose.yml  # crowdsecurity/crowdsec:v1.8.1, tanpa publish host (via edge), edge net
  acquis.d/haproxy.yaml  # syslog UDP server (:514) labelled type haproxy
  acquis.d/sshd.yaml     # tail /logs/auth.log (koleksi sshd)
  custom-scenarios/sso-bf.yaml  # skenario kustom (bruteforce SSO), contoh pola skenario sendiri
  conf/crowdsec-haproxy-bouncer.conf  # EXAMPLE (placeholder key, secret-free)
  .env.example  # placeholder key only
  README.md
```

SQLite DB lives in named volume `crowdsec-data`
(`/var/lib/crowdsec/data/crowdsec.db`); config in `crowdsec-config`.

## Setup (on the VPS, in order)

1. Shared network (once):
   `docker network create edge` (ignore "already exists").
2. Start CrowdSec first (HAProxy bouncer reads stream from LAPI):
   ```bash
   cd VPS/crowdsec
   docker compose up -d
   docker compose logs -f crowdsec
   ```
    `COLLECTIONS="crowdsecurity/haproxy crowdsecurity/http-cve crowdsecurity/sshd"` installs on
    first start. Confirm: `docker compose exec crowdsec cscli collections list`.
3. Register the bouncer (prints the API key once):
   `docker compose exec crowdsec cscli bouncers add haproxy-l7`
4. Render the bouncer conf (VPS only, never commit the key):
   copy `conf/crowdsec-haproxy-bouncer.conf` placeholder
   `${CROWDSEC_BOUNCER_KEY}` -> real key from step 3.
5. Pin the upstream Lua (fail-open stub until then):
   follow `VPS/haproxy/lua/README.md` (cs-haproxy-bouncer v0.0.6).
6. Start/refresh HAProxy:
   ```bash
   cd ../haproxy
   docker compose up -d
   ```

## Verify

```bash
cd VPS/crowdsec
docker compose config --quiet && echo "crowdsec compose OK"
docker compose exec crowdsec cscli collections list | grep -E "haproxy|http-cve|sshd"
docker compose exec crowdsec cscli bouncers list
docker compose exec crowdsec cscli decisions list
cd ../haproxy
docker compose config --quiet && echo "haproxy compose OK"
docker compose logs haproxy | grep -i crowdsec
```

Traffic check (fail-open proof): stop crowdsec
(`cd ../crowdsec && docker compose stop crowdsec`) -> HTTPS traffic must
still flow (stream cache / stub allows); restart afterwards.

## Rollback

- Bouncer off, WAF untouched: `cd VPS/haproxy && git checkout -- haproxy.cfg docker-compose.yml`
  (or comment the `lua.crowdsec_allow` line) `&& docker compose up -d haproxy`.
- Full CrowdSec removal: `cd VPS/crowdsec && docker compose down`
  (add `-v` only to also drop SQLite data + config volumes).

## Residual risks

- LAPI `8080`/syslog `514/udp` TIDAK di-publish ke host (konflik dengan
  netbird-dashboard `127.0.0.1:8080`); akses via network `edge` / `docker exec`.
- If LAPI is down when HAProxy (with real upstream lua) cold-starts, watch
  the lua init path in logs; start order above (crowdsec first) is the guard.
