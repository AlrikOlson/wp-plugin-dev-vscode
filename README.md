# WordPress Plugin Development Environment for VS Code

A complete WordPress plugin development environment setup using Docker, VS Code, and Xdebug. This project provides a standardized development environment for WordPress plugin development.

## Features

- 🐳 Docker-based WordPress development environment with MySQL and PHPMyAdmin
- 🔍 Configured Xdebug integration for PHP debugging
- 📦 Pre-configured VS Code workspace settings for WordPress development
- 🧰 Automatic installation of essential WordPress development VS Code extensions
- 🗄️ PHPMyAdmin for database management
- 🛠️ WP-CLI integration with helpful PowerShell commands
- 📁 Organized plugin directory structure

## Prerequisites

- [Visual Studio Code](https://code.visualstudio.com/)
- [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [Git](https://git-scm.com/)
- PowerShell 5.1 or higher

## Quick Start

1. Clone this repository:
```bash
git clone https://github.com/AlrikOlson/wp-plugin-dev-vscode.git your-plugin-name
cd your-plugin-name
```

2. Run the setup script:
```powershell
.\setup.ps1
```

3. Start the development environment:
```powershell
docker-compose up -d --build
```

4. Initialize WordPress:
```powershell
wp-reset
wp-install-theme
```

## Development Environment

### Access Points
- WordPress: http://localhost:8080
- PHPMyAdmin: http://localhost:8081

### Default Credentials

WordPress Admin:
- Username: admin
- Password: password

Database:
- Username: wordpress
- Password: wordpress

## PowerShell Helper Commands

The setup script adds several helpful PowerShell commands to your profile:

- `wp-cd [path]`: Change to plugin directory
- `wp-clean`: Rebuild containers from scratch
- `wp-reset`: Reset WordPress database and reinstall
- `wp-plugin-list`: List installed plugins
- `wp-install-theme`: Install and activate Twenty Twenty-Four theme
- `wp-help`: Show all available commands

## Directory Structure

```
your-plugin-name/
├── assets/
│   ├── css/          # Stylesheet files
│   ├── js/           # JavaScript files
│   └── images/       # Image assets
├── docker/
│   └── wordpress/    # Docker configuration
├── languages/        # Translation files
├── src/
│   ├── Admin/        # Admin-specific functionality
│   ├── Core/         # Core plugin functionality
│   └── Frontend/     # Frontend-specific functionality
├── templates/        # Template files
├── tests/
│   ├── Integration/  # Integration tests
│   └── Unit/        # Unit tests
├── .vscode/         # VS Code configuration
├── docker-compose.yml
└── your-plugin-name.php
```

## Installed VS Code Extensions

The following extensions are automatically installed during setup:

- PHP Intelephense (bmewburn.vscode-intelephense-client)
- WordPress Toolbox (wordpresstoolbox.wordpress-toolbox)
- PHP Debug (xdebug.php-debug)
- PHP DocBlocker (neilbrayfield.php-docblocker)
- PHP Namespace Resolver (MehediDracula.php-namespace-resolver)
- EditorConfig (editorconfig.editorconfig)
- ESLint (dbaeumer.vscode-eslint)
- Prettier (esbenp.prettier-vscode)
- Docker (ms-azuretools.vscode-docker)

## Debugging with Xdebug

1. Open your project in VS Code
2. Set breakpoints in your PHP code
3. Press F5 to start debugging
4. Access your WordPress site to trigger the breakpoints

The debug configuration is pre-configured in `.vscode/launch.json`.

## Docker Configuration

The development environment uses three main services:

1. **WordPress** (localhost:8080)
   - Latest WordPress version
   - Xdebug enabled
   - WP-CLI installed
   - Development plugins/tools

2. **MySQL** (internal)
   - Version 5.7
   - Persistent data storage

3. **PHPMyAdmin** (localhost:8081)
   - Database management interface
   - Connected to MySQL service

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.