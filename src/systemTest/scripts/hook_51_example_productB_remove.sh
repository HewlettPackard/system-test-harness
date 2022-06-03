#!/usr/bin/env bash
set -x
### Forcibly removes ProductB from Platform pkg database as it's impossible to skip pre-post scripts execution.

as_user_linux root /bin/rm -vrf /var/opt/Platform/install/$PRODUCTB_PACKAGE_NAME < /dev/null
