#!/bin/bash

# Default values
KC_VERSION="26.0.7"
ADMIN_NEW_PASSWORD=""

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --keycloak-url URL       Keycloak server URL (e.g., http://host.docker.internal:8080)"
    echo "  --db-url URL            Database connection URL (e.g., jdbc:postgresql://host.docker.internal:5432/keycloak)"
    echo "  --admin-user USER       Admin username"
    echo "  --admin-password PASS   Current admin password"
    echo "  --new-password PASS     New admin password"
    echo "  --db-user USER         Database username (required with --db-url)"
    echo "  --db-password PASS     Database password (required with --db-url)"
    echo "  --keycloak-version VER  Keycloak version (default: 26.0.7)"
    echo
    echo "Example using Keycloak API:"
    echo "  $0 --keycloak-url http://host.docker.internal:8080 --admin-user admin \\"
    echo "     --admin-password oldpass --new-password newpass"
    echo
    echo "Example using Database:"
    echo "  $0 --db-url jdbc:postgresql://host.docker.internal:5432/keycloak --db-user postgres \\"
    echo "     --db-password dbpass --admin-user admin --new-password newpass"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --keycloak-url)
            KC_SERVER="$2"
            shift 2
            ;;
        --db-url)
            DB_URL="$2"
            shift 2
            ;;
        --admin-user)
            ADMIN_USERNAME="$2"
            shift 2
            ;;
        --admin-password)
            ADMIN_PASSWORD="$2"
            shift 2
            ;;
        --new-password)
            ADMIN_NEW_PASSWORD="$2"
            shift 2
            ;;
        --db-user)
            DB_USER="$2"
            shift 2
            ;;
        --db-password)
            DB_PASSWORD="$2"
            shift 2
            ;;
        --keycloak-version)
            KC_VERSION="$2"
            shift 2
            ;;
        --help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$ADMIN_NEW_PASSWORD" ]; then
    echo "Error: --new-password is required"
    print_usage
    exit 1
fi

if [ -z "$KC_SERVER" ] && [ -z "$DB_URL" ]; then
    echo "Error: Either --keycloak-url or --db-url must be specified"
    print_usage
    exit 1
fi

# Additional validation for API method
if [ -n "$KC_SERVER" ]; then
    if [ -z "$ADMIN_USERNAME" ] || [ -z "$ADMIN_PASSWORD" ]; then
        echo "Error: --admin-user and --admin-password are required when using --keycloak-url"
        print_usage
        exit 1
    fi
fi

# Additional validation for DB method
if [ -n "$DB_URL" ]; then
    if [ -z "$ADMIN_USERNAME" ]; then
        echo "Error: --admin-user is required to identify which user's password to update"
        print_usage
        exit 1
    fi
fi

# Function to update password via Keycloak API
update_via_api() {
    # Check if protocol is specified
    if [[ ! "$KC_SERVER" =~ ^https?:// ]]; then
        echo "Error: Keycloak URL must include the protocol (http:// or https://)"
        exit 1
    fi

    # Warning for localhost usage
    if [[ "$KC_SERVER" =~ localhost ]]; then
        echo "Warning: Using 'localhost' in Keycloak URL will resolve to the Docker container's localhost,"
        echo "         not your host machine. Consider using 'host.docker.internal' instead."
        read -p "Do you want to continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    if [ -z "$ADMIN_PASSWORD" ]; then
        echo "Error: --admin-password is required when using --keycloak-url"
        exit 1
    fi

    docker run --rm --network host --entrypoint /bin/bash \
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
                --new-password \"$ADMIN_NEW_PASSWORD\"
        "
}

# Function to update password via database
update_via_db() {
    if [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
        echo "Error: --db-user and --db-password are required when using --db-url"
        exit 1
    fi

    # Extract database type from URL
    DB_TYPE=$(echo "$DB_URL" | sed -n 's/^jdbc:\([^:]*\):.*/\1/p')
    DB_HOST=$(echo "$DB_URL" | sed -n 's|^jdbc:[^:]*://\([^:/]*\).*|\1|p')
    DB_PORT=$(echo "$DB_URL" | sed -n 's|^jdbc:[^:]*://[^:]*:\([0-9]*\).*|\1|p')
    DB_NAME=$(echo "$DB_URL" | sed -n 's|^jdbc:[^:]*://[^/]*/\([^?]*\).*|\1|p')
    
    case "$DB_TYPE" in
        postgresql)
            # First get the user_id
            USER_ID=$(docker run --rm --network host \
                -e PGPASSWORD="$DB_PASSWORD" \
                postgres:latest \
                psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c "
                    SELECT id FROM user_entity 
                    WHERE username = '$ADMIN_USERNAME';
                ")
            
            # Trim whitespace from USER_ID
            USER_ID=$(echo "$USER_ID" | xargs)

            if [ -z "$USER_ID" ]; then
                echo "Error: User $ADMIN_USERNAME not found in database"
                exit 1
            fi

            # Generate new password hash and insert credential
            SQL_COMMAND=$(docker run --rm \
                -e PASSWORD="$ADMIN_NEW_PASSWORD" \
                -e USER_ID="$USER_ID" \
                python:3-slim python3 -c "
import os, sys
from base64 import b64encode
from hashlib import pbkdf2_hmac
import json
import uuid

password = os.environ['PASSWORD']
user_id = os.environ['USER_ID']
salt = os.urandom(16)
iterations = 27500
secret_value = pbkdf2_hmac('sha256', password.encode(), salt, iterations, dklen=64)

secret_data = json.dumps({'value': b64encode(secret_value).decode(), 'salt': b64encode(salt).decode()})
credential_data = json.dumps({'hashIterations': iterations, 'algorithm': 'pbkdf2-sha256'})
new_id = str(uuid.uuid4())

sql = 'DELETE FROM credential WHERE user_id = \\'' + user_id + '\\' AND type = \\'password\\'; '
sql += 'INSERT INTO credential (id, type, user_id, secret_data, credential_data, priority) '
sql += 'VALUES (\\'' + new_id + '\\', \\'password\\', \\'' + user_id + '\\', \\'' + secret_data + '\\', \\'' + credential_data + '\\', 10)'
print(sql)
")
            
            # Execute the SQL command
            docker run --rm --network host \
                -e PGPASSWORD="$DB_PASSWORD" \
                postgres:latest \
                psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "$SQL_COMMAND"

            echo "Password updated successfully for user $ADMIN_USERNAME"
            echo -e "\n\033[1;33mIMPORTANT:\033[0m You must restart your Keycloak server for the password change to take effect."
            echo -e "\nIf you're using Docker Compose, run:"
            echo -e "  docker compose restart keycloak\n"
            echo -e "If you're using standalone Docker, run:"
            echo -e "  docker restart <keycloak_container_name>\n"
            ;;
        mysql)
            echo "MySQL support coming soon"
            exit 1
            ;;
        *)
            echo "Error: Unsupported database type: $DB_TYPE"
            exit 1
            ;;
    esac
}

# Main execution
if [ -n "$KC_SERVER" ]; then
    update_via_api
elif [ -n "$DB_URL" ]; then
    update_via_db
fi

