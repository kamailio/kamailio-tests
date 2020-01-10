--
--
--

AUTH_XKEYS_TIMEFRAME=90

-- SIP request routing
-- equivalent of request_route{}
function ksr_request_route()
	local timehdr = "";
	-- from nodes with auth xkeys support
    if KSR.hdr.is_present("X-AuthXKeys-Token") > 0
            and KSR.hdr.is_present("X-AuthXKeys-Time") > 0 then
        timehdr = KSR.pv.gete("$hdr(X-AuthXKeys-Time)");
        local tlimit = tonumber(timehdr);
        if tlimit ~= NILL and tlimit >= os.time() then
            if KSR.auth_xkeys.auth_xkeys_check("X-AuthXKeys-Token", "kid1", "sha256",
                    timehdr .. ":" .. KSR.pv.gete("$hdr(CSeq)") .. ":" .. KSR.pv.gete("$ci")
                    .. ":" .. KSR.pv.gete("$fu") .. ":" .. KSR.pv.gete("$ru")) > 0 then
                KSR.info("auth xkeys ok\n");
                KSR.sl.sl_send_reply(200, "ok");
                return 1;
            end
        end
        KSR.info("auth xkeys failed\n");
        KSR.sl.sl_send_reply(403, "Not allowed");
        return 1;
    end

	timehdr = tostring(os.time() + AUTH_XKEYS_TIMEFRAME);
    KSR.hdr.append("X-AuthXKeys-Time: " .. timehdr .. "\r\n");
    KSR.auth_xkeys.auth_xkeys_add("X-AuthXKeys-Token", "kid1", "sha256",
            timehdr .. ":" .. KSR.pv.gete("$hdr(CSeq)") .. ":" .. KSR.pv.gete("$ci")
            .. ":" .. KSR.kx.get_furi() .. ":" .. KSR.kx.get_ruri());
    KSR.setdsturi("sip:" .. KSR.pv.gete("$Ri") .. ":" .. KSR.pv.gete("$Rp"));
	KSR.forward();
	return 1;
end
