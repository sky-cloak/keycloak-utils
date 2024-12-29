#!/bin/bash
KC_SERVER="$1"
ADMIN_USERNAME="$2"
ADMIN_PASSWORD="$3"
NEW_ADMIN_PASSWORD="$4"
KC_VERSION="$5"

if [ -z "$ADMIN_PASSWORD" ] || [ -z "$ADMIN_USERNAME" ] || [ -z "$KC_SERVER" ] || [ -z "$NEW_ADMIN_PASSWORD" ]; then
    echo "Usage: $0 <kc_server> <admin_username> <admin_password> <new_admin_password> [<keycloak_version>]"
    echo "Example: $0 http://host.docker.internal:8080 admin oldpass newpass 26.0.7"
    exit 1
fi

# Check if protocol is specified
if [[ ! "$KC_SERVER" =~ ^https?:// ]]; then
    echo "Error: KC_SERVER must include the protocol (http:// or https://)"
    echo "Example: http://host.docker.internal:8080"
    exit 1
fi

# Warning for localhost usage
if [[ "$KC_SERVER" =~ localhost ]]; then
    echo "Warning: Using 'localhost' in KC_SERVER will resolve to the Docker container's localhost,"
    echo "         not your host machine. Consider using 'host.docker.internal' instead."
    echo "Example: http://host.docker.internal:8080"
    read -p "Do you want to continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if KC_VERSION is provided, if not, default to 26.0.7
if [ -z "$KC_VERSION" ]; then
    KC_VERSION="26.0.7"
fi

# Run both commands in a single container using bash
docker run --rm --entrypoint /bin/bash \
    quay.io/keycloak/keycloak:"$KC_VERSION" \
    -c "
        /opt/keycloak/bin/kcadm.sh config credentials \
            --server \"$KC_SERVER\" \
            --realm master \
            --user \"$ADMIN_USERNAME\" \
            --password \"$ADMIN_PASSWORD\" \
            --config /tmp/.keycloak/kcadm.config && \
        /opt/keycloak/bin/kcadm.sh set-password \
            --config /tmp/.keycloak/kcadm.config \
            -r master \
            --username \"$ADMIN_USERNAME\" \
            --new-password \"$NEW_ADMIN_PASSWORD\"
    "

