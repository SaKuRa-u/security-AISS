# HAProxy 3.4 LTS (edge reverse proxy)

Image `haproxy:3.4` — rilis LTS, EOL 2031-Q2. Bukan 3.5-dev.
Ref: https://docs.haproxy.org/3.4/intro.html

Sertifikat dari **Let's Encrypt via certbot di host**. HAProxy hanya load file `.pem`.

## Struktur

```text
haproxy/
  docker-compose.yml  # publish 80/443, join network eksternal `edge`
  haproxy.cfg         # frontend + backend (saat ini: NetBird)
  certs/              # taruh netbird.pem di sini (di-ignore git)
```

## Urutan setup (HAProxy dulu, sesuai rencana)

1. Buat network bersama sekali saja (dipakai semua proyek edge):

   ```bash
   docker network create edge
   ```

2. Minta sertifikat Let's Encrypt di host (contoh domain `netbirdoverlay.cloudferdi.web.id`).
   Port 80 harus bebas saat issuance, jadi lakukan sebelum `up`
   (atau `docker compose stop haproxy` dulu):

   ```bash
   sudo certbot certonly --standalone -d netbirdoverlay.cloudferdi.web.id -m ferdilundju5443@gmail.com --agree-tos --no-eff-email
   ```

3. Gabungkan cert untuk HAProxy (HAProxy butuh cert+key satu file):

   ```bash
   cat /etc/letsencrypt/live/netbirdoverlay.cloudferdi.web.id/fullchain.pem \
       /etc/letsencrypt/live/netbirdoverlay.cloudferdi.web.id/privkey.pem \
       > certs/netbird.pem
   ```

3a. Opsional — boot awal tanpa Let's Encrypt (self-signed sementara).
HAProxy menolak start tanpa file cert, jadi untuk verifikasi "HAProxy dulu"
sebelum domain mengarah ke VPS, buat cert dummy (jangan dipakai produksi,
browser akan warning):

   ```bash
   mkdir -p certs
   openssl req -x509 -newkey rsa:2048 -keyout certs/netbird.pem -out certs/netbird.pem -days 1 -nodes -subj "/CN=netbirdoverlay.cloudferdi.web.id"
   ```

   File ini di-ignore git. Ganti dengan gabungan cert asli (langkah 3) sebelum go-live.

4. Jalankan:

   ```bash
   cd haproxy
   docker compose up -d
   docker compose logs -f haproxy
   ```

   Backend masih DOWN/merah = normal, NetBird-nya memang belum `up`.

5. Renewal otomatis (certbot + hook gabung ulang + restart):

   ```bash
   sudo certbot renew \
     --pre-hook "docker stop haproxy || true" \
     --deploy-hook "cat /etc/letsencrypt/live/netbirdoverlay.cloudferdi.web.id/fullchain.pem /etc/letsencrypt/live/netbirdoverlay.cloudferdi.web.id/privkey.pem > /path/to/haproxy/certs/netbird.pem" \
     --post-hook "docker start haproxy || true"
   ```

   Downtime hanya hitungan detik tiap renewal (~60 hari). Alternatif tanpa stop:
   DNS-01 sesuai plugin provider DNS kamu (mendukung wildcard juga).

## Verifikasi

```bash
docker compose config --quiet && echo "compose OK"
haproxy -c -f haproxy.cfg   # atau via container, lihat bawah
curl -skf https://netbirdoverlay.cloudferdi.web.id/oauth2/.well-known/openid-configuration
```

Cek config memakai image yang sama dengan runtime:

```bash
docker run --rm -v "$PWD/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro" haproxy:3.4 haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
```

Skipped: halaman stats, ACME bawaan HAProxy 3.4. Tambahkan saat butuh observasi /
tanpa certbot — backend tidak berubah.
