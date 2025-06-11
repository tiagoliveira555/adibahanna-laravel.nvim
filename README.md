# Laravel.nvim

A comprehensive Neovim plugin for Laravel development that provides intelligent navigation, Artisan command execution, database schema visualization, architecture diagrams, and seamless integration with your Laravel workflow.

## ✨ Features

### 🚀 Laravel-Specific Navigation
- Smart navigation between Controllers, Models, Views, and Route files
- Context-aware file jumping based on current cursor position
- Route file navigation with support for auth.php, console.php, web.php, and custom route files
- Model relationship analysis and navigation
- Quick access to related Laravel components

### 🎨 Blade Template Support
- Full Blade syntax highlighting and indentation
- Laravel-specific file type detection for `.blade.php` files
- Context-aware navigation from Blade templates to controllers

### ⚡ Artisan Integration
- Execute any Artisan command directly from Neovim with `:Artisan`
- Interactive make commands with fuzzy finder for creating controllers, models, migrations, etc.
- Cached command completions for better performance
- Terminal integration for long-running commands
- Laravel status overview with project information

### 🗃️ Route Management
- Beautiful routes display matching `php artisan route:list` terminal output
- Formatted table with method icons, dotted padding, and proper alignment
- Syntax highlighting for different HTTP methods and route patterns
- Navigate through all application routes in a clean interface
- Support for web, API, and custom route files

### 🏗️ Model Analysis
- Parse and display model relationships (hasMany, belongsTo, hasOne, etc.)
- Show fillable attributes, hidden fields, and casts
- Navigate between related models
- Intelligent model discovery across Laravel 8+ structure
- Deduplication of models in picker interfaces

### 🗄️ Migration Tools
- Migration file navigation and analysis
- Parse table operations and column definitions
- Database schema visualization with ER diagrams
- Migration status and execution commands

### 📊 Database Schema Diagrams
- **Comprehensive Schema Analysis**: Automatically parses all migration files
- **Mermaid ER Diagrams**: Generate beautiful database schema diagrams
- **Table Relationships**: Shows foreign key constraints and relationships
- **Column Details**: Displays data types, constraints, and nullable fields
- **Export Options**: View diagrams in terminal or export to `.mmd` files
- **Smart Parsing**: Handles complex Laravel migration syntax patterns

### 🏛️ Architecture Diagrams
- **Application Flow Diagrams**: Visualize Laravel request lifecycle
  - **Simplified Flow**: Clean overview with grouped components and smart model display
  - **Detailed Flow**: Comprehensive lifecycle showing all Laravel components
- **Model Relationships**: ER diagrams showing database relationships
- **Route Mapping**: Visual representation of route-to-controller connections
- **Color-Coded Components**: Different colors for security, business logic, and data layers
- **Interactive Selection**: Choose between different diagram types

### 🎨 Clean Integration
- Uses standard Neovim UI components (`vim.ui.select`, `vim.notify`) for maximum compatibility
- No LSP configuration conflicts - works with your existing PHP LSP setup
- Lightweight and focused on Laravel-specific functionality
- Graceful fallback behaviors for robust operation
- Error handling with `pcall()` protection for stability

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'adibhanna/laravel.nvim',
  ft = { 'php', 'blade' },
  config = function()
    require('laravel').setup()
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'adibhanna/laravel.nvim',
  ft = { 'php', 'blade' },
  config = function()
    require('laravel').setup()
  end,
}
```

### Manual Installation

1. Clone the repository to your Neovim plugin directory
2. Add the plugin to your configuration
3. Call `require('laravel').setup()` in your init.lua

## ⚙️ Prerequisites

### Required
- **Neovim 0.10+** (for modern Lua APIs and UI components)
- **PHP 8.0+** (for Laravel compatibility)
- **Composer** (for Laravel projects)

### Optional
- **Tree-sitter** (for enhanced Blade syntax highlighting)
- **ripgrep** (for faster file searching)

## 🚀 Usage

Laravel.nvim automatically activates when you open a Laravel project (detected by the presence of `artisan` file in the project root).

### Commands

| Command                     | Description                                      |
| --------------------------- | ------------------------------------------------ |
| `:Artisan [command]`        | Run Artisan commands with intelligent completion |
| `:LaravelController [name]` | Navigate to controller with fuzzy finder         |
| `:LaravelModel [name]`      | Navigate to model with relationship analysis     |
| `:LaravelView [name]`       | Navigate to view with Blade template support     |
| `:LaravelRoute`             | Show all routes in formatted table               |
| `:LaravelMake [type]`       | Interactive make command with templates          |
| `:LaravelStatus`            | Show Laravel project status and information      |
| `:LaravelSchema`            | Display database schema diagram                  |
| `:LaravelSchemaExport`      | Export schema diagram to .mmd file               |
| `:LaravelArchitecture`      | Show application architecture diagrams           |

### Key Mappings

All Laravel keymaps use the `<leader>L` prefix for better organization and to avoid conflicts with other plugins.

#### 🌐 Global Laravel Commands
- `<leader>Lc` - **Go to controller** - Navigate to controllers with fuzzy finder
- `<leader>Lm` - **Go to model** - Navigate to models with relationship info
- `<leader>Lv` - **Go to view** - Navigate to Blade templates and views
- `<leader>Lr` - **Go to route file** - Navigate between route files (web.php, auth.php, etc.)
- `<leader>LR` - **Show routes** - Display all routes in terminal-style table
- `<leader>La` - **Run artisan command** - Execute Artisan commands interactively
- `<leader>Lk` - **Laravel make command** - Create new Laravel components
- `<leader>Ls` - **Show Laravel status** - Display project information

#### 📊 Visualization Commands
- `<leader>LS` - **Show schema diagram** - Display database ER diagram in terminal
- `<leader>LE` - **Export schema diagram** - Export database schema to .mmd file
- `<leader>LA` - **Show architecture diagram** - Display application architecture options

#### 🏗️ Context-Specific Commands

**In Model Files:**
- All global commands available
- Enhanced model relationship analysis
- Smart navigation to related models and migrations

**In Migration Files:**
- Migration-specific analysis
- Table structure visualization
- Schema relationship mapping

**In Route Files:**
- Enhanced route definition navigation
- Controller action jumping
- Route-to-method mapping

**In Blade Templates:**
- Controller navigation from views
- Related view discovery
- Laravel directive support

## ⚡ Smart Navigation Features

Laravel.nvim provides intelligent navigation based on your current context:

### 📁 File-Based Navigation
1. **From Controllers**: Navigate to related models, views, and route definitions
2. **From Models**: Jump to controllers, migrations, and related models via relationships
3. **From Views**: Find corresponding controllers and related Blade templates
4. **From Route Files**: Navigate directly to controller actions and methods
5. **From Migrations**: Access related models and table structures

### 🎯 Cursor-Based Navigation
- Detects class names, method calls, and view names under cursor
- Automatically suggests relevant Laravel components
- Context-aware suggestions based on file type and location

### 🔍 Fuzzy Finding
- All navigation commands use fuzzy finding for quick access
- Intelligent filtering based on Laravel conventions
- Recent files prioritization for faster workflow

## 📊 Database Schema Visualization

Laravel.nvim provides powerful database schema analysis and visualization:

### 🔍 Migration Analysis
```php
// Automatically parsed from migration files
Schema::create('users', function (Blueprint $table) {
    $table->id();
    $table->string('name');
    $table->string('email')->unique();
    $table->foreignId('role_id')->constrained();
    $table->timestamps();
});
```

### 📈 Mermaid ER Diagrams
Generated diagrams show:
- **Tables and Columns**: All database tables with their column definitions
- **Relationships**: Foreign key constraints and table relationships
- **Data Types**: Column types, lengths, and constraints
- **Indexes**: Primary keys, unique constraints, and foreign keys

### 💾 Export Options
- **Terminal Display**: View diagrams directly in Neovim with syntax highlighting
- **File Export**: Save diagrams as `.mmd` files in your project root
- **External Tools**: Compatible with Mermaid CLI and web viewers

## 🏛️ Architecture Visualization

Comprehensive application architecture diagrams help understand your Laravel application:

### 🌊 Application Flow Diagrams

**Simplified Flow** - Clean overview perfect for documentation:
```
Client → Router → Middleware → Controller → Service → Model → Database
```

**Detailed Flow** - Complete Laravel request lifecycle:
```
Client → Web Server → public/index.php → Bootstrap → Service Providers
→ HTTP Kernel → Global Middleware → Route Middleware → Form Requests
→ Controllers → Services → Events → Jobs → Models → Query Builder
→ Database → Cache → Views → API → Response
```

### 🗄️ Model Relationships
Visual ER diagrams showing:
- Model connections and relationships
- Database foreign key constraints
- Relationship cardinality (one-to-one, one-to-many, many-to-many)

### 🛣️ Route Mapping
Visual representation of:
- Route definitions to controller methods
- Middleware assignments
- Route groups and prefixes
- API vs web route separation

## 🎯 Laravel Project Structure

The plugin intelligently understands Laravel project structure across versions:

```
laravel-project/
├── app/
│   ├── Http/
│   │   ├── Controllers/     # Controllers (all versions)
│   │   ├── Middleware/      # Custom middleware
│   │   └── Requests/        # Form requests
│   ├── Models/             # Models (Laravel 8+)
│   ├── Services/           # Service classes
│   └── *.php               # Models (Laravel < 8)
├── resources/
│   ├── views/              # Blade templates
│   ├── js/                 # Frontend assets
│   └── css/                # Stylesheets
├── routes/
│   ├── web.php             # Web routes
│   ├── api.php             # API routes
│   ├── auth.php            # Authentication routes
│   └── console.php         # Console routes
├── database/
│   ├── migrations/         # Database migrations
│   ├── seeders/            # Database seeders
│   └── factories/          # Model factories
└── artisan                 # Artisan CLI
```

## 🔧 Configuration

Laravel.nvim works out of the box with sensible defaults. For advanced configuration:

```lua
require('laravel').setup({
  -- Feature toggles
  features = {
    navigation = true,      -- Controller/Model/View navigation
    artisan = true,         -- Artisan command integration
    routes = true,          -- Route management and display
    models = true,          -- Model analysis and relationships
    migrations = true,      -- Migration tools and analysis
    blade = true,           -- Blade template support
    schema = true,          -- Database schema diagrams
    architecture = true,    -- Architecture visualization
    keymaps = true,         -- Automatic keymap setup
  },
  
  -- UI preferences
  ui = {
    use_terminal_diagrams = true,  -- Show diagrams in terminal vs files
    route_table_max_width = 120,   -- Maximum width for route tables
    show_icons = true,             -- Show method icons in route tables
  },
  
  -- Path customization
  paths = {
    controllers = "app/Http/Controllers",
    models = { "app/Models", "app" },  -- Laravel 8+ and legacy
    views = "resources/views",
    routes = "routes",
    migrations = "database/migrations",
  },
  
  -- Diagram options
  diagrams = {
    schema = {
      export_path = "database/schema.mmd",
      show_relationships = true,
      include_timestamps = true,
    },
    architecture = {
      default_type = "simplified",  -- 'simplified' or 'detailed'
      show_model_counts = true,
      group_models_threshold = 5,   -- Group models when > N models
    },
  },
})
```

## 🔌 Integration & Compatibility

### 🎨 UI Framework Integration
- **Standard Neovim UI**: Uses `vim.ui.select` and `vim.notify` for maximum compatibility
- **Terminal Integration**: Seamless terminal command execution
- **Floating Windows**: Clean, non-intrusive popup interfaces
- **Syntax Highlighting**: Proper highlighting for all displayed content

### 🔍 LSP Compatibility
Laravel.nvim focuses on Laravel-specific functionality and **does not configure LSP servers**, allowing you to use your preferred PHP LSP setup:

- ✅ **Compatible with any PHP LSP**: Intelephense, Phpactor, PHP Language Server
- ✅ **Works with nvim-lspconfig**: No configuration conflicts
- ✅ **Mason.nvim friendly**: Install and manage LSP servers separately
- ✅ **Manual LSP setup**: Works with any LSP configuration approach

### 🌳 Tree-sitter Integration
- **Blade Syntax**: Enhanced highlighting for `.blade.php` files
- **PHP Parsing**: Leverages tree-sitter for accurate code analysis
- **Graceful Fallback**: Works without tree-sitter if not available

### 🔧 Plugin Ecosystem
- **File Managers**: Works with nvim-tree, oil.nvim, and other file explorers
- **Fuzzy Finders**: Compatible with telescope.nvim, fzf, and native vim.ui.select
- **Terminal**: Integrates with toggleterm, vim-floaterm, and built-in terminal
- **Status Lines**: Status information available for lualine.nvim and other status plugins

## 🐛 Troubleshooting

### Common Issues

#### Laravel Project Not Detected
```bash
# Check if artisan file exists in project root
ls -la artisan

# Verify you're in the correct directory
pwd
```

#### Blade Files Not Highlighting
1. Ensure file extension is `.blade.php`
2. Check file type detection: `:set filetype?`
3. Reload file: `:e!` or restart Neovim

#### Artisan Commands Not Working
1. Verify PHP is in PATH: `php --version`
2. Check artisan permissions: `ls -la artisan`
3. Test artisan manually: `php artisan list`

#### Routes Not Displaying
1. Ensure route files exist in `routes/` directory
2. Check for syntax errors in route files
3. Verify Laravel project structure

#### Schema Diagrams Not Generating
1. Check migration files exist in `database/migrations/`
2. Verify migration syntax is valid
3. Look for parser errors in `:messages`

### Debug Information

Enable debug mode for troubleshooting:

```lua
vim.g.laravel_debug = true
```

This will show additional information about:
- Project detection
- File parsing
- Command execution
- Error messages

## 🤝 Contributing

Contributions are welcome! Here's how to get started:

### Development Setup
```bash
git clone https://github.com/adibhanna/laravel.nvim.git
cd laravel.nvim

# Test in a Laravel project
cd /path/to/your/laravel/project
nvim -u <path-to-plugin>/test/init.lua
```

### Contributing Guidelines
1. **Fork the repository** and create a feature branch
2. **Follow Lua conventions** and existing code style
3. **Add tests** for new functionality when applicable
4. **Update documentation** for new features
5. **Test thoroughly** with different Laravel versions
6. **Submit a pull request** with clear description

### Reporting Issues
When reporting issues, please include:
- Neovim version (`:version`)
- Laravel version
- Plugin configuration
- Steps to reproduce
- Error messages from `:messages`

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.
