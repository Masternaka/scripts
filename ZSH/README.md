## Installation ZSH avec zinit

### `install_zsh.sh`
Script d'installation et configuration complète de ZSH pour Linux Mint, Ubuntu et Debian.

#### Fonctionnalités
- Installation de ZSH
- Installation et configuration de zinit (gestionnaire de plugins)
- Installation des plugins :
  - `zsh-autosuggestions` - Suggestions automatiques
  - `zsh-syntax-highlighting` - Coloration syntaxique
  - `zsh-completions` - Complétions avancées
  - `zsh-bat` - Intégration de bat
  - `fzf-zsh-plugin` - Intégration de fzf
  - `zsh-zoxide` - Navigation intelligente avec zoxide
- Installation via Homebrew :
  - `JetBrainsMono` - Police de caractères
  - `bat` - Remplacement amélioré de cat
  - `fzf` - Recherche floue
  - `zoxide` - Navigation intelligente
- Configuration prête à l'emploi avec alias utiles

#### Installation
```bash
# Rendre le script exécutable
chmod +x install_zsh.sh

# Exécuter le script
./install_zsh.sh
```

#### Après l'installation
1. Déconnectez-vous et reconnectez-vous pour appliquer les changements
2. Ou exécutez : `source ~/.zshrc`

#### Alias inclus
- **Navigation** : `..`, `...`, `....`, `mkcd`
- **Fichiers** : `ll`, `la`, `l`, `cat` (remplacé par bat), `extract`
- **Système** : `update`, `install`, `remove`, `search`, `cleanup`
- **Git** : `gs`, `ga`, `gc`, `gp`, `gl`, `gd`, `gb`, `gco`
- **Docker** : `d`, `dc`, `dps`, `di`, `dr`, `dstop`, `drmi`
- **Utilitaires** : `myip`, `weather`, `zshconfig`, `zshreload`, `path`, `now`, `today`


# Installation standard
./install_zsh_enhanced.sh

# Simulation avec debug
./install_zsh_enhanced.sh --dry-run --verbose

# Installation minimaliste
./install_zsh_enhanced.sh --skip-font --no-plugins

# Installation avec thème personnalisé
./install_zsh_enhanced.sh --theme github --prompt powerline

# Désinstallation complète
./install_zsh_enhanced.sh --uninstall