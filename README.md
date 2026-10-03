# OpenVPN Community + OAuth2 container

An OCI image with OpenVPN Community 2.6.20 (Alpine package) and
`openvpn-auth-oauth2` 2.2.1. It provides both binaries and the
`start-openvpn` entrypoint. Supply server configuration, certificates,
secrets, and network settings at deployment time; none are built into the image.

The default command starts OpenVPN. To run the OAuth2 management client in a
second container from the same image, set its command to
`/usr/local/bin/openvpn-auth-oauth2` and provide its config file with `--config`.
The OAuth2 binary is downloaded from its upstream release with a pinned SHA-256
checksum. The image supports `linux/amd64` and `linux/arm64`.

`start-openvpn` expects `VPN_CIDR`, a space-separated `PRIVATE_CIDRS` allowlist,
and optional `VPN_DNS`. It reads `/etc/openvpn/config/server.conf` and writes a
runtime copy in `/run/openvpn`. The caller supplies `/dev/net/tun`, IP forwarding,
and the `NET_ADMIN` capability. It restricts forwarded client traffic to the
configured destination CIDRs and applies NAT for those destinations.

```bash
docker build -f Containerfile -t openvpn-community-oauth2:local .
docker run --rm openvpn-community-oauth2:local openvpn --version
docker run --rm openvpn-community-oauth2:local openvpn-auth-oauth2 --version
```

GitHub Actions builds pull requests without publishing. The build checks that
the OAuth2 executable matches the target CPU architecture. A push to `main`
publishes `edge` and a commit SHA tag. A tag such as `v2.2.1-2` publishes
`ghcr.io/modulairy/openvpn-community-oauth2:2.2.1-2`.

This repository's scripts are MIT licensed; see [LICENSE](LICENSE). The image
also contains OpenVPN (GPL-2.0) and `openvpn-auth-oauth2` (MIT); their upstream
license terms apply to those components.
