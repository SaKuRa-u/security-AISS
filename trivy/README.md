# Trivy — sapu bersih sekali jalan (VPS + node)

> Audit image + repo + secret + SBOM. Tidak ada daemon, tidak ada port:
> service `trivy` hanya jalan saat `docker compose run`. Setiap perintah
> di bawah dijalankan dari folder ini (`VPS/trivy`) kecuali disebut lain.

## 0. Syarat

```bash
df -h /tmp | tail -1        # sisa >2GB untuk DB + cache
docker compose config --quiet && echo "trivy compose OK"
docker compose run --rm trivy version
docker compose run --rm trivy image --download-db-only
```

Unduhan DB pertama 5–15 menit (sekali saja, tersimpan di volume
`trivy-cache`). Berikutnya cepat.

## 1. Scan image (simpan laporan, tempel ringkasannya)

```bash
mkdir -p /tmp/trivy-reports
for IMG in haproxy:3.4 crowdsecurity/crowdsec:v1.8.1 coraza-spoa:0.5.0 netbirdio/dashboard:latest netbirdio/netbird-server:latest postgres:16-alpine lldap/lldap:stable quay.io/coreos/etcd:v3.5.13 chrislusf/seaweedfs:latest; do
  NAME=$(echo $IMG | tr '/:' '__')
  docker compose run --rm trivy image --config /etc/trivy/trivy.yaml "$IMG" > /tmp/trivy-reports/$NAME.txt 2>&1
  grep -E "^Total:" /tmp/trivy-reports/$NAME.txt | head -8
done
```

Sesuaikan daftar dengan `docker images` bila tag beda (misal authentik
`ghcr.io/goauthentik/server:2026.8.3`). Tempel **hanya baris `Total:`**.
Di node: pola sama untuk image node (`postgres:16`, `adminer:latest`,
`seaweedfs`, `etcd`, `psp-web` rakitan) + `fs` atas folder app.

## 2. Scan repo (misconfig + secret)

```bash
docker compose run --rm trivy fs --config /etc/trivy/trivy.yaml --scanners misconfig,secret /scan > /tmp/trivy-reports/fs-vps.txt 2>&1
grep -E "^(FAIL|CRITICAL|HIGH|Total)" /tmp/trivy-reports/fs-vps.txt | head -30
```

Ekspektasi: secret scanner akan menunjuk secret ter-commit (sudah
diketahui) → perbaiki via `.env`, bukan via ignore.

## 3. SBOM (lampiran laporan, opsional murah)

```bash
docker compose run --rm -v /tmp/trivy-reports:/out trivy image --format cyclonedx --output /out/sbom-haproxy.cdx.json haproxy:3.4
```

## 4. Tabel pin versi (acuan triase hasil scan)

Legenda: Observed = terverifikasi sumber resmi; Inferred = perilaku tag
standar; Unverified = belum terkonfirmasi — JANGAN jadikan dasar klaim,
pembuktinya = output Trivy Fase 1.

| Image kini | Rekomendasi | Status |
|---|---|---|
| `haproxy:3.4` | PERTAHANKAN (`:3.4` mem-float patch otomatis; LTS s/d 2031-Q2; resmi dipakai `3.4.6`) | Inferred + Observed pakai |
| `crowdsecurity/crowdsec:v1.8.1` | PERTAHANKAN (latest stabil per releases resmi, 3 Sep 2026) | Observed |
| `coraza-spoa:0.5.0` (build source) | PERTAHANKAN; cek rilis baru di `github.com/corazawaf/coraza-spoa/releases` saat scan | Unverified |
| `ghcr.io/goauthentik/server:2026.8.3` | PERTAHANKAN; verifikasi seri `2026.8.x/2026.10.x` lebih baru sebelum bump | Unverified |
| `lldap/lldap:stable` | PIN KE TAG TANGGAL `2026-09-22` (varian sama; reproducible; isi = build Sep 2026). JANGAN ke `v0.6.3` (Mei 2026, lebih tua = potensi regresi fix) | Observed tag ada; Inferred isi |
| `netbirdio/dashboard:latest`, `netbird-server:latest` | PERTAHANKAN + PIN DIGEST pasca-scan (lihat §5); jaga sinkron mgmt+proxy (wajib sejak v0.76.1); cek versi via dashboard `GET /api/instance/version` | Unverified |
| `postgres:16-alpine` | PERTAHANKAN (float 16.x; 16.15 Agu 2026 per postgresql.org; EOL 2028) | Observed |
| `quay.io/coreos/etcd:v3.5.13` | FLAG: tua. Kandidat naik ke 3.5 termutakhir HANYA pasca-scan + cek kompat Patroni — JANGAN sentuh dulu (risiko quorum) | Unverified angka |
| `chrislusf/seaweedfs:latest` | PERTAHANKAN + PIN DIGEST pasca-scan | Unverified |
| `adminer:latest` (node) | FLAG: pin versi + pertimbangkan stop di produksi (restart-loop terobservasi) | Inferred |
| `aquasec/trivy:0.75.0` | PIN scanner ini (latest Okt 2026) | Observed |

## 5. Pin digest (anti-drift untuk tag bergerak, pasca-scan)

```bash
docker images --digests --format '{{.Repository}}:{{.Tag}} {{.Digest}}' | grep -E "netbird|seaweedfs|adminer|lldap"
```

Rekomendasi ditulis sebagai `image@sha256:...` di `.env` masing-masing
project (file `.env` gitignored; contoh di `.env.example`). Berlaku untuk
semua `:latest`/`:stable`.

## 6. Kejujuran riset (baca sebelum klaim "bebas CVE")

- Context7 MCP tidak terjangkau dari sesi ini (tool tidak terdaftar) dan
  pencarian web kena rate-limit di tengah jalan. Klaim versi di §4
  berlabel jujur di atas; sumber yang sempat terverifikasi: releases resmi
  CrowdSec, lldap, NetBird, postgresql.org, Docker Hub tags.
- "Bebas dari kasus Trivy" TIDAK dinyatakan oleh file ini — hanya oleh
  **output scan Fase 1** (`Total: 0` CRITICAL/HIGH atau sisa yang
  di-`.trivyignore` beralasan). Tabel §4 = titik mulai triase, bukan vonis.
- Jadwal ulang: tiap deploy besar + tiap bulan (DB CVE bergerak harian).
