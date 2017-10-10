# gorgor/docker-letsencrypt

This project is a fork of the docker image [`linuxserver/letsencrypt`](https://hub.docker.com/r/linuxserver/letsencrypt/) with the goal of making it possible to use it behind a HAProxy service of the image [`dockercloud/haproxy`](https://hub.docker.com/r/dockercloud/haproxy/).

The original README `README_linuxserver.md` documents all the options of the original image; this README merely documents the additional options.

## Concept

This Let’s Encrypt service is supposed to be run behind a HAProxy server, along with several other services for all of which HAProxy acts as the load balancer.
That makes it necessary for the Let’s Encrypt service to be aware of the HAProxy, e.g. by waiting with its requests for certificates until a connection through HAProxy can be established and by concatenating the key and the certificate chain into a single file apt for consumption by HAProxy.

## Example configuration

Here is an example Docker Compose file for HAProxy balancing the load between three web services and this Let’s Encrypt service.
The web services use the service [`whalesalad/docker-debug`](https://hub.docker.com/r/whalesalad/docker-debug/) because it displays helpful debugging information on port 8080.

Refer to `dockercloud/haproxy`’s documentation for information on how to build a Stackfile.

```yaml
---
version: '3'

services:

  web1:
    image: whalesalad/docker-debug
    environment:
      VIRTUAL_HOST: 'https://www1.example.com, http://www1.example.com, www1.example.com'
      VIRTUAL_HOST_WEIGHT: '0'
    networks:
      proxynet:
        aliases:
          - web1

  web2:
    image: whalesalad/docker-debug
    environment:
      VIRTUAL_HOST: 'https://www2.example.com, http://www2.example.com, www2.example.com'
      VIRTUAL_HOST_WEIGHT: '0'
    networks:
      proxynet:
        aliases:
          - web2

  web3:
    image: whalesalad/docker-debug
    environment:
      VIRTUAL_HOST: 'http://www3.example.com, www3.example.com'
      VIRTUAL_HOST_WEIGHT: '0'
    networks:
      proxynet:
        aliases:
          - web3

  haproxy:
    image: dockercloud/haproxy:staging
    environment:
      STATS_AUTH: 'haadmin:secure'
      EXTRA_GLOBAL_SETTINGS: 'debug'
      CERT_FOLDER: '/certs/'
    volumes:
      - '/var/run/docker.sock:/var/run/docker.sock'
      - './haproxy_certs/:/certs/'
    ports:
      - '80:80'
      - '443:443'
      - '1936:1936'  # For the statistics page
    links:
      - web1
      - web2
      - web3
      - letsencrypt
    networks:
      proxynet:
        aliases:
          - haproxy

  letsencrypt:
    image: gorgor/docker-letsencrypt:81
    environment:
      EMAIL: 'admin@example.com'
      URL: 'example.com'
      SUBDOMAINS: 'www1,www2'  # Get certificates for www1.example.com and www2.example.com
      ONLY_SUBDOMAINS: 'true'
      VIRTUAL_HOST: 'http://*/.well-known/acme-challenge/*, http://*/.well-known/acme-challenge'
      VIRTUAL_HOST_WEIGHT: '1'  # So that the VIRTUAL_HOST rules of this service have preference over those of the other services; cf. dockercloud/haproxy documentation
      EXCLUDE_PORTS: '443'  # Not needed for the HTTP ACME challenge
      PREFERRED_CHALLENGES: 'http'
      HAPROXY_DEFAULT_SSL_CERT: |
        -----BEGIN PRIVATE KEY-----
        MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQD8UxSkXb5NzLYe
        ZqzZC9z4ps8BA3w1lmt3BCNTWoCYhpdrqiqez0qTfHALlPhySf8pU/rTUsq7sIv+
        yYJPnM2lAh7LlxI69ShIOC88nMYc65gOWHIiNqI88oLwYy8GM5PWG5N3uOgWCZ3w
        MHneoCUr1DdquOpb8aSRI+eUu3QsR+jxnM103KtR4I4aLRC5KobcWfqIIkdDzEyd
        RfzDarnODCaemmeXY/xGVwqjSg2FdPKWD0QNPX30hyXTNoIg/bdjjp3W4yufbxlK
        a+zW5m9K1zPpderxd8Y3DagSHhu5C0mXp28NGaiZIbTbaSwkbq1o/+Z24T9ZG5DG
        bCUy2V/LAgMBAAECggEAFvBeogq7sEr6C41+DUVc02Ymz4rHkf+YyXsg0wUZR8SE
        o48WzNU/jGT1srfaVlmPzuwJk4ilUabdM06SgDZbI7MrpYqYZ6+998LT2IjQIfTx
        H+y+g4m/+hZ5/Oyna8Lon8BmCa5PuyEosJtXmPuqJW/nkdY5yB4Rvfgrp4PbLeM1
        fdRdJfSINWiEZDuJqR091IFah15bBMkaSOCjcrJclIC3O+4Lno4sujFaJ6dhuQGW
        tMRO9lj0HshVcW6/KCZyt++gG9NRQgpfjj/4Uc5nYR4fOwYMBdk5RpiW0zDISa1N
        gYFY52VYQjdBaO1KjP7Q2w8olqHR17nHQlVxWXnDkQKBgQD/sMWylCZpFsW7wtmh
        Wb693nGNjN0M/hx9k/VuuxRV2P3CNFQ3un8aFk7HCFicwtdDc0HLFE4841fbkjAS
        4JL1M5lxwBkpW061s50a9bl7Myw2lvWwO75Wa1yk6XMDfCBoQaZFOLndSS5xs9Xn
        tCkxA9PoY++EktqoVWVUAX+x/wKBgQD8oUPxRYb8zE20JVCakel3n1Qkw+Puxbl5
        MDQYrJEzc+0lkanOCwzJxC47e/DHn6uIMTIzKkPLQwHoIFyaGDdrCGmyr8cgXvQ8
        YEJ2tllUtC1AeV/fc5Y9tBCux8Arz7Y8vGb6iJGmuRHJCIXMSg7AdgO0Q9Lbyv8K
        H4e7q2p6NQKBgQD76vS9n43AmHk1JyM4/60YcOO8LP9V37++UlrMQHImquZJwzj+
        tzanQzdWjfiQar+gaxx1s4nqH6veX8gRsUXZZH9YPYYM4zNHfrHZcCTRJ3f2SQHE
        IvjDOIBM0t1In7FmRthE90DYr1OdHywvX6f97OGJ43yHSBE7LPfqrpdbjQKBgQDW
        xbMhV16fZIFa+a5A+nNlg0rhxrfssqQv508i+vKmr5OZMPEPfk1s6x/y6jeVPqVx
        r4FiBjiEgX8JfRm814GluQ1DIDVFy/QPsDZQ/k2LuXIPMiDTs0yzQHY+YQt7M6dW
        k0VpENnix8vbASfeucc40BvuEQseWMHiNVQLtHtdUQKBgFPU3IhekthOlkspR02x
        qAsQzHX4AEK98Ao5TGo4upRu2pCyX/GkZi53xijOegvnZ738Xak8ih0Rp24iTkNT
        KkFIlISnMmc1QYI8SIPp0nTBHyfL9TLB6XKgNPgsDQ1wH0IrtA7xSjsqyhm0MsZr
        fv5sOjK2yvHonAnJtavUAFRc
        -----END PRIVATE KEY-----
        -----BEGIN CERTIFICATE-----
        MIIC6zCCAdOgAwIBAgIJALW8JYCigr/VMA0GCSqGSIb3DQEBCwUAMAwxCjAIBgNV
        BAMMASowHhcNMTcwODA3MTIyNDU1WhcNMTcwOTA2MTIyNDU1WjAMMQowCAYDVQQD
        DAEqMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA/FMUpF2+Tcy2Hmas
        2Qvc+KbPAQN8NZZrdwQjU1qAmIaXa6oqns9Kk3xwC5T4ckn/KVP601LKu7CL/smC
        T5zNpQIey5cSOvUoSDgvPJzGHOuYDlhyIjaiPPKC8GMvBjOT1huTd7joFgmd8DB5
        3qAlK9Q3arjqW/GkkSPnlLt0LEfo8ZzNdNyrUeCOGi0QuSqG3Fn6iCJHQ8xMnUX8
        w2q5zgwmnppnl2P8RlcKo0oNhXTylg9EDT199Icl0zaCIP23Y46d1uMrn28ZSmvs
        1uZvStcz6XXq8XfGNw2oEh4buQtJl6dvDRmomSG022ksJG6taP/mduE/WRuQxmwl
        MtlfywIDAQABo1AwTjAdBgNVHQ4EFgQU7SjW7YK+o1J2SDA9U58U6EodBMAwHwYD
        VR0jBBgwFoAU7SjW7YK+o1J2SDA9U58U6EodBMAwDAYDVR0TBAUwAwEB/zANBgkq
        hkiG9w0BAQsFAAOCAQEAG5BfDwPXoGwj/p5/nqlYZOioWutpSZWdmg+DjYssFYRJ
        XNGrR8rwAMF3xkDELBQLUmFpuyoGN6BHgwWcwLLg1a8lanegbeqeBBUAYfQAdxxJ
        C1KfXlKfZJx2y7VerGo54qV6y0djDxp01Lc8UBgaRjajD0RNsz2iaVdg4mnC3OSH
        8QI4H6pq2WEuHn/ihfcCkUkKlmaGObEVjPPsoYkRkSLnercBFgMO648AG2nfNIKh
        OOJnhWzyKy0Sp7FtGM1FLo7hF8tLDOi6QdgLLpsJPlM7FPVGitXmS6CJ0Xzh4zK5
        H6kW3i7yEEcS7YQM8UoigUv0ol1gYqW8nqqgh75s4Q==
        -----END CERTIFICATE-----
    volumes:
      - ./haproxy_certs:/haproxy_certs/
      - ./etc/letsencrypt:/config/etc/letsencrypt/
    privileged: true  # Necessary for fail2ban's access to iptables; not necessary if fail2ban is not used
    networks:
      proxynet:
        aliases:
          - letsencrypt

networks:
  proxynet:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.name: proxynet0
```

## Environment variables

|Environment Variable|Default|Description|
|:------------------:|:-----:|:---------:|
|`HAPROXY_DEFAULT_SSL_CERT`|*None*|A concatenation of SSL key and certificate chain that is going to be saved as `/haproxy_certs/cert0.pem`. This is necessary if you want to provide a self-signed default certificate, as `dockercloud/haproxy` does not use its environment variable `DEFAULT_SSL_CERT` if you supply a `CERT_FOLDER`.|
|`TEST_CERT`|*None*|If this variable is `TRUE`, `true` or `1`, the option `--test-cert` is given to Certbot in order to get a staging certificate from Let’s Encrypt, which is not going to count into your certificate limit. Be aware that this certificate will cause a `SEC_ERROR_UNKNOWN_ISSUER`.|
|`MAX_TRIES`|`3`|Sometimes, HAProxy needs a few seconds to notice that the Let’s Encrypt service is listening for a connection. Therefore, `MAX_TRIES` attempts are made to get the certificate.|
|`PREFERRED_CHALLENGES`|`http,tls-sni`|This variable specifies the preferred challenges to fulfil in order to get the certificate. Refer to [Certbot’s documentation](https://certbot.eff.org/docs/using.html#getting-certificates-and-choosing-plugins) and the [IETF ACME draft](https://tools.ietf.org/html/draft-ietf-acme-acme-07#section-8) for further information. Behind HAProxy, using `tls-sni` is not possible (at least not easily), therefore `http` is the obvious choice and is mentioned before `tls-sni`.|
|`EXPAND_CERTIFICATE`|*None*|**Unless** this variable is `FALSE`, `false` or `0`, the option `--expand` is given to Certbot in order to expand an exisiting certificate to new domains. Specifying a false value is currently untested.|
