# Keycloak Utility Scripts

This repository contains multiple utility scripts for playing around with Keycloak instances via Docker. Each script has a distinct purpose and usage instructions. Below is a high-level overview of what you can find in this repository.

## Available Scripts

1. **reset-admin-password.sh**  
   Resets the admin password of an existing Keycloak instance using Docker.  
   • Usage details can be found below.  
   • Defaults to Keycloak version 26.0.7, but you can override it.

## reset-admin-password.sh

This script allows you to reset the admin password of a running Keycloak instance using Docker. It relies on the official Keycloak Docker image to run the necessary commands, so you don't need to install or configure Keycloak locally.

### Prerequisites
- Docker installed and running
- Access to a running Keycloak instance
- Valid admin credentials for that Keycloak instance

### Usage
```bash
./reset-admin-password.sh <kc_server> <admin_username> <admin_password> <new_admin_password> [<keycloak_version>]
```
- <kc_server>: Must include the protocol, e.g. http://host.docker.internal:8080  
- <admin_username>: The admin username (e.g., "admin")  
- <admin_password>: Your current admin password  
- <new_admin_password>: The password you want to set  
- <keycloak_version> (optional): The Keycloak Docker image version to use. If not specified, the script uses 26.0.7.

#### Example
```bash
# Using the default Keycloak version (26.0.7):
./reset-admin-password.sh http://host.docker.internal:8080 admin oldpass newpass

# Specifying a custom version (e.g., 22.0.1):
./reset-admin-password.sh https://keycloak.example.com admin oldpass newpass 22.0.1
```

### Important Notes

1. Do NOT use localhost in <kc_server>, because inside a Docker container, localhost refers to the container's own network, not your host machine.  
   - Instead, you can use:
     - For Docker Desktop (Windows/Mac): http://host.docker.internal:8080  
     - For Linux: Use the IP address of your host machine (e.g., http://192.168.x.x:8080)
   
2. Ensure you include the protocol (http:// or https://) in <kc_server>. If you do not, the script will exit with an error.

3. Make sure that Keycloak is already running and that your machine (or container) can reach the provided <kc_server> address.

4. If you need to modify which Keycloak Docker image version is used by default, edit the Docker image reference (the variable that defaults to 26.0.7) within the script.

### Troubleshooting

1. If the script outputs "No server specified" after the first step, confirm that you included the protocol in the Keycloak server URL and that the Keycloak server is reachable.
2. If authentication fails, verify that your Keycloak credentials and realm configuration are correct (i.e., ensure you are using the "master" realm unless otherwise specified).

### Security Considerations

- Use HTTPS in production.
- Limit direct internet exposure of your Keycloak server and its admin passwords.
- Regularly rotate admin passwords and keep the Docker image up to date.
- Consider using environment variables or secure storage for sensitive credentials rather than passing them directly on the command line.

## Other Scripts

(Describe additional scripts here, along with their usage instructions.)