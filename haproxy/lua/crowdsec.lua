-- STUB fail-open placeholder for crowdsec.lua (NOT the real bouncer).
-- TODO(pin upstream v0.0.6): replace this file with the official crowdsec.lua +
-- templates/ from https://github.com/crowdsecurity/cs-haproxy-bouncer/releases/tag/v0.0.6
-- (steps + checksum slot in README.md next to this file). Never hand-roll bouncer logic.
-- Behavior until replaced: allow every request (fail-open), so `haproxy -c` passes
-- and traffic is unaffected before the real install.

core.register_action("crowdsec_allow", { "http-req" }, function(_txn)
  -- fail-open: no LAPI check in stub.
end)

core.register_service("reply_ban", "http", function(applet)
  applet:set_status(403)
  applet:add_header("content-type", "text/plain")
  applet:start_response()
  applet:send("Forbidden (crowdsec lua stub: upstream crowdsec.lua not installed yet).\n")
end)

core.register_service("reply_captcha", "http", function(applet)
  applet:set_status(200)
  applet:add_header("content-type", "text/plain")
  applet:start_response()
  applet:send("Captcha unavailable (crowdsec lua stub: upstream crowdsec.lua not installed yet).\n")
end)
