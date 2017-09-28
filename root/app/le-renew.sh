#!/usr/bin/with-contenv bash

echo "<------------------------------------------------->"
echo
echo "<------------------------------------------------->"
echo "cronjob running on "$(date)
echo "Running certbot renew"
certbot -n renew --standalone --pre-hook "s6-svc -d /var/run/s6/services/nginx" --post-hook "s6-svc -u /var/run/s6/services/nginx ; cd /config/keys/letsencrypt && openssl pkcs12 -export -out privkey.pfx -inkey privkey.pem -in cert.pem -certfile chain.pem -passout pass: ; cd /config/keys/letsencrypt && mkdir -p /haproxy_certs && cat privkey.pem fullchain.pem > /haproxy_certs/cert1.pem"

if [ -e /haproxy_certs/cert0.pem -a -e /haproxy_certs/cert1.pem ]; then
  echo 'Removing /haproxy_certs/cert0.pem'
  rm /haproxy_certs/cert0.pem
fi
