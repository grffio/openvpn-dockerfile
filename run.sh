#!/usr/bin/env bash

set -e

# Variables
confFile="/etc/openvpn/openvpn.conf"
certDir="/etc/openvpn/certs"

# Check environment variables and set default values
_checkEnv() {
    if [ -z "${OVPN_PROTO}" ]; then
        export OVPN_PROTO="tcp"
    fi
    if [ -z "${OVPN_NETWORK}" ]; then
        export OVPN_NETWORK="10.36.54.0"
    fi
    if [ -z "${OVPN_MAXCL}" ]; then
        export OVPN_MAXCL="2"
    fi
    if [ -z "${OVPN_SERVERCN}" ]; then
        export OVPN_SERVERCN="example.com"
    fi
    if [ -z "${OVPN_DEBUG}" ]; then
        verb="3"
    elif [ "${OVPN_DEBUG}" == "true" ]; then
        verb="9"
    fi
}

# Check for certificates and generate if not exist
_checkCerts() {
    files=(ca.crt server.crt server.key ta.key)
    for f in ${files[*]}; do
        if [ ! -f ${certDir}/${f} ]; then
            echo "Warning: not found ${f} in ${certDir}"
            _generateCerts
            break
        fi
        echo ${f}
    done
}

# Generate certificates
_generateCerts() {
    echo "Info: generating certificates"
    
    easyrsacmd="/usr/share/easy-rsa/easyrsa"
    export TEMP_PKI_DIR=$(mktemp -d)
    
    ${easyrsacmd} init-pki
    openvpn --genkey --secret ${TEMP_PKI_DIR}/ta.key
    dd if=/dev/urandom of=${TEMP_PKI_DIR}/.rnd bs=256 count=1
    ${easyrsacmd} build-ca nopass
    ${easyrsacmd} build-server-full server nopass
    ${easyrsacmd} build-client-full client nopass

    mkdir -p ${certDir}
    files=(server client)
    for f in ${files[*]}; do
        openssl x509 -in ${TEMP_PKI_DIR}/issued/${f}.crt -out ${TEMP_PKI_DIR}/issued/${f}.crt -outform PEM
        cp -f ${TEMP_PKI_DIR}/issued/${f}.crt ${certDir}
        cp -f ${TEMP_PKI_DIR}/private/${f}.key ${certDir}
    done
    cp -f ${TEMP_PKI_DIR}/{ta.key,ca.crt} ${certDir}
    
    rm -rf ${TEMP_PKI_DIR}
    unset "TEMP_PKI_DIR"
}

# Amending variables in config file
_configAmend() {
    sed -i 's/_proto_/'${OVPN_PROTO}'/g' ${confFile} && \
    sed -i 's/_network_/'${OVPN_NETWORK}'/g' ${confFile} && \
    sed -i 's/_maxcl_/'${OVPN_MAXCL}'/g' ${confFile} && \
    sed -i 's/_verb_/'${verb}'/g' ${confFile}
}

# Preparing system parameters
_sysPrep() {
    if [ ! -e /dev/net/tun ]; then
        mkdir -p /dev/net
        mknod /dev/net/tun c 10 200
        chmod 600 /dev/net/tun
    fi

    iptables -t nat -A POSTROUTING -j MASQUERADE
    iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
}

# Starting openvpn
_startOpenvpn() {
    if (pgrep -fl openvpn >/dev/null 2>&1); then
        echo "Info: openvpn process already running, killing..."
        pkill -9 openvpn
    fi

    openvpn --config ${confFile} &
    sleep 1
    echo "Info: openvpn process started!"
}

# Print client config
_printClientConfig() {
    echo "#=== Client Config Start ===#"
    echo "
client
remote ### CHANGEME ### 
port ### CHANGEME ###
proto ${OVPN_PROTO}
dev tun
resolv-retry infinite
tls-client
tls-timeout 120
key-direction 1
<ca>
$(cat ${certDir}/ca.crt)
</ca>
<cert>
$(cat ${certDir}/client.crt)
</cert>
<key>
$(cat ${certDir}/client.key)
</key>
<tls-auth>
$(cat ${certDir}/ta.key)
</tls-auth>
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
tls-version-min 1.2
tls-cipher TLS-ECDHE-ECDSA-WITH-AES-256-GCM-SHA384
verb 3
    "
    echo "#=== Client Config End ===#"
}

# Checking process is running
_healthCheck() {
    while (pgrep -fl openvpn >/dev/null 2>&1)
    do
        sleep 5
    done

    echo "Error: openvpn is not running, exiting..."
    exit 1
}

_checkEnv
_checkCerts
_configAmend
_sysPrep
_startOpenvpn
_printClientConfig
_healthCheck
