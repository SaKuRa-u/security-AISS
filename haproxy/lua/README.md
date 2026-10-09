# HAProxy Lua: CrowdSec classic bouncer (fail-open stub -> upstream pin)

`crowdsec.lua` next to this file is a minimal fail-open STUB so that
`haproxy -c` passes and traffic is unaffected before the real install.
It is NOT the bouncer. Do not extend it; replace it with upstream files.

## Pin

- Bouncer: `cs-haproxy-bouncer` **v0.0.6** (tagged Latest stable on
  2026-10-08; v0.0.7 is a pre-release).
- Release page: https://github.com/crowdsecurity/cs-haproxy-bouncer/releases
- Direct tag: https://github.com/crowdsecurity/cs-haproxy-bouncer/releases/tag/v0.0.6
- CrowdSec LAPI image pinned to match this setup: `crowdsecurity/crowdsec:v1.8.1`
  (https://github.com/crowdsecurity/crowdsec/releases/tag/v1.8.1).

## Install (on the VPS)

1. Download the release archive from the tag above
   (`crowdsec-haproxy-bouncer.tgz`).
2. Verify checksum (fill in from the release page after download):
   `sha256: <paste-official-checksum-here>  crowdsec-haproxy-bouncer.tgz`
3. Extract and copy ONLY these upstream paths:
   - `crowdsec.lua` -> `VPS/haproxy/lua/crowdsec.lua` (overwrite stub)
   - `templates/` -> `VPS/haproxy/lua/templates/`
4. Keep the mount layout expected by `haproxy.cfg`:
   - `lua-prepend-path /usr/local/etc/haproxy/lua/?.lua`
   - `lua-load /usr/local/etc/haproxy/lua/crowdsec.lua`
   - `BAN_TEMPLATE_PATH=/usr/local/etc/haproxy/lua/templates/ban.html`
5. Confirm `MAP_PATH=/tmp/crowdsec/community_blocklist.map` (writable at
   runtime) against the v0.0.6 `install.sh`/docs; adjust if upstream
   changed the default.
6. Re-run the config check:
   `docker run --rm -v "$PWD/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro" ... haproxy:3.4 haproxy -c -f ...`
   then `docker compose up -d haproxy` and watch
   `docker compose logs haproxy | grep -i crowdsec`.

## Why a stub

No Lua was written from memory: the real script + templates come from the
pinned upstream release only. The stub registers the same three names the
config references (`crowdsec_allow`, `reply_ban`, `reply_captcha`) as
fail-open no-ops.
