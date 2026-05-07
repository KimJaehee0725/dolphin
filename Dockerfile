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
ARG TRACK_RESEARCH_HISTORY_REF=main

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

RUN git config --global init.defaultBranch main \
 && git config --global core.editor vim \
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

RUN mkdir -p "${HOME}/.codex/skills" "${HOME}/.claude/skills"

RUN git clone --depth=1 --branch "${TRACK_RESEARCH_HISTORY_REF}" https://github.com/KimJaehee0725/track-research-history.git /tmp/track-research-history \
 && mkdir -p "${HOME}/.codex/skills/track-research-history" "${HOME}/.claude/skills/track-research-history" \
 && cp -a /tmp/track-research-history/. "${HOME}/.codex/skills/track-research-history/" \
 && cp -a /tmp/track-research-history/. "${HOME}/.claude/skills/track-research-history/" \
 && rm -rf \
      "${HOME}/.codex/skills/track-research-history/.git" \
      "${HOME}/.claude/skills/track-research-history/.git" \
      /tmp/track-research-history

RUN mkdir -p "${HOME}/.codex/skills/paper-triage" "${HOME}/.claude/skills/paper-triage" \
 && printf '%s\n' \
    '---' \
    'name: paper-triage' \
    'description: Rapidly triage NLP/ML papers and extract contribution, method, datasets, metrics, limitations, and reproducibility risks.' \
    '---' \
    '' \
    'Use this skill when the user asks to read, summarize, compare, or assess an NLP/ML paper.' \
    '' \
    'Workflow:' \
    '1. Identify problem and claimed contribution.' \
    '2. Extract method, data, evaluation, and baselines.' \
    '3. Flag reproducibility gaps and weak comparisons.' \
    '4. End with what is truly new and what to reproduce first.' \
    > "${HOME}/.codex/skills/paper-triage/SKILL.md" \
 && cp "${HOME}/.codex/skills/paper-triage/SKILL.md" "${HOME}/.claude/skills/paper-triage/SKILL.md"

RUN mkdir -p "${HOME}/.codex/skills/experiment-planner" "${HOME}/.claude/skills/experiment-planner" \
 && printf '%s\n' \
    '---' \
    'name: experiment-planner' \
    'description: Design robust NLP experiments with baselines, ablations, seeds, metrics, and stop/go criteria.' \
    '---' \
    '' \
    'Use this skill when the user wants experiment design or ablation planning.' \
    '' \
    'Workflow:' \
    '1. Restate the hypothesis.' \
    '2. Define minimal baselines.' \
    '3. Define variables and ablations.' \
    '4. Require seeds, fixed splits, and variance reporting.' \
    '5. End with a concise run sheet.' \
    > "${HOME}/.codex/skills/experiment-planner/SKILL.md" \
 && cp "${HOME}/.codex/skills/experiment-planner/SKILL.md" "${HOME}/.claude/skills/experiment-planner/SKILL.md"

RUN mkdir -p "${HOME}/.codex/skills/error-analysis" "${HOME}/.claude/skills/error-analysis" \
 && printf '%s\n' \
    '---' \
    'name: error-analysis' \
    'description: Perform structured NLP error analysis on predictions, labels, generations, retrieval misses, and evaluation failures.' \
    '---' \
    '' \
    'Use this skill when the user asks why a model failed or how to categorize failures.' \
    '' \
    'Workflow:' \
    '1. Separate metric failure from product failure.' \
    '2. Bucket representative errors.' \
    '3. Hypothesize root causes.' \
    '4. Propose the smallest confirming experiment.' \
    > "${HOME}/.codex/skills/error-analysis/SKILL.md" \
 && cp "${HOME}/.codex/skills/error-analysis/SKILL.md" "${HOME}/.claude/skills/error-analysis/SKILL.md"

RUN mkdir -p "${HOME}/.codex/skills/dataset-audit" "${HOME}/.claude/skills/dataset-audit" \
 && printf '%s\n' \
    '---' \
    'name: dataset-audit' \
    'description: Audit NLP datasets for leakage, duplication, imbalance, annotation artifacts, and split contamination.' \
    '---' \
    '' \
    'Use this skill when the user wants to inspect datasets or corpus quality.' \
    '' \
    'Checklist:' \
    '1. Schema and provenance.' \
    '2. Split leakage and near-duplicates.' \
    '3. Class/domain/length imbalance.' \
    '4. Annotation artifacts and cleanup priorities.' \
    > "${HOME}/.codex/skills/dataset-audit/SKILL.md" \
 && cp "${HOME}/.codex/skills/dataset-audit/SKILL.md" "${HOME}/.claude/skills/dataset-audit/SKILL.md"

RUN mkdir -p "${HOME}/.codex/skills/repro-check" "${HOME}/.claude/skills/repro-check" \
 && printf '%s\n' \
    '---' \
    'name: repro-check' \
    'description: Check reproducibility for NLP/ML experiments, including seeds, environments, configs, logging, and artifact traceability.' \
    '---' \
    '' \
    'Use this skill when the user wants to reproduce results or explain run-to-run variance.' \
    '' \
    'Checklist:' \
    '1. Environment and versions.' \
    '2. Config completeness.' \
    '3. Data snapshot/version.' \
    '4. Artifact lineage.' \
    '5. Most likely causes of mismatch.' \
    > "${HOME}/.codex/skills/repro-check/SKILL.md" \
 && cp "${HOME}/.codex/skills/repro-check/SKILL.md" "${HOME}/.claude/skills/repro-check/SKILL.md"

# codex-plugin-cc
# The plugin itself is prepared here, but Claude-side activation still happens inside Claude Code.
RUN mkdir -p "${HOME}/.local/share/claude-plugins" \
 && git clone --depth=1 https://github.com/openai/codex-plugin-cc.git \
      "${HOME}/.local/share/claude-plugins/codex-plugin-cc" \
 && cd "${HOME}/.local/share/claude-plugins/codex-plugin-cc" \
 && npm ci

CMD ["zsh", "-l"]
