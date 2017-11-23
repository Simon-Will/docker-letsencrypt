# Testing Procedure

This document describes the steps that should be executed to test whether the service does what it is supposed to.
After each change, restart the HAProxy service and check in a browser that exactly those domains have a valid certificate that are expected to have one after the respective step.

## Getting the first certificate.

* Domains specified: `www{1..3}.example.com`
* Expected outcome: A certificate for these domains is fetched.

Restart the service twice. Each time, check that the service tries to renew the certificate.

## Expanding the certificate.

* Domains specified: `www{1..10}.example.com`
* Expected outcome: The existing certificate is expanded.

Check in the logs that the certificate name has not changed.

## Failing to get a new certificate for a subset of domains.

* Domains specified: `www{2..10}.example.com`
* Expected outcome: Nothing is done and the logs mention an error.

Restart the service once again and check that the error occurs again.
`www1.example.com` should still have a valid certificate.

## Getting a new certificate for a subset of domains.

* Domains specified: `www{2..10}.example.com`
* Environment variables: `REMOVE_OLD_DOMAINS='true'`
* Expected outcome: `www1.example.com` does not have a valid certificate anymore, `www{2..10}.example.com` however do.

Check in the logs that the certificate name has changed. (Probably, `-0001` has been appended.
Restart the service. Check that the service tries to renew the new certificate.

## Reusing the first certificate

* Domains specified: `www{1..10}.example.com`
* Expected outcome: The first certificate is reused.

In the logs, it should say that the first certificate is used again.

## Failing to get a new certificate for a different set of domains.

* Domains specified: `www{5..50}.example.com`
* Expected outcome: Nothing is done and the logs mention an error.

The domains `www{1..10}.example.com` should still have a valid certificate.

## Getting a new certificate for a different set of domains.

* Domains specified: `www{5..50}.example.com`
* Environment variables: `REMOVE_OLD_DOMAINS='true'`
* Expected outcome: `www{1..4}.example.com` do not have a valid certificate anymore, `www{5..50}.example.com` however do.
