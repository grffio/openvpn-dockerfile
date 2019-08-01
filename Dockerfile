FROM alpine:3.10
ARG OPENVPN_VER="2.4.7-r1"
ARG EASYRSA_VER="3.0.6-r0"
RUN apk add --update openvpn=${OPENVPN_VER} easy-rsa=${EASYRSA_VER} iptables bash tini
COPY run.sh /usr/local/bin/
COPY openvpn.conf /etc/openvpn/
COPY vars /usr/share/easy-rsa/
EXPOSE 1194/tcp 1194/udp
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["run.sh"]
