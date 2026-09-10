FROM node:24-bookworm

ARG RTK_VERSION=v0.45.0
USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates curl fd-find fzf git gh gnupg jq openssh-client ripgrep tmux zsh \
       zsh-autosuggestions zsh-syntax-highlighting yq bat btop less procps \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && ln -sf /usr/bin/batcat /usr/local/bin/bat \
    && corepack enable \
    && corepack prepare pnpm@10.20.0 --activate \
    && curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh \
       | PATH=/root/.local/bin:$PATH RTK_VERSION=${RTK_VERSION} sh \
    && install -m 0755 /root/.local/bin/rtk /usr/local/bin/rtk \
    && install -d -m 0755 /etc/apt/keyrings \
    && curl -fsSL https://deb.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc \
       | gpg --dearmor --yes -o /etc/apt/keyrings/deb.griffo.io.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/deb.griffo.io.gpg] https://deb.griffo.io/apt bookworm main" \
       > /etc/apt/sources.list.d/deb.griffo.io.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends lazygit \
    && rm -rf /var/lib/apt/lists/* \
    && install -d -m 0755 /opt/warhammer/bin /workspaces \
    && curl -fsSL https://chatgpt.com/codex/install.sh \
       | CODEX_HOME=/opt/codex CODEX_INSTALL_DIR=/usr/local/bin CODEX_NON_INTERACTIVE=1 sh \
    && chown -R node:node /opt/warhammer /workspaces

COPY .devcontainer/dotfiles/.zshrc .devcontainer/dotfiles/.tmux.conf /tmp/
RUN install -o node -g node -m 0644 /tmp/.zshrc /home/node/.zshrc \
    && install -o node -g node -m 0644 /tmp/.tmux.conf /home/node/.tmux.conf \
    && rm -f /tmp/.zshrc /tmp/.tmux.conf

COPY .devcontainer/scripts/ /opt/warhammer/bin/
RUN chmod +x /opt/warhammer/bin/* \
    && for script in /opt/warhammer/bin/*; do ln -sf "$script" "/usr/local/bin/$(basename "$script")"; done

USER node
ENV PATH="/home/node/.local/bin:/opt/warhammer/bin:${PATH}" \
    PNPM_HOME="/home/node/.local/share/pnpm"
