# syntax=docker/dockerfile:1.7

FROM node:22-bookworm-slim AS node_runtime

# Host driver 535.x exposes CUDA 12.2. Keep the image runtime at CUDA 12.2
# and install PyTorch cu121 wheels in the project environment for driver compatibility.
FROM nvidia/cuda:12.2.2-devel-ubuntu22.04

ARG UID=1000
ARG GID=1000
ARG USERNAME=appuser
ARG GIT_NAME="Codex User"
ARG GIT_EMAIL="codex@example.com"

# Ubuntu 22.04 cannot run newer prebuilt releases that require glibc 2.39.
ARG TREE_SITTER_CLI_VERSION=0.25.10

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

WORKDIR /workspace

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    git \
    openssh-client \
    locales \
    tzdata \
    unzip \
    vim \
    tmux \
    htop \
    less \
    jq \
    tree \
    build-essential \
    pkg-config \
    libssl-dev \
    libffi-dev \
    ripgrep \
    fd-find \
    bat \
    zsh \
    ncurses-bin \
    ncurses-term \
    poppler-utils \
    pandoc \
    graphviz \
    parallel \
    file \
    docker.io \
    ffmpegthumbnailer \
    p7zip-full \
 && locale-gen en_US.UTF-8 \
 && apt-get purge -y 'libnvidia-*' 'nvidia-*' 'cuda-drivers*' || true \
 && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p -m 755 /etc/apt/keyrings \
 && wget -qO /etc/apt/keyrings/githubcli-archive-keyring.gpg https://cli.github.com/packages/githubcli-archive-keyring.gpg \
 && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
    gh \
    git-lfs \
    rsync \
 && git lfs install --system \
 && rm -rf /var/lib/apt/lists/*

RUN ln -sf "$(command -v fdfind)" /usr/local/bin/fd \
 && ln -sf "$(command -v batcat)" /usr/local/bin/bat

COPY --from=node_runtime /usr/local/ /usr/local/

RUN groupadd -g "${GID}" "${USERNAME}" \
 && useradd -m -u "${UID}" -g "${GID}" -s /bin/zsh "${USERNAME}" \
 && mkdir -p /workspace \
 && chown -R "${UID}:${GID}" /workspace "/home/${USERNAME}"

USER ${USERNAME}

ENV HOME=/home/${USERNAME}
ENV NPM_CONFIG_PREFIX="${HOME}/.npm-global"
ENV PATH="${HOME}/.venv/bin:${HOME}/.local/bin:${HOME}/.npm-global/bin:${PATH}"
ENV UV_TORCH_BACKEND=cu121
ENV COLORTERM=truecolor
ENV RUNZSH=no
ENV CHSH=no
ENV KEEP_ZSHRC=yes

RUN curl -LsSf https://astral.sh/uv/install.sh | sh

RUN uv python install 3.12 \
 && uv venv "${HOME}/.venv" --python 3.12 \
 && uv pip install --python "${HOME}/.venv/bin/python" pip numpy

# Install the repo-local Markdown history skill. It vendors BM25S and keeps all
# project memory inside each repository's history/ directory.
ARG TRACK_RESEARCH_HISTORY_REPOSITORY=https://github.com/KimJaehee0725/track-research-history.git
ARG TRACK_RESEARCH_HISTORY_REF=c90f27c23928c17688fdfa7c3d06bb3e6e593f45
RUN git init -q /tmp/track-research-history-source \
 && git -C /tmp/track-research-history-source remote add origin \
      "${TRACK_RESEARCH_HISTORY_REPOSITORY}" \
 && git -C /tmp/track-research-history-source fetch -q --depth 1 origin \
      "${TRACK_RESEARCH_HISTORY_REF}" \
 && git -C /tmp/track-research-history-source checkout -q --detach FETCH_HEAD \
 && install -d -m 0755 "${HOME}/.codex/skills/track-research-history" \
 && cp -a /tmp/track-research-history-source/SKILL.md \
      /tmp/track-research-history-source/agents \
      /tmp/track-research-history-source/references \
      /tmp/track-research-history-source/scripts \
      "${HOME}/.codex/skills/track-research-history/" \
 && chmod 0755 "${HOME}/.codex/skills/track-research-history/scripts/history.py" \
 && "${HOME}/.venv/bin/python" \
      "${HOME}/.codex/skills/track-research-history/scripts/history.py" start --help >/dev/null \
 && printf '%s\n' "${TRACK_RESEARCH_HISTORY_REF}" \
      > "${HOME}/.codex/skills/track-research-history/REVISION" \
 && rm -rf /tmp/track-research-history-source

RUN mkdir -p "${NPM_CONFIG_PREFIX}" \
 && npm config set prefix "${NPM_CONFIG_PREFIX}" \
 && npm install -g @openai/codex \
 && codex --version

RUN curl -fsSL https://claude.ai/install.sh | bash \
 && claude --version

RUN EZA_URL="$(curl -fsSL https://api.github.com/repos/eza-community/eza/releases/latest | jq -r '.assets[] | select(.name | test("x86_64-unknown-linux-gnu.tar.gz$")) | .browser_download_url' | head -n1)" \
 && curl -fsSL "${EZA_URL}" -o /tmp/eza.tar.gz \
 && tar -xzf /tmp/eza.tar.gz -C /tmp \
 && install -m 0755 /tmp/eza "${HOME}/.local/bin/eza" \
 && rm -rf /tmp/eza /tmp/eza.tar.gz

RUN arch="$(uname -m)" \
 && case "${arch}" in \
      x86_64) yazi_arch="x86_64-unknown-linux-musl" ;; \
      aarch64) yazi_arch="aarch64-unknown-linux-musl" ;; \
      *) echo "Unsupported architecture: ${arch}" && exit 1 ;; \
    esac \
 && YAZI_URL="$(curl -fsSL https://api.github.com/repos/sxyazi/yazi/releases/latest | jq -r --arg arch "${yazi_arch}" '.assets[] | select(.name | test("yazi-" + $arch + ".zip$")) | .browser_download_url' | head -n1)" \
 && curl -fsSL "${YAZI_URL}" -o /tmp/yazi.zip \
 && unzip -q /tmp/yazi.zip -d /tmp \
 && install -m 0755 /tmp/yazi-*/yazi "${HOME}/.local/bin/yazi" \
 && install -m 0755 /tmp/yazi-*/ya "${HOME}/.local/bin/ya" \
 && rm -rf /tmp/yazi.zip /tmp/yazi-*

RUN uv tool install ruff \
 && STYLUA_URL="$(curl -fsSL https://api.github.com/repos/JohnnyMorganz/StyLua/releases/latest | jq -r '.assets[] | select(.name == "stylua-linux-x86_64-musl.zip" or .name == "stylua-linux-x86_64.zip") | .browser_download_url' | head -n1)" \
 && test -n "${STYLUA_URL}" \
 && curl -fsSL "${STYLUA_URL}" -o /tmp/stylua.zip \
 && unzip -q /tmp/stylua.zip -d /tmp/stylua \
 && install -m 0755 /tmp/stylua/stylua "${HOME}/.local/bin/stylua" \
 && npm install -g "tree-sitter-cli@${TREE_SITTER_CLI_VERSION}" \
 && rm -rf /tmp/stylua /tmp/stylua.zip \
 && ruff --version \
 && stylua --version \
 && tree-sitter --version

RUN git config --global init.defaultBranch main \
 && git config --global pull.rebase false \
 && git config --global user.name "${GIT_NAME}" \
 && git config --global user.email "${GIT_EMAIL}"

# Global guidance points agents at the installed repo-local BM25S skill. No
# passwords, SSH keys, or memory service configuration are copied into images.
COPY --chown=${UID}:${GID} AGENTS.md /home/${USERNAME}/.codex/AGENTS.md

# Keep the DSBA provider available without replacing Codex's default OpenAI
# provider. The API key is supplied only at container runtime.
RUN cat > "${HOME}/.codex/config.toml" <<'EOF'
[model_providers.dsba_litellm]
name = "DSBA LiteLLM"
base_url = "https://dsba-server.duckdns.org:8022/llm/v1"
env_key = "DSBA_LITELLM_API_KEY"
wire_api = "responses"
EOF

RUN cat > "${HOME}/.codex/dsba.config.toml" <<'EOF'
model = "gpt-5.6-sol"
model_provider = "dsba_litellm"
EOF

RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
 && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
      "${HOME}/.oh-my-zsh/custom/themes/powerlevel10k" \
 && git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
      "${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions" \
 && git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
      "${HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" \
 && git clone --depth=1 https://github.com/zsh-users/zsh-completions \
      "${HOME}/.oh-my-zsh/custom/plugins/zsh-completions" \
 && git clone --depth=1 https://github.com/zsh-users/zsh-history-substring-search \
      "${HOME}/.oh-my-zsh/custom/plugins/zsh-history-substring-search"

RUN mkdir -p "${HOME}/.config" \
 && cat > "${HOME}/.config/terminal-env.sh" <<'EOF'
if [ "${TERM:-}" = "xterm-ghostty" ] && ! infocmp xterm-ghostty >/dev/null 2>&1; then
  export TERM=xterm-256color
fi
export COLORTERM=truecolor
EOF

RUN cat > "${HOME}/.tmux.conf" <<'EOF'
set -g default-terminal "tmux-256color"
set -as terminal-features ",xterm-256color:RGB,xterm-ghostty:RGB,tmux-256color:RGB"
set -ga terminal-overrides ",xterm-256color:Tc,xterm-ghostty:Tc,tmux-256color:Tc"

set -g mouse on
set -sg escape-time 10
set -g focus-events on
set -g history-limit 200000

setw -g mode-keys vi
bind-key -T copy-mode-vi v send -X begin-selection
bind-key -T copy-mode-vi y send -X copy-selection-and-cancel

unbind '"'
unbind %
bind | split-window -h
bind - split-window -v
bind -n C-h select-pane -L
bind -n C-j select-pane -D
bind -n C-k select-pane -U
bind -n C-l select-pane -R

set -g status on
set -g status-style "bg=default,fg=default"
set -g status-left  " #S:#I.#P "
set -g status-right " #{?client_prefix,#[reverse] PREFIX #[default],} #{pane_current_path} | %Y-%m-%d %H:%M "
set -g window-status-format         " #I:#W "
set -g window-status-current-format " #[reverse]#I:#W#[default] "
set -g status-interval 2
set -g status-left-length  40
set -g status-right-length 120
EOF

RUN cat > "${HOME}/.zshrc" <<'EOF'
[ -f "$HOME/.config/terminal-env.sh" ] && source "$HOME/.config/terminal-env.sh"
if [[ -f "$HOME/.config/dsba-litellm.key" ]]; then
  export DSBA_LITELLM_API_KEY="$(< "$HOME/.config/dsba-litellm.key")"
fi

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-completions
  zsh-history-substring-search
)

source "$ZSH/oh-my-zsh.sh"

[ -f "$HOME/.local/share/uv/env" ] && source "$HOME/.local/share/uv/env"

export PAGER=less
export LESS='-R -F -X'

alias ls='eza --group-directories-first'
alias ll='eza -lah --icons --git --group-directories-first'
alias lt='eza --tree --level=2 --icons'
alias cat='bat'
alias cdbase='cd /workspace'

bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

function y() {
  local tmp
  tmp="$(mktemp -t yazi-cwd.XXXXXX)"
  yazi "$@" --cwd-file="$tmp"
  if [[ -f "$tmp" ]]; then
    local cwd
    cwd="$(cat "$tmp")"
    [[ -n "$cwd" && "$cwd" != "$PWD" ]] && cd "$cwd"
    rm -f "$tmp"
  fi
}

[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
EOF

# codex-plugin-cc
# The plugin itself is prepared here, but Claude-side activation still happens inside Claude Code.
RUN mkdir -p "${HOME}/.local/share/claude-plugins" \
 && git clone --depth=1 https://github.com/openai/codex-plugin-cc.git \
      "${HOME}/.local/share/claude-plugins/codex-plugin-cc" \
 && cd "${HOME}/.local/share/claude-plugins/codex-plugin-cc" \
 && npm ci

CMD ["zsh", "-l"]
