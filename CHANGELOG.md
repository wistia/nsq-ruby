# Changelog

## 2.0.1

* Bugfix: URI escape topic for discovery to handle #ephemeral topics

## 2.0.0

* Enable TLS connections without any client-side keys, certificates or certificate authorities.
* Deprecate `ssl_context` connection setting, rename it to `tls_options` moving forward.
