# Regisrar - xavp_rcd Tests #

Summary: regisrar - check xavp_rcd values

Following tests are done:

  * run kamailio with kamailio-tregxx0001.cfg send a REGISTER msg and check the
	xavp_rcd values depending of the xavp_rcd_mask paramater after save(), send
	a MESSAGE msg and check xavp_rcd values depending of the xavp_rcd_mask
	paramater after lookup().

  * run that check for different values of xavp_rcd_mask
