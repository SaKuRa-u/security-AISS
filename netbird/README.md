# NetBird (self-host, mode HAProxy)

Setup mengikuti [Quickstart resmi](https://docs.netbird.io/selfhosted/selfhosted-quickstart)
dan [External Reverse Proxy - Combined Container](https://docs.netbird.io/selfhosted/external-reverse-proxy#combined-container-setup-v0-65-0),
tapi reverse proxy diganti HAProxy (kategori resmi `Other/Manual` / opsi `[5]`).
Arsitektur: 2 container (`netbird-server` combined + `dashboard`), STUN UDP 3478 langsung.

## Struktur

```text
netbird/
  docker-compose.yml            # expose 127.0.0.1:8080 + 127.0.0.1:8081 + 3478/udp
  config.yaml                   # gabungan management+signal+relay+STUN (edit domain + secret)
  dashboard.env                 # endpoint + OIDC embedded IdP (edit domain)
  .env.example                  # template env -> copy ke .env (tidak di-commit)
  haproxy-netbird.cfg.example   # template frontend/backend HAProxy
```

## Prasyarat

- Linux VM 1 CPU / 2 GB, Docker + compose plugin v2, `jq`, `curl`.
- Domain publik `A` ke IP VPS (contoh `netbirdoverlay.cloudferdi.web.id`).
- Port publik: TCP `80`, `443` (via HAProxy) + UDP `3478` (STUN, langsung, jangan di-proxy).
- HAProxy 3.4 LTS via Docker, lihat folder `../haproxy/` (jalankan HAProxy dulu,
  baru NetBird). File `haproxy-netbird.cfg.example` di folder ini hanya referensi
  mode install host; yang runnable adalah `../haproxy/haproxy.cfg`.

## Cara pakai

1. Generate secret (jangan pakai `CHANGEME`):

   ```bash
   openssl rand -base64 32 | tr -d '='   # -> authSecret / sessionCookieEncryptionKey
   openssl rand -base64 32               # -> store encryptionKey (pertahankan '=')
   ```

2. Copy env dan edit:

   ```bash
   cp .env.example .env
   # isi NETBIRD_DOMAIN, LETSENCRYPT_EMAIL
   ```

3. Edit `config.yaml`: `exposedAddress`, `auth.issuer`, `dashboardRedirectURIs`,
   `authSecret`, `sessionCookieEncryptionKey`, `store.encryptionKey`.
   `reverseProxy.trustedPeers`: isi subnet network `edge`
   (`docker network inspect edge --format "{{(index .IPAM.Config 0).Subnet}}"`).

4. Edit `dashboard.env`: domain sudah terisi, verifikasi saja tidak ada yang terlewat.

5. Jalankan HAProxy dulu (folder `../haproxy/`), lalu NetBird. HAProxy mencapai
   NetBird via nama container di network `edge`, jadi pastikan network-nya ada:

   ```bash
   docker network create edge
   ```

6. Jalankan:

   ```bash
   cd netbird
   docker compose up -d
   docker compose logs -f netbird-server
   curl -skf https://netbirdoverlay.cloudferdi.web.id/oauth2/.well-known/openid-configuration | jq .
   ```

7. Onboarding: buka `https://netbirdoverlay.cloudferdi.web.id` -> `/setup` -> buat akun admin pertama.
   Halaman `/setup` hanya ada saat belum ada user.

## Operasional

```bash
docker compose pull && docker compose up -d --force-recreate  # upgrade (cek release notes dulu)
docker compose stop management  # tidak ada; combined = service netbird-server
docker compose cp -a netbird-server:/var/lib/netbird/ ./backup/  # backup data sqlite
```

Skipped: Traefik built-in, NetBird Proxy expose-to-internet, CrowdSec. Tambahkan saat butuh expose resource internal via subdomain (perlu wildcard DNS + TLS passthrough, hanya didukung Traefik resmi).
