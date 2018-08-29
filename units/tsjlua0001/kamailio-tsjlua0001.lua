function ksr_request_route()

	KSR.sipjson.sj_serialize("0B", "$var(json)");

	KSR.dbg("===== json:\n" .. KSR.pv.getw("$var(json)")  .. "\n");
	KSR.sl.sl_send_reply("200", "OK");
	KSR.x.exit();

end
