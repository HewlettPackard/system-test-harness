#!/usr/bin/env bash
set -x
### Forcibly removes productC from Platform pkg database as it's impossible to skip pre-post scripts execution.

as_user_linux root /bin/rm -vrf /var/opt/Platform/install/$PRODUCTC_PACKAGE_NAME < /dev/null
