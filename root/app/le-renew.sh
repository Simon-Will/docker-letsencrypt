#!/usr/bin/with-contenv bash

echo "<------------------------------------------------->"
echo
echo "<------------------------------------------------->"
echo "cronjob running on "$(date)

CERT_NAME_OPTION=''
if [ -f /config/donoteditthisfile.conf ]; then
  . /config/donoteditthisfile.conf
  if [ -n "$ORIGCERT_NAME" ]; then
    echo "Trying to renew certificate $ORIGCERT_NAME"
    CERT_NAME_OPTION=" --cert-name $ORIGCERT_NAME "
  else
    echo 'Warning: ORIGCERT_NAME is empty. Trying to renew all certificates.'
  fi
else
    echo 'Warning: The file /config/donoteditthisfile.conf could not be found. Trying to renew all certificates.'
fi

s6-svc -d /var/run/s6/services/nginx >/dev/null 2>&1

WEBROOT=/var/www/
mkdir -p "$WEBROOT"
WEBLOGDIR=/var/log/pythonhttpserver/
mkdir -p "$WEBLOGDIR"

echo "Starting Python SimpleHTTPServer in $WEBROOT logging to $WEBLOGDIR"
cd "$WEBROOT"
python -m SimpleHTTPServer 80 >"$WEBLOGDIR/stdout.log" 2>"$WEBLOGDIR/stderr.log" </dev/null &
HTTPSERVER_RENEWAL_PID="$!"

echo "Running certbot renew"
# shellcheck disable=SC2086
certbot renew $CERT_NAME_OPTION --non-interactive --preferred-challenges "${PREFERRED_CHALLENGES:-http,tls-sni}" --post-hook " cd /config/keys/letsencrypt && openssl pkcs12 -export -out privkey.pfx -inkey privkey.pem -in cert.pem -certfile chain.pem -passout pass: ; cd /config/keys/letsencrypt && mkdir -p /haproxy_certs && cat privkey.pem fullchain.pem > /haproxy_certs/cert1.pem"

echo "Killing Python SimpleHTTPServer"
kill "$HTTPSERVER_RENEWAL_PID"

s6-svc -u /var/run/s6/services/nginx >/dev/null 2>&1
# vim: ft=sh sts=2 sw=2 et si
