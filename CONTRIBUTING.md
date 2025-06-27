# Contributing to Laravel.nvim

Thank you for your interest in contributing to Laravel.nvim! This document provides guidelines and information for contributors.

## 🚀 Getting Started

### Prerequisites
- Neovim 0.8.0+
- A Laravel project for testing
- Basic knowledge of Lua and Laravel

### Development Setup

1. **Fork and Clone**
   ```bash
   git clone https://github.com/adibhanna/laravel.nvim.git
   cd laravel.nvim
   ```

2. **Set up Test Environment**
   - Create or use an existing Laravel project
   - Symlink the plugin to your Neovim config for testing
   ```bash
   ln -s /path/to/laravel.nvim ~/.local/share/nvim/site/pack/dev/start/laravel.nvim
   ```

3. **Test the Plugin**
   - Open Neovim in your Laravel project
   - Test navigation and completion features
   - Verify all commands work correctly

## 🎯 How to Contribute

### Reporting Issues
- Use the GitHub issue tracker
- Provide clear reproduction steps
- Include Neovim version, Laravel version, and OS
- Share relevant error messages or logs

### Suggesting Features
- Check existing issues first
- Explain the use case and benefits
- Consider Laravel Idea features for inspiration
- Provide examples of how it should work

### Code Contributions

#### Areas for Contribution
- **Navigation Features**: New Laravel patterns to navigate
- **Completion Sources**: Additional Laravel helper completions
- **File Creation**: New file types and templates
- **Performance**: Optimization and caching improvements
- **Documentation**: Examples, guides, and API docs
- **Testing**: Unit tests and integration tests
- **Bug Fixes**: Any reported issues

#### Code Style
- Follow Lua best practices
- Use consistent indentation (4 spaces)
- Comment complex logic
- Keep functions focused and small
- Use descriptive variable names

#### Pull Request Process
1. **Branch**: Create a feature branch from `main`
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Code**: Implement your changes
   - Write clean, readable code
   - Add comments for complex logic
   - Follow existing patterns

3. **Test**: Verify your changes work
   - Test in multiple Laravel projects
   - Test edge cases and error conditions
   - Ensure no regressions in existing features

4. **Document**: Update documentation
   - Update README.md if needed
   - Add examples for new features
   - Update CHANGELOG.md

5. **Commit**: Use clear commit messages
   ```bash
   git commit -m "feat: add support for Livewire component navigation"
   git commit -m "fix: handle missing config files gracefully"
   git commit -m "docs: add examples for custom keybindings"
   ```

6. **Push and PR**: Submit your pull request
   ```bash
   git push origin feature/your-feature-name
   ```

## 🏗️ Project Structure

```
laravel.nvim/
├── lua/laravel/           # Core plugin modules
│   ├── artisan.lua       # Artisan command integration
│   ├── blade.lua         # Blade template support
│   ├── completions.lua   # Completion data gathering
│   ├── blink_source.lua  # Blink.nvim integration
│   ├── completion_source.lua # nvim-cmp integration
│   ├── keymaps.lua       # Keybinding setup
│   ├── models.lua        # Model navigation
│   ├── navigate.lua      # Navigation logic
│   ├── routes.lua        # Route handling
│   ├── migrations.lua    # Migration support
│   ├── schema.lua        # Database schema diagrams
│   ├── architecture.lua  # Architecture diagrams
│   ├── ui.lua           # UI components
│   └── utils/           # Utility functions
├── plugin/laravel.lua    # Plugin initialization
├── README.md            # Main documentation
├── CHANGELOG.md         # Version history
└── LICENSE             # MIT license
```

## 🧪 Testing Guidelines

### Manual Testing
- Test in different Laravel versions (8, 9, 10, 11+)
- Test with different frontend stacks (React, Vue, Svelte)
- Test edge cases (missing files, malformed syntax)
- Test performance with large projects

### Test Cases to Cover
- **Navigation**: All supported Laravel patterns
- **Completion**: All helper functions and edge cases
- **File Creation**: All supported file types
- **Error Handling**: Graceful failure modes
- **Performance**: No significant slowdowns

## 📝 Documentation

### Code Documentation
- Document public functions with clear descriptions
- Explain complex algorithms or patterns
- Add usage examples for new features

### User Documentation
- Update README.md for new features
- Add configuration examples
- Include troubleshooting information
- Provide usage examples

## 🎨 Design Principles

### User Experience
- **Intuitive**: Should work like Laravel Idea when possible
- **Non-intrusive**: Don't break existing workflows
- **Fast**: Optimize for performance and responsiveness
- **Reliable**: Handle edge cases gracefully

### Code Quality
- **Modular**: Keep concerns separated
- **Extensible**: Make it easy to add new features
- **Maintainable**: Write code that's easy to understand
- **Robust**: Handle errors and edge cases

## 🤝 Community

### Getting Help
- Open an issue for bugs or questions
- Check existing issues and discussions
- Be respectful and constructive

### Communication
- Be clear and specific in issues and PRs
- Provide context and examples
- Be patient with review process

## 📋 Checklist for Contributors

Before submitting a PR, ensure:

- [ ] Code follows project style guidelines
- [ ] Changes are tested in real Laravel projects
- [ ] Documentation is updated if needed
- [ ] CHANGELOG.md is updated for significant changes
- [ ] No regressions in existing functionality
- [ ] Error handling is appropriate
- [ ] Performance impact is considered

## 🙏 Recognition

Contributors will be:
- Listed in the README.md contributors section
- Mentioned in release notes for significant contributions
- Credited in commit history

Thank you for helping make Laravel.nvim better for the entire Laravel community! 