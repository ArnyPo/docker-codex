FROM ubuntu:24.04

# ============================================
# CORE SYSTEM PACKAGES
# ============================================
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    vim \
    nano \
    htop \
    tree \
    unzip \
    jq \
    ca-certificates \
    locales \
    sudo \
    cmake \
    bubblewrap \
    default-jdk \
    libmagick++-dev \
    gosu \
    && rm -rf /var/lib/apt/lists/* \
    && locale-gen en_US.UTF-8

# ============================================
# R DEPENDENCIES (START)
# Remove this section and the other R sections
# below to disable R support
# ============================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    dirmngr \
    libcurl4-openssl-dev \
    libuv1-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    libhdf5-dev \
    libglpk-dev \
    libcairo2-dev \
    libxt-dev \
    libgsl-dev \
    libfftw3-dev \
    # Spatial packages (terra, sf) dependencies
    libgdal-dev \
    libudunits2-dev \
    && rm -rf /var/lib/apt/lists/*

# Add CRAN repository and install R
RUN wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | \
    tee /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc > /dev/null && \
    add-apt-repository -y "deb https://cloud.r-project.org/bin/linux/ubuntu noble-cran40/" && \
    apt-get update && \
    apt-get install -y --no-install-recommends r-base r-base-dev && \
    rm -rf /var/lib/apt/lists/*
# ============================================
# R DEPENDENCIES (END)
# ============================================

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Create codex user with default UID/GID (remapped at runtime by entrypoint)
RUN groupadd -g 1100 codex && \
    useradd -m -s /bin/bash -u 1100 -g 1100 codex && \
    echo "codex ALL=(ALL) NOPASSWD: /usr/bin/apt-get, /usr/bin/apt" >> /etc/sudoers

# ============================================
# R USER LIBRARY (START)
# ============================================
# Copy R package installation script (runs at first container start)
COPY install-r-packages.R /opt/install-r-packages.R
# ============================================
# R USER LIBRARY (END)
# ============================================

# ============================================
# APT additions (START)
# ============================================

RUN apt-get update && apt-get install -y --no-install-recommends pandoc && \
    rm -rf /var/lib/apt/lists/*

# PDF text extraction
RUN apt-get update -qq && apt-get install -y -qq poppler-utils

# Python Excel support
RUN apt-get install -y -qq python3-pip && \
    pip3 install --break-system-packages openpyxl

# Node.js (LTS via NodeSource — available for project tooling and Codex plugins)
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

# GitHub CLI (official apt repo — Ubuntu's is stale/absent)
RUN mkdir -p -m 755 /etc/apt/keyrings && \
    wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
    tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && \
    apt-get install -y --no-install-recommends gh && \
    rm -rf /var/lib/apt/lists/*

# ============================================
# APT additions (END)
# ============================================

# ============================================
# BIOINFORMATICS TOOLS (START)
# Remove this section to disable bioinf tools
# ============================================

# Core tools from apt (Ubuntu 24.04 universe)
RUN apt-get update && apt-get install -y --no-install-recommends \
    samtools \
    bcftools \
    bedtools \
    tabix \
    fastqc \
    fastp \
    && rm -rf /var/lib/apt/lists/*

# mosdepth — static binary (not in apt)
RUN wget -q https://github.com/brentp/mosdepth/releases/download/v0.3.12/mosdepth \
    -O /usr/local/bin/mosdepth \
    && chmod +x /usr/local/bin/mosdepth

# pysam — Python BAM access
RUN pip3 install --break-system-packages pysam

# ============================================
# BIOINFORMATICS TOOLS (END)
# ============================================


# Entrypoint script for first-run setup and UID mapping
COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

# Install Codex and its Code Mode sidecar system-wide so they remain available
# when /home/codex is bind-mounted. Authentication and configuration live in
# the persistent /home/codex/.codex directory.
# Keep both executables on the same release to ensure protocol compatibility.
ARG CODEX_VERSION=0.162.1
RUN set -eux; \
    mkdir -p /opt/codex; \
    curl -fsSL \
      "https://github.com/openai/codex/releases/download/rust-v${CODEX_VERSION}/codex-package-x86_64-unknown-linux-musl.tar.gz" \
      | tar -xz -C /opt/codex; \
    ln -sf /opt/codex/bin/codex /usr/local/bin/codex; \
    ln -sf /opt/codex/bin/codex-code-mode-host /usr/local/bin/codex-code-mode-host

ENTRYPOINT ["/opt/entrypoint.sh"]
CMD ["codex"]
