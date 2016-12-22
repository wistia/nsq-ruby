# Changelog

## 2.0.4

* Bugfix: Close connection socket when calling `.terminate`.

## 2.0.3

* Bugfix: Ensure write_loop ends; pass message via write_queue (#32)

## 2.0.2

* Bugfix: Use `File.read` instead of `File.open` to avoid leaving open file handles around.

## 2.0.1

* Bugfix: Allow discovery of ephemeral topics when using JRuby.

## 2.0.0

* Enable TLS connections without any client-side keys, certificates or certificate authorities.
* Deprecate `ssl_context` connection setting, rename it to `tls_options` moving forward.
