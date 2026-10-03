FROM alpine:3.23@sha256:85fe1e81d6758c208f3e1eed4338a1997e19d4be002d4dd32d3100c9a8c010a0 AS download
ARG TARGETARCH=amd64
RUN apk add --no-cache ca-certificates curl xz \
    && case "$TARGETARCH" in \
         amd64) checksum=32f6665df7573ab67d99e19737b917a680f1a18769b4f99c841d332a72301f82 ;; \
         arm64) checksum=fa157b887acbbbbe513343d5ac7349e65b89bfaca46b2d93c93d0492a03bbb26 ;; \
         *) exit 1 ;; \
       esac \
    && curl -fsSL "https://github.com/jkroepke/openvpn-auth-oauth2/releases/download/v2.2.1/openvpn-auth-oauth2_2.2.1_linux_${TARGETARCH}.tar.xz" -o /tmp/auth.tar.xz \
    && printf '%s  /tmp/auth.tar.xz\n' "$checksum" | sha256sum -c - \
    && mkdir -p /usr/share/licenses/openvpn-auth-oauth2 \
    && tar -xJf /tmp/auth.tar.xz -C /usr/local/bin openvpn-auth-oauth2 LICENSE.txt \
    && mv /usr/local/bin/LICENSE.txt /usr/share/licenses/openvpn-auth-oauth2/LICENSE

FROM alpine:3.23@sha256:85fe1e81d6758c208f3e1eed4338a1997e19d4be002d4dd32d3100c9a8c010a0
RUN apk add --no-cache openvpn=2.6.20-r0 iptables iproute2 ca-certificates openssl \
    && mkdir -p /run/openvpn
COPY --from=download /usr/local/bin/openvpn-auth-oauth2 /usr/local/bin/openvpn-auth-oauth2
COPY --from=download /usr/share/licenses/openvpn-auth-oauth2/LICENSE /usr/share/licenses/openvpn-auth-oauth2/LICENSE
COPY start-openvpn.sh /usr/local/bin/start-openvpn
RUN chmod 0755 /usr/local/bin/start-openvpn
CMD ["/usr/local/bin/start-openvpn"]
