# Setup script for WordPress plugin development environment with Docker
# Run this from your project root directory

# Function to write UTF-8 without BOM
function Write-FileUtf8NoBom {
    param(
        [string]$Path,
        [string]$Content
    )
    
    try {
        # Convert to absolute path relative to current directory
        $absolutePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        
        # Create directory if it doesn't exist
        $directory = Split-Path -Path $absolutePath -Parent
        if (![string]::IsNullOrEmpty($directory) -and !(Test-Path -Path $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        
        # Write file content
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
        [System.IO.File]::WriteAllLines($absolutePath, $Content, $Utf8NoBomEncoding)
        
        Write-Host "Successfully wrote file: $Path" -ForegroundColor Green
    }
    catch {
        Write-Host "Error writing file $Path : $_" -ForegroundColor Red
        throw
    }
}

# Function to test if a command exists
function Test-CommandExists {
    param (
        [string]$Command,
        [string]$InstallInstructions
    )
    
    if (!(Get-Command $Command -ErrorAction SilentlyContinue)) {
        Write-Host "❌ $Command is not installed." -ForegroundColor Red
        Write-Host $InstallInstructions -ForegroundColor Yellow
        exit 1
    }
    Write-Host "✅ $Command is installed" -ForegroundColor Green
}

# Function to install VS Code extension if not already installed
function Install-VSCodeExtension {
    param (
        [string]$ExtensionId
    )
    
    $installed = code --list-extensions | Where-Object { $_ -eq $ExtensionId }
    
    if (!$installed) {
        Write-Host "Installing VS Code extension: $ExtensionId" -ForegroundColor Yellow
        code --install-extension $ExtensionId
    } else {
        Write-Host "✅ VS Code extension already installed: $ExtensionId" -ForegroundColor Green
    }
}

# Check for required commands
Test-CommandExists "code" "Please install Visual Studio Code and ensure it's in your PATH"
Test-CommandExists "docker" "Please install Docker Desktop from https://www.docker.com/products/docker-desktop"
Test-CommandExists "docker-compose" "Docker Compose is required. It comes with Docker Desktop"
Test-CommandExists "git" "Please install Git from https://git-scm.com/"

# Install VS Code Extensions
Write-Host "`nInstalling VS Code Extensions..." -ForegroundColor Cyan
$extensions = @(
    "bmewburn.vscode-intelephense-client",
    "wordpresstoolbox.wordpress-toolbox",
    "xdebug.php-debug",
    "neilbrayfield.php-docblocker",
    "MehediDracula.php-namespace-resolver",
    "editorconfig.editorconfig",
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode",
    "ms-azuretools.vscode-docker"
)

foreach ($extension in $extensions) {
    Install-VSCodeExtension $extension
}

# Get the plugin name from the current directory
$pluginName = (Get-Item .).Name

# Create directory structure
Write-Host "`nCreating directory structure..." -ForegroundColor Cyan
$directories = @(
    "src/Admin",        # Admin-specific code
    "src/Frontend",     # Frontend-specific code
    "src/Core",         # Core plugin functionality
    "assets/js",        # JavaScript files
    "assets/css",       # CSS files
    "assets/images",    # Images
    "templates",        # Template files
    "languages",        # Translation files
    "tests/Unit",       # Unit tests
    "tests/Integration", # Integration tests
    "docker/wordpress"  # Docker configuration
)

foreach ($dir in $directories) {
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "Created directory: $dir" -ForegroundColor Green
    } else {
        Write-Host "Directory already exists: $dir" -ForegroundColor Green
    }
}

# Create Dockerfile
$dockerfile = @"
FROM wordpress:latest

# Install required dependencies
RUN apt-get update && \
    apt-get install -y \
    git \
    zip \
    unzip \
    libzip-dev \
    curl \
    default-mysql-client \
    && docker-php-ext-install zip

# Install WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

# Install Xdebug
RUN pecl install xdebug && \
    docker-php-ext-enable xdebug

# Configure Xdebug
RUN echo "xdebug.mode=debug" >> /usr/local/etc/php/conf.d/xdebug.ini && \
    echo "xdebug.start_with_request=yes" >> /usr/local/etc/php/conf.d/xdebug.ini && \
    echo "xdebug.client_host=host.docker.internal" >> /usr/local/etc/php/conf.d/xdebug.ini && \
    echo "xdebug.client_port=9003" >> /usr/local/etc/php/conf.d/xdebug.ini && \
    echo "xdebug.log=/var/log/xdebug.log" >> /usr/local/etc/php/conf.d/xdebug.ini && \
    echo "xdebug.idekey=VSCODE" >> /usr/local/etc/php/conf.d/xdebug.ini

# Create xdebug log file
RUN touch /var/log/xdebug.log && \
    chmod 666 /var/log/xdebug.log

# Remove default plugins and themes
RUN rm -rf /usr/src/wordpress/wp-content/plugins/* && \
    rm -rf /usr/src/wordpress/wp-content/themes/* && \
    mkdir -p /usr/src/wordpress/wp-content/plugins && \
    mkdir -p /usr/src/wordpress/wp-content/themes && \
    chown -R www-data:www-data /usr/src/wordpress/wp-content
"@

# Create docker-compose.yml
$dockerCompose = @"
name: ${pluginName}-dev

services:
  wordpress:
    build: 
      context: .
      dockerfile: docker/wordpress/Dockerfile
    ports:
      - "8080:80"
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: wordpress
      WORDPRESS_DB_NAME: wordpress
      WORDPRESS_DEBUG: 1
      PHP_IDE_CONFIG: "serverName=Docker"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      # Only bind our specific plugin directory
      - type: bind
        source: .
        target: /var/www/html/wp-content/plugins/$pluginName
      # Use named volumes for other WordPress directories
      - wordpress_core:/var/www/html
      - wordpress_plugins:/var/www/html/wp-content/plugins
      - wordpress_themes:/var/www/html/wp-content/themes
      - wordpress_uploads:/var/www/html/wp-content/uploads
    depends_on:
      - db

  db:
    image: mysql:5.7
    environment:
      MYSQL_ROOT_PASSWORD: somewordpress
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: wordpress
    volumes:
      - db_data:/var/lib/mysql

  phpmyadmin:
    image: phpmyadmin/phpmyadmin
    ports:
      - "8081:80"
    environment:
      PMA_HOST: db
    depends_on:
      - db

volumes:
  wordpress_core:
  wordpress_plugins:
  wordpress_themes:
  wordpress_uploads:
  db_data:
"@

# Create main plugin file
$mainPluginFile = @"
<?php
/**
 * Plugin Name: $($pluginName)
 * Plugin URI: 
 * Description: 
 * Version: 1.0.0
 * Requires at least: 6.0
 * Requires PHP: 7.4
 * Author: 
 * Author URI: 
 * License: GPL v2 or later
 * License URI: https://www.gnu.org/licenses/gpl-2.0.html
 * Text Domain: $($pluginName.ToLower())
 * Domain Path: /languages
 */

namespace $($pluginName.Replace('-', '_'));

if (!defined('ABSPATH')) {
    exit;
}

// Plugin constants
define(__NAMESPACE__ . '\PLUGIN_VERSION', '1.0.0');
define(__NAMESPACE__ . '\PLUGIN_DIR', plugin_dir_path(__FILE__));
define(__NAMESPACE__ . '\PLUGIN_URL', plugin_dir_url(__FILE__));

// Autoloader
spl_autoload_register(function (`$class) {
    `$prefix = __NAMESPACE__ . '\\';
    `$base_dir = plugin_dir_path(__FILE__) . 'src/';

    `$len = strlen(`$prefix);
    if (strncmp(`$prefix, `$class, `$len) !== 0) {
        return;
    }

    `$relative_class = substr(`$class, `$len);
    `$file = `$base_dir . str_replace('\\', '/', `$relative_class) . '.php';

    if (file_exists(`$file)) {
        require_once `$file;
    }
});

// Register activation hook
register_activation_hook(__FILE__, __NAMESPACE__ . '\activate_plugin');

function activate_plugin() {
    require_once PLUGIN_DIR . 'src/Core/Plugin.php';
    `$plugin = Core\Plugin::get_instance();
    `$plugin->activate();
}

// Initialize plugin
add_action('plugins_loaded', function() {
    require_once PLUGIN_DIR . 'src/Core/Plugin.php';
    Core\Plugin::get_instance();
}, 0);
"@

# Create Plugin class
$pluginClass = @"
<?php
namespace $($pluginName.Replace('-', '_'))\Core;

class Plugin {
    private static `$instance = null;
    private `$initialized = false;
    private `$admin_manager = null;
    private `$frontend_manager = null;

    public static function get_instance() {
        if (null === self::`$instance) {
            self::`$instance = new self();
        }
        return self::`$instance;
    }

    private function __construct() {
        `$this->init_hooks();
    }

    private function init_hooks() {
        // Core hooks
        add_action('init', [`$this, 'load_textdomain']);
        
        // Initialize components based on context
        if (is_admin()) {
            add_action('init', [`$this, 'init_admin'], 20);
        } else {
            add_action('init', [`$this, 'init_frontend'], 20);
        }

        // Register deactivation hook
        register_deactivation_hook(
            \$($pluginName.Replace('-', '_'))\PLUGIN_DIR . '$($pluginName).php',
            [`$this, 'deactivate']
        );
    }

    public function init_admin() {
        if (!`$this->admin_manager) {
            require_once \$($pluginName.Replace('-', '_'))\PLUGIN_DIR . 'src/Admin/AdminManager.php';
            `$this->admin_manager = new \$($pluginName.Replace('-', '_'))\Admin\AdminManager();
        }
    }

    public function init_frontend() {
        if (!`$this->frontend_manager) {
            require_once \$($pluginName.Replace('-', '_'))\PLUGIN_DIR . 'src/Frontend/FrontendManager.php';
            `$this->frontend_manager = new \$($pluginName.Replace('-', '_'))\Frontend\FrontendManager();
        }
    }

    public function activate() {
        flush_rewrite_rules();
        update_option('$($pluginName)_version', \$($pluginName.Replace('-', '_'))\PLUGIN_VERSION);
    }

    public function deactivate() {
        flush_rewrite_rules();
        delete_option('$($pluginName)_version');
    }

    public function load_textdomain() {
        load_plugin_textdomain(
            '$($pluginName.ToLower())',
            false,
            dirname(plugin_basename(\$($pluginName.Replace('-', '_'))\PLUGIN_DIR)) . '/languages'
        );
    }
}
"@

# Create AdminManager class
$adminManagerClass = @"
<?php
namespace $($pluginName.Replace('-', '_'))\Admin;

class AdminManager {
    public function __construct() {
        add_action('admin_menu', [`$this, 'add_admin_menu'], 20);
        add_action('admin_init', [`$this, 'init_settings']);
    }

    public function add_admin_menu() {
        add_menu_page(
            __('$($pluginName)', '$($pluginName.ToLower())'),
            __('$($pluginName)', '$($pluginName.ToLower())'),
            'manage_options',
            '$($pluginName.ToLower())',
            [`$this, 'render_admin_page'],
            'dashicons-admin-generic',
            30
        );
    }

    public function init_settings() {
        register_setting('$($pluginName.ToLower())_options', '$($pluginName.ToLower())_settings');
    }

    public function render_admin_page() {
        ?>
        <div class="wrap">
            <h1><?php echo esc_html(get_admin_page_title()); ?></h1>
            <p><?php _e('Welcome to $($pluginName) settings page.', '$($pluginName.ToLower())'); ?></p>
            <form method="post" action="options.php">
                <?php
                settings_fields('$($pluginName.ToLower())_options');
                do_settings_sections('$($pluginName.ToLower())');
                submit_button();
                ?>
            </form>
        </div>
        <?php
    }
}
"@

# Create FrontendManager class
$frontendManagerClass = @"
<?php
namespace $($pluginName.Replace('-', '_'))\Frontend;

class FrontendManager {
    public function __construct() {
        add_action('wp_enqueue_scripts', [`$this, 'enqueue_assets']);
        add_shortcode('$($pluginName.ToLower())', [`$this, 'render_shortcode']);
    }

    public function enqueue_assets() {
        wp_enqueue_style(
            '$($pluginName.ToLower())-style',
            \$($pluginName.Replace('-', '_'))\PLUGIN_URL . 'assets/css/frontend.css',
            [],
            \$($pluginName.Replace('-', '_'))\PLUGIN_VERSION
        );

        wp_enqueue_script(
            '$($pluginName.ToLower())-script',
            \$($pluginName.Replace('-', '_'))\PLUGIN_URL . 'assets/js/frontend.js',
            ['jquery'],
            \$($pluginName.Replace('-', '_'))\PLUGIN_VERSION,
            true
        );
    }

    public function render_shortcode(`$atts) {
        `$atts = shortcode_atts([
            'message' => __('Hello from $($pluginName)!', '$($pluginName.ToLower())')
        ], `$atts, '$($pluginName.ToLower())');

        return sprintf(
            '<div class="$($pluginName.ToLower())-shortcode">%s</div>',
            esc_html(`$atts['message'])
        );
    }
}
"@

# Create frontend CSS
$frontendCss = @"
.$($pluginName.ToLower())-shortcode {
    padding: 20px;
    margin: 10px 0;
    background-color: #f5f5f5;
    border: 1px solid #ddd;
    border-radius: 4px;
}
"@

# Create frontend JavaScript
$frontendJs = @"
(function(`$) {
    'use strict';

    `$(document).ready(function() {
        `$('.$($pluginName.ToLower())-shortcode').on('click', function() {
            `$(this).fadeOut().fadeIn();
        });
    });
})(jQuery);
"@

# Create test debug file
$testDebug = @"
<?php
// Test file for verifying Xdebug configuration

function test_xdebug() {
    // Set a breakpoint on the next line
    `$a = 1;
    `$b = 2;
    `$c = `$a + `$b;
    return `$c;
}

test_xdebug();
"@

# VS Code settings
$vsCodeSettings = @"
{
    "php.suggest.basic": false,
    "php.validate.enable": false,
    "files.associations": {
        "*.php": "php"
    },
    "editor.formatOnSave": true,
    "editor.defaultFormatter": "bmewburn.vscode-intelephense-client",
    "intelephense.environment.phpVersion": "8.0",
    "intelephense.diagnostics.undefinedFunctions": false,
    "intelephense.diagnostics.undefinedConstants": false,
    "intelephense.diagnostics.undefinedClassConstants": false,
    "intelephense.diagnostics.undefinedMethods": false,
    "intelephense.diagnostics.undefinedTypes": false,
    "intelephense.diagnostics.undefinedProperties": false,
    "intelephense.diagnostics.undefinedVariables": false,
    "intelephense.stubs": [
        "apache",
        "wordpress",
        "woocommerce",
        "php",
        "mysql"
    ]
}
"@

# VS Code launch configuration
$vsCodeLaunch = @"
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Listen for Xdebug",
            "type": "php",
            "request": "launch",
            "port": 9003,
            "pathMappings": {
                "/var/www/html/wp-content/plugins/$pluginName": "`${workspaceFolder}"
            },
            "log": true,
            "xdebugSettings": {
                "max_children": 128,
                "max_data": 512,
                "max_depth": 3
            }
        }
    ]
}
"@

# Update the configFiles array to include new files
$configFiles = @{
    "docker/wordpress/Dockerfile" = $dockerfile
    "docker-compose.yml" = $dockerCompose
    "$($pluginName).php" = $mainPluginFile
    "src/Core/Plugin.php" = $pluginClass
    "src/Admin/AdminManager.php" = $adminManagerClass
    "src/Frontend/FrontendManager.php" = $frontendManagerClass
    "assets/css/frontend.css" = $frontendCss
    "assets/js/frontend.js" = $frontendJs
    "test-debug.php" = $testDebug
    ".vscode/settings.json" = $vsCodeSettings
    ".vscode/launch.json" = $vsCodeLaunch
}

foreach ($file in $configFiles.Keys) {
    $directory = Split-Path $file
    if ($directory -and !(Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    
    if (!(Test-Path $file)) {
        Write-FileUtf8NoBom -Path $file -Content $configFiles[$file]
        Write-Host "Created file: $file" -ForegroundColor Green
    } else {
        Write-Host "File already exists: $file" -ForegroundColor Green
    }
}

# Initialize Git if not already initialized
if (!(Test-Path ".git")) {
    Write-Host "`nInitializing Git repository..." -ForegroundColor Cyan
    git init
    
    Write-FileUtf8NoBom -Path ".gitignore" -Content @"
# Development
node_modules/
vendor/
.env
.DS_Store
Thumbs.db

# IDE
.idea/
.vscode/*
!.vscode/settings.json
!.vscode/launch.json

# Testing
/tests/coverage/

# Build
/dist/
/build/

# Composer
/vendor/
composer.lock

# NPM/Yarn
/node_modules/
package-lock.json
yarn.lock

# Docker
/docker/mysql/data/

# setup script
setup.ps1
"@
    Write-Host "Created .gitignore file" -ForegroundColor Green
}

# Add helper commands to PowerShell profile
$helperCommands = @"
# Helper commands for WordPress development

function Test-WordPressDevEnvironment {
    # Check if we're in a WordPress plugin dev directory
    if (!(Test-Path "docker-compose.yml")) {
        Write-Host "Error: This command must be run from a WordPress plugin development directory containing docker-compose.yml" -ForegroundColor Red
        return `$false
    }
    
    # Verify it's our specific docker-compose setup by checking for key services
    `$dockerCompose = Get-Content "docker-compose.yml" -Raw
    if (!(`$dockerCompose -match "wordpress:" -and `$dockerCompose -match "phpmyadmin:" -and `$dockerCompose -match "db:")) {
        Write-Host "Error: This directory doesn't appear to be a WordPress plugin development environment" -ForegroundColor Red
        return `$false
    }
    
    return `$true
}

function wp-clean {
    if (Test-WordPressDevEnvironment) {
        docker-compose down -v
        docker-compose up -d --build
    }
}

function wp-reset {
    if (Test-WordPressDevEnvironment) {
        docker-compose exec wordpress wp db reset --yes --allow-root
        docker-compose exec wordpress wp core install --allow-root --url=localhost:8080 --title="WordPress Dev" --admin_user=admin --admin_password=password --admin_email=admin@example.com
    }
}

function wp-plugin-list {
    if (Test-WordPressDevEnvironment) {
        docker-compose exec wordpress wp plugin list --allow-root
    }
}

function wp-install-theme {
    if (Test-WordPressDevEnvironment) {
        docker-compose exec wordpress wp theme install twentytwentyfour --activate --allow-root
    }
}

function wp-cd {
    param(
        [Parameter(Mandatory=`$false)]
        [string]`$pluginDir = ""
    )
    
    # Search common locations for docker-compose.yml
    `$searchPaths = @()
    
    if (`$pluginDir) {
        `$searchPaths += `$pluginDir
    }
    
    `$searchPaths += Join-Path `$env:USERPROFILE "Code"
    `$searchPaths += "D:/Code"
    `$searchPaths += "C:/Code"
    
    foreach (`$path in `$searchPaths) {
        if (Test-Path `$path) {
            `$found = Get-ChildItem -Path `$path -Recurse -Filter "docker-compose.yml" -ErrorAction SilentlyContinue | 
                     Where-Object {
                         `$content = Get-Content `$_.FullName -Raw
                         `$content -match "wordpress:" -and `$content -match "phpmyadmin:" -and `$content -match "db:"
                     } |
                     Select-Object -First 1
            if (`$found) {
                Set-Location `$found.Directory
                Write-Host "Changed to WordPress plugin directory: `$(`$found.Directory)" -ForegroundColor Green
                return
            }
        }
    }
    
    Write-Host "Error: Could not find WordPress plugin development directory" -ForegroundColor Red
}

function wp-help {
    Write-Host "WordPress Development Commands:" -ForegroundColor Cyan
    Write-Host "These commands must be run from within a WordPress plugin development directory:" -ForegroundColor Yellow
    Write-Host "wp-cd [path]  : Change to plugin directory (optional: specify path)" -ForegroundColor Yellow
    Write-Host "wp-clean     : Rebuild containers from scratch" -ForegroundColor Yellow
    Write-Host "wp-reset     : Reset WordPress database and reinstall" -ForegroundColor Yellow
    Write-Host "wp-plugin-list: List installed plugins" -ForegroundColor Yellow
    Write-Host "wp-install-theme: Install and activate Twenty Twenty-Four theme" -ForegroundColor Yellow
}

# Show help when module is loaded
Write-Host "WordPress development commands loaded. Type 'wp-help' for available commands." -ForegroundColor Cyan
"@

# Create PowerShell profile directory and file if they don't exist
$profileDir = Split-Path $PROFILE
if (!(Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    Write-Host "Created PowerShell profile directory" -ForegroundColor Green
}

if (!(Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    Write-Host "Created PowerShell profile file" -ForegroundColor Green
}

# Add helper commands to a separate file
$helpersPath = Join-Path $profileDir "WordPress-Dev-Helpers.ps1"
Write-FileUtf8NoBom -Path $helpersPath -Content $helperCommands
Write-Host "Created WordPress helper commands file" -ForegroundColor Green

# Add the source line to the profile if it's not already there
$sourceCommand = ". `$PSScriptRoot\WordPress-Dev-Helpers.ps1"
$profileContent = Get-Content $PROFILE -ErrorAction SilentlyContinue
if ($profileContent -notcontains $sourceCommand) {
    Write-FileUtf8NoBom -Path $PROFILE -Content $sourceCommand
    Write-Host "Added helper commands to PowerShell profile" -ForegroundColor Green
}

Write-Host "`n✅ Setup complete!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Run 'docker-compose up -d --build' to start the containers" -ForegroundColor Yellow
Write-Host "2. Open a new PowerShell window" -ForegroundColor Yellow
Write-Host "3. Run 'wp-reset' to initialize WordPress" -ForegroundColor Yellow
Write-Host "4. Run 'wp-install-theme' to install the default theme" -ForegroundColor Yellow
Write-Host "`nAccess your development environment:" -ForegroundColor Yellow
Write-Host "- WordPress: http://localhost:8080" -ForegroundColor Yellow
Write-Host "- PHPMyAdmin: http://localhost:8081" -ForegroundColor Yellow
Write-Host "`nDefault credentials:" -ForegroundColor Yellow
Write-Host "WordPress Admin:" -ForegroundColor Yellow
Write-Host "- Username: admin" -ForegroundColor Yellow
Write-Host "- Password: password" -ForegroundColor Yellow
Write-Host "`nDatabase:" -ForegroundColor Yellow
Write-Host "- Username: wordpress" -ForegroundColor Yellow
Write-Host "- Password: wordpress" -ForegroundColor Yellow
Write-Host "`nTo test Xdebug:" -ForegroundColor Yellow
Write-Host "1. Open VS Code" -ForegroundColor Yellow
Write-Host "2. Set a breakpoint in test-debug.php" -ForegroundColor Yellow
Write-Host "3. Press F5 to start debugging" -ForegroundColor Yellow
Write-Host "4. Visit http://localhost:8080" -ForegroundColor Yellow
