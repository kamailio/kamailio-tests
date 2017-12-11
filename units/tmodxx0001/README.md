# Load All Modules - Detect Undefined Symbols #

Summary: load all modules - detect undefined symbols

All modules that compile on the guest OS and don't have init constraints are loaded,
the rest are commented, see `kamailio-allmods.cfg`. Some modules have load conflicts
because they define same variables (e.g., $rtpstat is defined by rtpengine and rtpproxy).

Following tests are done:

  * run `kamailio -f kamailio-allmods.cfg`
  * run `kamailio -f kamailio-allmods.cfg -A WITH_IMS -A WITH_RTPPROXY`
