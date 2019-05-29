# openvpn-dockerfile
Dockerfile for OpenVPN server on Alpine Linux

Build
-----
```
$ docker build -t grffio/openvpn .
```
- Supported Args: `OPENVPN_VER=2.4.7-r0`, `EASYRSA_VER=3.0.6-r0`

Quick Start
-----------
```
$ docker run --name openvpn -d -p 1194:1194/tcp                     \
             -v /dir-to-cert:/etc/openvpn/certs --cap-add=NET_ADMIN \
             grffio/openvpn
```
- Supported Environment variables:
  - `OVPN_PROTO` - Protocol to use when connecting with the remote, tcp or udp (default: tcp)
  - `OVPN_NETWORK` - The network that will be used the VPN, subnet 255.255.255.0 (default: 10.36.54.0)
  - `OVPN_MAXCL` - Limit the number of concurrent clients (default: 2)
  - `OVPN_SERVERCN` - The CN that will be used to generate the certificate (default: example.com)
  - `OVPN_DEBUG` - The verbosity "9" of OpenVPN's logs (default: false)
 
- Exposed Ports:
  - 1194/tcp 1194/udp
