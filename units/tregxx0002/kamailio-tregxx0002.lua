-- luacheck: globals KSR
function check ()
	local fields = {'ruid', 'expires', 'contact', 'received', 'path'}
	local str_x = '$xavp(rcd[0]=>%s[%d])'
	local str_y = 'check: %s%d exists\n'
	local val

	for i=0,2 do
		for _,field in ipairs(fields) do
			local xavp = string.format(str_x, field, i)
			val = KSR.pv.get(xavp)
			if val then
				local tmp = string.format('val %s%d:%s\n', field, i, tostring(val))
				KSR.dbg(tmp)
				KSR.err(string.format(str_y, field, i))
			end
		end
	end
end
