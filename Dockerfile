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
    sqlite3 \
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
 && mkdir -p /run/research-memory /opt/research-memory-client \
 && touch /run/research-memory/client.json \
          /run/research-memory/id_ed25519 \
          /run/research-memory/known_hosts \
          /run/research-memory/ssh_config \
 && chmod 0755 /run/research-memory /opt/research-memory-client \
 && chown -R "${UID}:${GID}" /workspace "/home/${USERNAME}"

USER ${USERNAME}

ENV HOME=/home/${USERNAME}
ENV NPM_CONFIG_PREFIX="${HOME}/.npm-global"
ENV PATH="${HOME}/.local/bin:${HOME}/.npm-global/bin:${PATH}"
ENV UV_TORCH_BACKEND=cu121
ENV COLORTERM=truecolor
ENV RUNZSH=no
ENV CHSH=no
ENV KEEP_ZSHRC=yes

RUN curl -LsSf https://astral.sh/uv/install.sh | sh

RUN uv python install 3.12 \
 && uv venv "${HOME}/.venv" --python 3.12 \
 && uv pip install --python "${HOME}/.venv/bin/python" pip numpy \
 && mkdir -p "${HOME}/.local/bin" \
 && ln -sf "${HOME}/.venv/bin/python" "${HOME}/.local/bin/python" \
 && ln -sf "${HOME}/.venv/bin/python" "${HOME}/.local/bin/python3" \
 && ln -sf "${HOME}/.venv/bin/pip" "${HOME}/.local/bin/pip" \
 && ln -sf "${HOME}/.venv/bin/pip" "${HOME}/.local/bin/pip3"

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
 && npm install -g tree-sitter-cli \
 && rm -rf /tmp/stylua /tmp/stylua.zip \
 && ruff --version \
 && stylua --version \
 && tree-sitter --version

RUN git config --global init.defaultBranch main \
 && git config --global pull.rebase false \
 && git config --global user.name "${GIT_NAME}" \
 && git config --global user.email "${GIT_EMAIL}"

RUN mkdir -p "${HOME}/.local/bin" \
 && cat > "${HOME}/.local/bin/init-dev-auth" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

github_token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
hf_token="${HF_TOKEN:-${HUGGINGFACE_TOKEN:-}}"
wandb_token="${WANDB_API_KEY:-}"

if [[ -f "${HOME}/.config/dev-tokens/.tokens" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${HOME}/.config/dev-tokens/.tokens"
  set +a
  github_token="${GITHUB_TOKEN:-${GH_TOKEN:-${github_token}}}"
  hf_token="${HF_TOKEN:-${HUGGINGFACE_TOKEN:-${hf_token}}}"
  wandb_token="${WANDB_API_KEY:-${wandb_token}}"
fi

if [[ -n "${github_token}" ]]; then
  if command -v gh >/dev/null 2>&1 && ! gh auth status >/dev/null 2>&1; then
    printf '%s\n' "${github_token}" | gh auth login --with-token >/dev/null
  fi
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    gh auth setup-git >/dev/null
  elif ! git config --global credential.https://github.com.helper >/dev/null; then
    git config --global credential.https://github.com.helper store
    printf 'protocol=https\nhost=github.com\nusername=x-access-token\npassword=%s\n\n' "${github_token}" | git credential approve
  fi
fi

if [[ -n "${hf_token}" ]]; then
  mkdir -p "${HOME}/.cache/huggingface" "${HOME}/.config/huggingface"
  chmod 700 "${HOME}/.cache/huggingface" "${HOME}/.config/huggingface"
  printf '%s' "${hf_token}" > "${HOME}/.cache/huggingface/token"
  printf '%s' "${hf_token}" > "${HOME}/.config/huggingface/token"
  chmod 600 "${HOME}/.cache/huggingface/token" "${HOME}/.config/huggingface/token"
fi

if [[ -n "${wandb_token}" ]]; then
  rm -rf "${HOME}/.netrc"
  cat > "${HOME}/.netrc" <<NETRC
machine api.wandb.ai
  login user
  password ${wandb_token}
NETRC
  chmod 600 "${HOME}/.netrc"
fi
EOF

RUN chmod 700 "${HOME}/.local/bin/init-dev-auth"

# Install a non-secret, project-scoped memory skill. Runtime configuration and
# SSH material are mounted only by make_container.sh.
COPY --chown=${UID}:${GID} AGENTS.md /home/${USERNAME}/.codex/AGENTS.md
COPY --chown=${UID}:${GID} skills/research-memory /home/${USERNAME}/.codex/skills/research-memory
COPY --chmod=0755 --chown=${UID}:${GID} scripts/research-memory /home/${USERNAME}/.local/bin/research-memory

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
alias auth-init='init-dev-auth'

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
