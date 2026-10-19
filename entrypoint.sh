#!/bin/bash
set -e

# ============================================
# RUNTIME UID/GID MAPPING (START)
# Runs as root, then drops to codex user
# ============================================
TARGET_UID="${USER_ID:-1000}"
TARGET_GID="${GROUP_ID:-1000}"
CURRENT_UID=$(id -u codex)
CURRENT_GID=$(id -g codex)

if [ "$(id -u)" = "0" ]; then
    # Remap codex user/group to match host UID/GID
    if [ "$CURRENT_GID" != "$TARGET_GID" ]; then
        groupmod -g "$TARGET_GID" codex 2>/dev/null || true
    fi
    if [ "$CURRENT_UID" != "$TARGET_UID" ]; then
        usermod -u "$TARGET_UID" codex 2>/dev/null || true
    fi

    # Fix ownership of non-mounted dirs that still have old UID
    chown codex:codex /home/codex 2>/dev/null || true

    # Add supplementary groups (e.g. shared lab group for file access)
    # EXTRA_GROUPS is a colon-separated list of GIDs, e.g. "1001:1002"
    if [ -n "${EXTRA_GROUPS:-}" ]; then
        IFS=':' read -ra GIDS <<< "$EXTRA_GROUPS"
        for gid in "${GIDS[@]}"; do
            groupadd -g "$gid" "group_$gid" 2>/dev/null || true
            usermod -aG "group_$gid" codex
        done
    fi

    # Re-run this script as codex
    exec gosu codex "$0" "$@"
fi
# ============================================
# RUNTIME UID/GID MAPPING (END)
# ============================================

# ============================================
# DOTFILE BOOTSTRAP (START)
# Create essential dotfiles if missing in
# the mounted home (first run for new users)
# ============================================
if [ ! -f "$HOME/.Renviron" ]; then
    echo 'R_LIBS_USER="~/R/library"' > "$HOME/.Renviron"
    echo "Created ~/.Renviron"
fi

if [ ! -f "$HOME/.bashrc" ]; then
    cp /etc/skel/.bashrc "$HOME/.bashrc" 2>/dev/null || true
    echo "Created ~/.bashrc"
fi

if [ ! -f "$HOME/.profile" ]; then
    cp /etc/skel/.profile "$HOME/.profile" 2>/dev/null || true
    echo "Created ~/.profile"
fi

# Codex stores sign-in credentials, configuration, sessions, and plugins here.
mkdir -p "$HOME/.codex"
# ============================================
# DOTFILE BOOTSTRAP (END)
# ============================================

# ============================================
# R PACKAGES INSTALLATION (START)
# First-run installation into persistent home
# Delete ~/R/.packages-installed to reinstall
# ============================================
if [ -f /opt/install-r-packages.R ]; then
    mkdir -p "$HOME/R/library"

    if [ ! -f "$HOME/R/.packages-installed" ]; then
        echo "First run: installing R packages to persistent home..."
        echo "This may take a while. Subsequent runs will skip this step."
        Rscript /opt/install-r-packages.R
        touch "$HOME/R/.packages-installed"
        echo "R packages installed successfully."
    fi
fi
# ============================================
# R PACKAGES INSTALLATION (END)
# ============================================

exec "$@"
