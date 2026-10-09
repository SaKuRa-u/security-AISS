# Authentik + LLDAP (identity plane)

Authentik jadi IAM/SSO (termasuk login NetBird), LLDAP jadi user store yang
di-sync ke Authentik. Mengikuti compose resmi
(https://docs.goauthentik.io/install-config/install/docker-compose/) +
panduan integrasi resmi NetBird
(https://docs.netbird.io/selfhosted/identity-providers/authentik,
https://integrations.goauthentik.io/networking/netbird).

Asumsi domain: `auth.cloudferdi.web.id` (record `A` ke IP VPS, cert via HAProxy).
Ganti di `.env` (`AUTH_DOMAIN`) + `haproxy/haproxy.cfg` kalau beda.

## Urutan setup

1. Secret (di VPS, jangan commit):

   ```bash
   cp .env.example .env
   echo "PG_PASS=$(openssl rand -base64 36 | tr -d '\n')" >> .env
   echo "AUTHENTIK_SECRET_KEY=$(openssl rand -base64 60 | tr -d '\n')" >> .env
   # + isi LLDAP_JWT_SECRET, LLDAP_KEY_SEED (openssl rand -base64 32),
   #   LLDAP_ADMIN_PASS (password admin lldap)
   ```

2. Cert untuk domain auth (HAProxy stop dulu bila port 80 dipakai):

   ```bash
   sudo certbot certonly --standalone -d auth.cloudferdi.web.id -m ferdilundju5443@gmail.com --agree-tos --no-eff-email
   sudo sh -c 'cat /etc/letsencrypt/live/auth.cloudferdi.web.id/fullchain.pem /etc/letsencrypt/live/auth.cloudferdi.web.id/privkey.pem > /path/ke/haproxy/certs/auth.pem'
   ```

3. Jalankan:

   ```bash
   cd authentik
   docker compose up -d
   ```

4. Setup awal: buka `https://auth.cloudferdi.web.id` → set password `akadmin`.

5. Buat user di LLDAP (`http://VPS:17170` via SSH tunnel, login `admin`),
   lalu di Authentik: Directory → Federation & Social login → LDAP Source:
   server `lldap`, port `3890`, Base DN `dc=cloudferdi,dc=web,dc=id`,
   bind `admin`, sync. User lldap sekarang bisa SSO.

6. NetBird via Authentik (Management Setup — embedded IdP tetap, tanpa ubah file):
   - Authentik → Applications → Providers → Create → OAuth2/OpenID:
     Name `NetBird`, Client type Confidential, Authorization flow
     `default-provider-authorization-explicit-consent`, Redirect URIs **kosong dulu**,
     Advanced → Selected Scopes tambah mapping OpenID `entitlements`.
     Catat Client ID + Secret.
   - Applications → Create: Name `NetBird`, Slug `netbird`, Provider = provider tadi.
   - NetBird dashboard → Settings → Identity Providers → Add:
     Type Generic OIDC (atau `authentik` bila ada), Name `Authentik`,
     Client ID/Secret dari atas,
     Issuer `https://auth.cloudferdi.web.id/application/o/netbird/`.
     Salin Redirect URL yang ditampilkan (JANGAN klik Add dulu).
   - Kembali ke provider Authentik → Edit → Redirect URIs: tempel URL tadi (Strict).
     Opsional: tambah `https://netbirdoverlay.cloudferdi.web.id/oauth2/logout/callback`.
   - Kembali ke NetBird → Add Provider → test login.

## Operasional

- `compose up` ulang aman: data di volume `authentik_db` + `lldap_data`.
  Jangan ubah secret setelah terisi. `down -v` menghapus semua user.
- Upgrade Authentik: samakan `AUTHENTIK_TAG` dengan compose resmi terbaru,
  `docker compose pull && docker compose up -d` (baca release notes dulu).

Skipped: mount docker.sock (tidak pakai outpost), Redis/etcd (tidak dibutuhkan
compose resmi), MFA enforcement (aktifkan per kebutuhan di Authentik).
