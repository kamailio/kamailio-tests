# Registrar - Wildcard Contact With Outbound #

Summary: registrar - wildcard contact with outbound and path

Following tests are done:

  * run kamailio with kamailio-tregxx0003.cfg (outbound_mode set to 1) and
    send with sipexer REGISTER requests that have two Via headers and a Path
    header, as received from an outbound edge proxy. The reply codes and
    the contacts returned are checked, and after a removal an OPTIONS request
    is answered with 404 when registered() finds no binding for the AoR:
    * `Contact: *` with `Expires: 0` removes all the bindings of the AoR
    * the same removal when the Path URI has no `ob` parameter
    * `Contact: *` with non-zero Expires, without Expires or together with
      another contact is rejected with 400 and the bindings are kept

Related to kamailio PR #5149.
