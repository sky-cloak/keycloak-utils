# Keycloak Utility Scripts

This repository contains utility scripts for managing Keycloak instances. Each script provides specific functionality for Keycloak administration tasks.

## Available Scripts

### reset-admin-password.sh

This script provides two methods to reset a Keycloak admin password:
1. Using Keycloak's REST API (recommended)
2. Direct database update (use with caution)

#### Prerequisites

- Docker installed and running
- Either:
  - Access to a running Keycloak instance (for API method)
  - Access to the Keycloak database (for database method)
- Python 3 (automatically handled via Docker)

#### Usage

```bash
./reset-admin-password.sh [OPTIONS]
```

##### Options:
- `--keycloak-url URL`: Keycloak server URL (e.g., http://host.docker.internal:8080)
- `--db-url URL`: Database connection URL (e.g., jdbc:postgresql://host.docker.internal:5432/keycloak)
- `--admin-user USER`: Username of the account to update
- `--admin-password PASS`: Current admin password (required only with --keycloak-url)
- `--new-password PASS`: New password to set
- `--db-user USER`: Database username (required with --db-url)
- `--db-password PASS`: Database password (required with --db-url)
- `--keycloak-version VER`: Keycloak version (default: 26.0.7)

##### Examples:

Using Keycloak API (recommended):
```bash
./reset-admin-password.sh \
    --keycloak-url http://host.docker.internal:8080 \
    --admin-user admin \
    --admin-password oldpass \
    --new-password newpass
```

Using Database (use with caution):
```bash
./reset-admin-password.sh \
    --db-url jdbc:postgresql://host.docker.internal:5432/keycloak \
    --db-user keycloak \
    --db-password dbpass \
    --admin-user admin \
    --new-password newpass
```

#### Important Notes

1. When using `--keycloak-url`:
   - Do NOT use 'localhost' as it refers to the Docker container's network
   - Use 'host.docker.internal' for Docker Desktop (Windows/Mac)
   - Use actual IP address for Linux hosts
   - Always include the protocol (http:// or https://)
   - No restart required after password change

2. When using `--db-url`:
   - Currently supports PostgreSQL
   - Direct database updates bypass Keycloak's security measures
   - Use this method only when the API method is not available
   - Backup your database before attempting direct updates
   - **Requires Keycloak restart after password change**
   - If using Docker Compose: `docker compose restart keycloak`
   - If using standalone Docker: `docker restart <keycloak_container_name>`

#### Database Support

Currently supported databases:
- PostgreSQL ✅

#### Security Considerations

- Always use HTTPS in production environments
- Backup your database before making direct database changes
- Consider using environment variables for sensitive information
- Regularly rotate admin passwords
- Keep your Keycloak version updated
- Prefer the API method over direct database updates when possible

#### Troubleshooting

1. "Error: User not found in database"
   - Verify the username exists in your Keycloak instance
   - Check if you're using the correct database credentials
   - Ensure the database is accessible from your machine

2. Connection Issues
   - When using host.docker.internal, ensure Docker Desktop is running
   - Check if the database port is accessible
   - Verify network connectivity between your machine and the database

3. After Database Update
   - Remember to restart your Keycloak instance
   - Check Keycloak logs for any startup errors
   - Verify the new password works after restart

#### Acknowledgments

The database password reset implementation was inspired by [@yitzhtal](https://github.com/yitzhtal)'s approach to Keycloak password hashing.