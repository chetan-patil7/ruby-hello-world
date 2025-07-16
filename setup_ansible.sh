#!/bin/bash

# Quick Ansible Setup - Creates a basic structure with example values
# Modify the variables below and run this script

set -e

# =============================================================================
# CONFIGURATION - MODIFY THESE VALUES FOR YOUR ENVIRONMENT
# =============================================================================

# Basic settings
VAULT_PASSWORD="mySecretVaultPassword123"  # Change this!
GIT_REPO_URL="https://github.com/chetan-patil7/ruby-hello-world.git"
APP_NAME="hello-world-app"

# Server IPs (Update these with your actual server IPs)
DEV1_IP="10.0.1.10"
DEV2_IP="10.0.1.20"  
DEV3_IP="10.0.1.30"
STAGING1_IP="10.0.1.40"

# Database configurations (Update these with your actual database details)
DEV1_DB_HOST="dev1-db.example.com"
DEV1_DB_NAME="hello_world_dev1"
DEV1_DB_USER="dev1_user"
DEV1_DB_PASS="dev1_password_123"

DEV2_DB_HOST="dev2-db.example.com"
DEV2_DB_NAME="hello_world_dev2"
DEV2_DB_USER="dev2_user"
DEV2_DB_PASS="dev2_password_456"

DEV3_DB_HOST="dev3-db.example.com"
DEV3_DB_NAME="hello_world_dev3"
DEV3_DB_USER="dev3_user"
DEV3_DB_PASS="dev3_password_789"

STAGING1_DB_HOST="staging1-db.example.com"
STAGING1_DB_NAME="hello_world_staging1"
STAGING1_DB_USER="staging1_user"
STAGING1_DB_PASS="staging1_password_abc"

# =============================================================================
# SCRIPT EXECUTION - DO NOT MODIFY BELOW THIS LINE
# =============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_status() { echo -e "${GREEN}✓${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

echo "🚀 Setting up Ansible directory structure..."

# Check prerequisites
if ! command -v ansible-vault &> /dev/null; then
    print_error "Ansible is not installed!"
    print_info "Install with: sudo apt install ansible (Ubuntu) or brew install ansible (macOS)"
    exit 1
fi

# Create directory structure
print_status "Creating directories..."
mkdir -p ansible/{inventory,group_vars/{dev1_servers,dev2_servers,dev3_servers,staging1_servers},templates}

# Create inventory files
print_status "Creating inventory files..."

cat > ansible/inventory/dev1_hosts << EOF
[dev1_servers]
dev1-server ansible_host=$DEV1_IP ansible_user=deploy
EOF

cat > ansible/inventory/dev2_hosts << EOF
[dev2_servers]
dev2-server ansible_host=$DEV2_IP ansible_user=deploy
EOF

cat > ansible/inventory/dev3_hosts << EOF
[dev3_servers]
dev3-server ansible_host=$DEV3_IP ansible_user=deploy
EOF

cat > ansible/inventory/staging1_hosts << EOF
[staging1_servers]
staging1-server ansible_host=$STAGING1_IP ansible_user=deploy
EOF

# Create vars files
print_status "Creating variable files..."

for env in dev1 dev2 dev3 staging1; do
    rails_env="development"
    [ "$env" = "staging1" ] && rails_env="staging"
    
    cat > "ansible/group_vars/${env}_servers/vars.yml" << EOF
---
app_name: "$APP_NAME"
app_path: "/var/www/$APP_NAME"
app_user: "deploy"
rails_env: "$rails_env"
git_repo_url: "$GIT_REPO_URL"
EOF
done

# Create vault password file
echo "$VAULT_PASSWORD" > .vault_pass
chmod 600 .vault_pass

# Create vault files
print_status "Creating encrypted vault files..."

# Dev1 vault
cat << EOF | ansible-vault encrypt --vault-password-file .vault_pass --output ansible/group_vars/dev1_servers/vault.yml
---
vault_db_host: "$DEV1_DB_HOST"
vault_db_name: "$DEV1_DB_NAME"
vault_db_username: "$DEV1_DB_USER"
vault_db_password: "$DEV1_DB_PASS"
vault_redis_url: "redis://dev1-redis:6379/0"
vault_secret_key_base: "$(openssl rand -hex 64)"
EOF

# Dev2 vault
cat << EOF | ansible-vault encrypt --vault-password-file .vault_pass --output ansible/group_vars/dev2_servers/vault.yml
---
vault_db_host: "$DEV2_DB_HOST"
vault_db_name: "$DEV2_DB_NAME"
vault_db_username: "$DEV2_DB_USER"
vault_db_password: "$DEV2_DB_PASS"
vault_redis_url: "redis://dev2-redis:6379/0"
vault_secret_key_base: "$(openssl rand -hex 64)"
EOF

# Dev3 vault
cat << EOF | ansible-vault encrypt --vault-password-file .vault_pass --output ansible/group_vars/dev3_servers/vault.yml
---
vault_db_host: "$DEV3_DB_HOST"
vault_db_name: "$DEV3_DB_NAME"
vault_db_username: "$DEV3_DB_USER"
vault_db_password: "$DEV3_DB_PASS"
vault_redis_url: "redis://dev3-redis:6379/0"
vault_secret_key_base: "$(openssl rand -hex 64)"
EOF

# Staging1 vault
cat << EOF | ansible-vault encrypt --vault-password-file .vault_pass --output ansible/group_vars/staging1_servers/vault.yml
---
vault_db_host: "$STAGING1_DB_HOST"
vault_db_name: "$STAGING1_DB_NAME"
vault_db_username: "$STAGING1_DB_USER"
vault_db_password: "$STAGING1_DB_PASS"
vault_redis_url: "redis://staging1-redis:6379/0"
vault_secret_key_base: "$(openssl rand -hex 64)"
EOF

# Create database template
print_status "Creating configuration templates..."
cat > ansible/templates/database.yml.j2 << 'EOF'
default: &default
  adapter: postgresql
  encoding: unicode
  pool: 5

development:
  <<: *default
  host: {{ vault_db_host }}
  database: {{ vault_db_name }}
  username: {{ vault_db_username }}
  password: {{ vault_db_password }}

staging:
  <<: *default
  host: {{ vault_db_host }}
  database: {{ vault_db_name }}
  username: {{ vault_db_username }}
  password: {{ vault_db_password }}

production:
  <<: *default
  host: {{ vault_db_host }}
  database: {{ vault_db_name }}
  username: {{ vault_db_username }}
  password: {{ vault_db_password }}
EOF

# Create main playbook
print_status "Creating deployment playbook..."
cat > ansible/deploy.yml << 'EOF'
---
- name: Deploy Ruby Application
  hosts: all
  become: yes

  tasks:
    - name: Update packages
      apt:
        update_cache: yes
        upgrade: safe

    - name: Install dependencies
      apt:
        name:
          - git
          - build-essential
          - libpq-dev
          - nodejs
          - postgresql-client
        state: present

    - name: Create app user
      user:
        name: "{{ app_user }}"
        shell: /bin/bash

    - name: Create app directory
      file:
        path: "{{ app_path }}"
        state: directory
        owner: "{{ app_user }}"
        group: "{{ app_user }}"

    - name: Clone repository
      git:
        repo: "{{ git_repo_url }}"
        dest: "{{ app_path }}"
        version: "{{ branch_name }}"
        force: yes
      become_user: "{{ app_user }}"

    - name: Create database config
      template:
        src: database.yml.j2
        dest: "{{ app_path }}/config/database.yml"
        owner: "{{ app_user }}"
        mode: '0600'

    - name: Install gems
      shell: bundle install --deployment
      args:
        chdir: "{{ app_path }}"
      become_user: "{{ app_user }}"
      environment:
        RAILS_ENV: "{{ rails_env }}"

    - name: Run database setup
      shell: bundle exec rails db:create db:migrate
      args:
        chdir: "{{ app_path }}"
      become_user: "{{ app_user }}"
      environment:
        RAILS_ENV: "{{ rails_env }}"
EOF

# Create ansible.cfg
cat > ansible/ansible.cfg << 'EOF'
[defaults]
host_key_checking = False
timeout = 30
EOF

# Clean up and create reference
rm .vault_pass

cat > VAULT_PASSWORD.txt << EOF
Your Vault Password: $VAULT_PASSWORD

IMPORTANT:
1. Add this password to Jenkins credentials (ID: ansible_vault_password)
2. Delete this file after setup
3. Never commit this to git

Test Commands:
# View vault:
ansible-vault view ansible/group_vars/dev1_servers/vault.yml

# Test deployment:
ansible-playbook -i ansible/inventory/dev1_hosts ansible/deploy.yml --extra-vars "rails_env=development branch_name=dev1" --ask-vault-pass
EOF

cat > ansible/README.md << 'EOF'
# Ansible Configuration

## Quick Start

1. Test connectivity:
```bash
ansible -i inventory/dev1_hosts dev1_servers -m ping --ask-vault-pass
```

2. Deploy to dev1:
```bash
ansible-playbook -i inventory/dev1_hosts deploy.yml --extra-vars "rails_env=development branch_name=dev1" --ask-vault-pass
```

3. View encrypted vault:
```bash
ansible-vault view group_vars/dev1_servers/vault.yml --ask-vault-pass
```

## Files Created:
- inventory/: Server definitions for each environment
- group_vars/: Environment-specific variables (encrypted vaults for DB credentials)
- templates/: Configuration file templates
- deploy.yml: Main deployment playbook
EOF

echo ""
print_status "Setup completed successfully! 🎉"
echo ""
print_info "Created files:"
echo "  📁 ansible/inventory/ - Server inventories"
echo "  📁 ansible/group_vars/ - Environment variables & encrypted vaults"
echo "  📁 ansible/templates/ - Configuration templates"
echo "  📄 ansible/deploy.yml - Main deployment playbook"
echo ""
print_warning "Next steps:"
echo "  1. Review and update server IPs in ansible/inventory/ files"
echo "  2. Update database credentials at the top of this script if needed"
echo "  3. Add vault password to Jenkins credentials"
echo "  4. Test: ansible-vault view ansible/group_vars/dev1_servers/vault.yml"
echo ""
print_info "Vault password saved in: VAULT_PASSWORD.txt (delete after setup)"
echo ""
print_status "Ready for Jenkins deployment! 🚀"