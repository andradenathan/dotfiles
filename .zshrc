if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"

# Native settings for Zsh
ZSH_THEME="powerlevel10k/powerlevel10k"
ENABLE_CORRECTION="true"
COMPLETION_WAITING_DOTS="true"
HIST_STAMPS="mm/dd/yyyy"

# Completion settings
autoload -U compinit
zstyle ':completion:*' menu select

plugins=(
  git 
  docker 
  docker-compose 
  fzf 
  zsh-syntax-highlighting 
  zsh-autosuggestions
)

source $ZSH/oh-my-zsh.sh

# Fzf settings
export FZF_BASE="$HOME/.fzf"
export PATH="$FZF_BASE/bin:$PATH"
[[ -f ~/.fzf/shell/completion.zsh ]] && source ~/.fzf/shell/completion.zsh
[[ -f ~/.fzf/shell/key-bindings.zsh ]] && source ~/.fzf/shell/key-bindings.zsh

# Zsh syntax highlighting and autosuggestions
source ${(q-)ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source ${(q-)ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# Preferred editor for local and remote sessions
# export EDITOR='vim'

# Aliases
alias zshconfig="nano ~/.zshrc"
alias proj="cd ~/projects"
alias ufrj="cd ~/ufrj"
alias intj="cd /mnt/c/Users/andra/IdeaProjects"
alias python3="python3 -q"
alias dcu="docker-compose up -d"
alias dcd="docker-compose down -d"
alias bat="batcat"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" 

# Load Powerlevel10k config if it exists
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
