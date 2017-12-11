# Load All Modules - Detect Undefined Symbols #

Summary: load all modules - detect undefined symbols

All modules that compile on the guest OS and don't have init constraints are loaded, the rest are commented, see `kamailio-allmods.cfg`.

Following tests are done:

  * run kamailio -f kamailio-allmods.cfg
