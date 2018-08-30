local cjson = require "cjson"

function ksr_request_route()

	KSR.sipjson.sj_serialize("0B", "$var(json)");

	local vjson = KSR.pv.getw("$var(json)");
	if string.len(vjson) < 10 then
		KSR.dbg("===== short json:\n" .. vjson  .. "\n");
		KSR.sl.sl_send_reply("200", "OK");
		KSR.x.exit();
	end

	local sjv = cjson.decode(vjson);
	if sjv["rU"] == nil or string.len(sjv["rU"]) < 1 then
		KSR.dbg("===== rU key is not set\n");
	else
		KSR.dbg("===== rU key is set: " .. sjv["rU"] .. "\n");
	end

	KSR.dbg("===== long json:\n" .. vjson  .. "\n");
	KSR.sl.sl_send_reply("200", "OK");
	KSR.x.exit();

end
