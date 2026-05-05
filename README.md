# Hollow Knight GRUB Theme

A dark, atmospheric GRUB2 bootloader theme inspired by the game Hollow Knight. Features clean typography, cyan highlights, and comprehensive OS icon support.

![Theme Preview](background.png)

## Quick install (one line)

```bash
curl -fsSL https://raw.githubusercontent.com/opx0/grub-theme/main/install.sh | sudo bash
```

That's it — no clone, no manual file copying. The installer auto-fetches the theme from GitHub, backs up your current GRUB config, installs the theme to `/boot/grub/themes/hollow-knight/`, and regenerates the menu.

### Headless / non-interactive

```bash
curl -fsSL https://raw.githubusercontent.com/opx0/grub-theme/main/install.sh | sudo bash -s -- --yes --no-reboot
```

### Pin to a specific branch, tag, or commit

```bash
curl -fsSL https://raw.githubusercontent.com/opx0/grub-theme/main/install.sh | sudo bash -s -- --branch v1.0.0
```

### Uninstall (one line)

```bash
curl -fsSL https://raw.githubusercontent.com/opx0/grub-theme/main/uninstall.sh | sudo bash
```

## Features

- **Dark aesthetic** with Hollow Knight-themed background artwork
- **Modern design** with cyan (#02CCFC) selection highlights
- **80+ OS icons** supporting major Linux distributions, BSD, Windows, and macOS
- **Clean typography** using Terminus and DejaVu Sans fonts
- **Helpful keyboard shortcuts** displayed on screen
- **Progress bar** with timeout notifications
- **Responsive layout** optimized for various screen resolutions

## Supported Operating Systems

The theme includes icons for:
- **Linux**: Arch, Ubuntu, Fedora, Debian, Manjaro, Pop!_OS, Linux Mint, Gentoo, openSUSE, and many more
- **BSD**: FreeBSD, Haiku
- **Other**: Windows, macOS, Android
- **Special**: Recovery mode, EFI, shutdown, restart

## Installation options

### Local clone

```bash
git clone https://github.com/opx0/grub-theme
cd grub-theme
sudo ./install.sh
```

The installer:
- Detects local files when run from a clone, or auto-fetches a tarball when piped from `curl`
- Backs up any existing theme to `~/.grub-theme-backups/`
- Backs up `/etc/default/grub` before editing it
- Installs theme files to `/boot/grub/themes/hollow-knight/`
- Sets sensible `GRUB_GFXMODE` / `GRUB_GFXPAYLOAD_LINUX` defaults if missing
- Regenerates the GRUB menu (`update-grub` / `grub-mkconfig` / `grub2-mkconfig`)

### Installer flags

| Flag | Effect |
| ---- | ------ |
| `-y`, `--yes` | Assume yes to prompts (non-interactive) |
| `-f`, `--force` | Overwrite existing theme without confirmation (implies `-y`) |
| `-n`, `--no-reboot` | Skip the post-install reboot prompt |
| `-b REF`, `--branch REF` | Use a specific branch, tag, or commit |
| `-d`, `--debug` | Verbose debug output |
| `-h`, `--help` | Show usage |

When piped via `curl ... | sudo bash`, the installer detects the missing TTY and runs non-interactively with safe defaults.

### Manual installation

1. **Copy theme files:**
   ```bash
   sudo mkdir -p /boot/grub/themes/hollow-knight
   sudo cp -r * /boot/grub/themes/hollow-knight/
   ```

2. **Edit GRUB configuration:**
   ```bash
   sudo nano /etc/default/grub
   ```
   
   Add or modify these lines:
   ```
   GRUB_THEME="/boot/grub/themes/hollow-knight/theme.txt"
   GRUB_GFXMODE=1920x1080
   ```

3. **Update GRUB:**
   
   For Debian/Ubuntu/Mint:
   ```bash
   sudo update-grub
   ```
   
   For Arch/Manjaro:
   ```bash
   sudo grub-mkconfig -o /boot/grub/grub.cfg
   ```
   
   For Fedora/RHEL:
   ```bash
   sudo grub2-mkconfig -o /boot/grub2/grub.cfg
   ```

4. **Reboot to see changes:**
   ```bash
   reboot
   ```

## Customization

### Change Title Text

Edit `theme.txt` and uncomment/modify line 20:
```
#text = "BTW its Arch"
```

### Adjust Colors

Key color definitions in `theme.txt`:
- `selected_item_color = "#02CCFC"` - Highlight color (cyan)
- `item_color = "#cccccc"` - Default menu item color
- `desktop-color = "#000000"` - Background color

### Change Background

Replace `background.png` with your own image (recommended: 1920x1080 or higher).

### Font Sizes

Available fonts:
- Terminus: 12, 14, 16, 18 (regular and bold)
- DejaVu Sans: 12, 14, 16, 24, 48

Modify font references in `theme.txt` to adjust text sizes.


## Troubleshooting

### Theme doesn't appear after installation
- Verify GRUB_THEME path in `/etc/default/grub`
- Ensure theme files have correct permissions: `sudo chmod -R 755 /boot/grub/themes/hollow-knight`
- Check GRUB config was regenerated: `sudo update-grub` or `sudo grub-mkconfig`

### Low resolution / Blurry theme
- Set appropriate resolution in `/etc/default/grub`:
  ```
  GRUB_GFXMODE=1920x1080
  GRUB_GFXPAYLOAD_LINUX=keep
  ```
- Regenerate GRUB config after changes

### Icons not showing
- Ensure icon files are in `/boot/grub/themes/hollow-knight/icons/`
- GRUB matches icons by OS name patterns in menu entries
- Check icon file names match GRUB's expected naming conventions

### Custom OS not showing correct icon
- Add a custom icon as `icons/your-os-name.png` (32x32 PNG)
- GRUB matches based on menu entry text

## Uninstallation

### One-line uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/opx0/grub-theme/main/uninstall.sh | sudo bash
```

### Local uninstall script

```bash
sudo ./uninstall.sh
```

Useful flags: `--purge` (also delete theme files), `--keep-files` (keep them), `--yes` (non-interactive), `--no-reboot`.

### Manual uninstallation
1. Edit `/etc/default/grub` and remove/comment the `GRUB_THEME` line
2. Regenerate GRUB: `sudo update-grub` or `sudo grub-mkconfig`
3. Optionally remove theme files: `sudo rm -rf /boot/grub/themes/hollow-knight`

## Credits

- **Artwork**: Hollow Knight characters and assets © Team Cherry
- **Theme Design**: Custom GRUB2 theme configuration
- **Fonts**: Terminus, DejaVu Sans (open source)
- **Icons**: Community-sourced distribution logos

## License

This theme is provided as-is for personal use. Hollow Knight artwork and characters are property of Team Cherry. Distribution logos are trademarks of their respective owners.

## Contributing

Improvements welcome! Areas for contribution:
- Icon quality improvements
- Additional OS icons
- Layout optimizations
- Resolution adaptability
- Bug fixes

## Screenshots

The theme features:
- Centered boot menu with 70% width
- Cyan selection highlight
- Bottom-aligned help text with keyboard shortcuts
- Timeout progress bar
- Dark, atmospheric background

---

**Note**: This is a bootloader theme. Always maintain backups and test in a safe environment before deploying on critical systems.
