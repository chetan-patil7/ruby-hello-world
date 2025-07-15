#!/bin/bash

# Simplified Rails Deployment Setup Script
# Creates only the necessary files for your 3-command deployment

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Configuration - Update these values
GIT_REPO_URL="https://github.com/your-org/your-rails-app.git"
APP_USER="deploy"

# Server IPs - Update these to match your actual servers
DEV1_IP="192.168.1.101"
DEV2_IP="192.168.1.102"
DEV3_IP="192.168.1.103"
STAGING1_IP="10.0.2.101"
STAGING2_IP="10.0.2.102"
STAGING3_IP="10.0.2.103"

print_header "Simple Rails Deployment Setup"

# Create ansible directory structure
print_status "Creating ansible directory structure..."
mkdir -p ansible/inventory/{dev,staging}

# Create simplified deployment playbook
print_status "Creating deployment playbook..."
cat > ansible/deploy.yml << 'EOF'
---
- name: Deploy Rails Application
  hosts: all
  become: yes
  vars:
    app_path: "{{ app_path | default('/var/www/rails_app') }}"
    app_user: "{{ app_user | default('deploy') }}"
    rails_env: "{{ rails_env | default('development') }}"
    branch_name: "{{ branch_name | default('master') }}"
    
  tasks:
    - name: Display deployment information
      debug:
        msg: |
          Deploying to: {{ inventory_hostname }}
          Rails Environment: {{ rails_env }}
          Branch: {{ branch_name }}
          App Path: {{ app_path }}
          
    - name: Ensure application directory exists
      file:
        path: "{{ app_path }}"
        state: directory
        owner: "{{ app_user }}"
        group: "{{ app_user }}"
        mode: '0755'
    
    - name: Pull latest code from repository
      git:
        repo: "{{ git_repo_url }}"
        dest: "{{ app_path }}"
        version: "{{ branch_name }}"
        force: yes
      become_user: "{{ app_user }}"
    
    - name: Install Ruby gems
      shell: "bundle install"
      args:
        chdir: "{{ app_path }}"
      become_user: "{{ app_user }}"
      environment:
        RAILS_ENV: "{{ rails_env }}"
    
    - name: Create database
      shell: "RAILS_ENV={{ rails_env }} bundle exec rake db:create"
      args:
        chdir: "{{ app_path }}"
      become_user: "{{ app_user }}"
      ignore_errors: yes
    
    - name: Run database migrations
      shell: "RAILS_ENV={{ rails_env }} bundle exec rake db:migrate"
      args:
        chdir: "{{ app_path }}"
      become_user: "{{ app_user }}"
    
    - name: Precompile assets
      shell: "RAILS_ENV={{ rails_env }} bundle exec rake assets:precompile"
      args:
        chdir: "{{ app_path }}"
      become_user: "{{ app_user }}"
    
    - name: Set proper permissions
      file:
        path: "{{ app_path }}"
        owner: "{{ app_user }}"
        group: "{{ app_user }}"
        recurse: yes
    
    - name: Restart Apache service
      service:
        name: apache2
        state: restarted
      notify:
        - check apache status
  
  handlers:
    - name: check apache status
      service:
        name: apache2
        state: started
EOF

# Create development inventory
print_status "Creating development inventory..."
cat > ansible/inventory/dev/hosts << EOF
# Development Environment Inventory

[dev1_servers]
dev1-server ansible_host=${DEV1_IP} ansible_user=${APP_USER}

[dev2_servers]
dev2-server ansible_host=${DEV2_IP} ansible_user=${APP_USER}

[dev3_servers]
dev3-server ansible_host=${DEV3_IP} ansible_user=${APP_USER}

[dev1_servers:vars]
git_repo_url=${GIT_REPO_URL}
app_path=/var/www/rails_app_dev1
app_user=${APP_USER}

[dev2_servers:vars]
git_repo_url=${GIT_REPO_URL}
app_path=/var/www/rails_app_dev2
app_user=${APP_USER}

[dev3_servers:vars]
git_repo_url=${GIT_REPO_URL}
app_path=/var/www/rails_app_dev3
app_user=${APP_USER}

[all_dev_servers:children]
dev1_servers
dev2_servers
dev3_servers
EOF

# Create staging inventory
print_status "Creating staging inventory..."
cat > ansible/inventory/staging/hosts << EOF
# Staging Environment Inventory

[staging1_servers]
staging1-server ansible_host=${STAGING1_IP} ansible_user=${APP_USER}

[staging2_servers]
staging2-server ansible_host=${STAGING2_IP} ansible_user=${APP_USER}

[staging3_servers]
staging3-server ansible_host=${STAGING3_IP} ansible_user=${APP_USER}

[staging1_servers:vars]
git_repo_url=${GIT_REPO_URL}
app_path=/var/www/rails_app_staging1
app_user=${APP_USER}

[staging2_servers:vars]
git_repo_url=${GIT_REPO_URL}
app_path=/var/www/rails_app_staging2
app_user=${APP_USER}

[staging3_servers:vars]
git_repo_url=${GIT_REPO_URL}
app_path=/var/www/rails_app_staging3
app_user=${APP_USER}

[all_staging_servers:children]
staging1_servers
staging2_servers
staging3_servers
EOF

# Create ansible configuration
print_status "Creating ansible configuration..."
cat > ansible/ansible.cfg << 'EOF'
[defaults]
host_key_checking = False
timeout = 30
stdout_callback = yaml
retry_files_enabled = False

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no
pipelining = True
EOF

# Create simple deployment script
print_status "Creating deployment script..."
cat > ansible/deploy.sh << 'EOF'
#!/bin/bash

# Simple deployment script
# Usage: ./deploy.sh <environment> <server> <branch>
# Example: ./deploy.sh dev dev1 dev1

set -e

ENVIRONMENT=$1
SERVER=$2
BRANCH=$3

if [[ -z "$ENVIRONMENT" || -z "$SERVER" || -z "$BRANCH" ]]; then
    echo "Usage: $0 <environment> <server> <branch>"
    echo "  environment: dev or staging"
    echo "  server: dev1, dev2, dev3, staging1, staging2, staging3"
    echo "  branch: git branch name"
    echo ""
    echo "Examples:"
    echo "  $0 dev dev1 dev1"
    echo "  $0 staging staging1 staging1"
    exit 1
fi

# Validate environment
if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "staging" ]]; then
    echo "Error: Environment must be 'dev' or 'staging'"
    exit 1
fi

# Set inventory and rails environment
INVENTORY_FILE="inventory/${ENVIRONMENT}/hosts"
LIMIT="${SERVER}_servers"

# Determine rails environment
case $SERVER in
    dev1) RAILS_ENV="development1" ;;
    dev2) RAILS_ENV="development2" ;;
    dev3) RAILS_ENV="development3" ;;
    staging1) RAILS_ENV="staging1" ;;
    staging2) RAILS_ENV="staging2" ;;
    staging3) RAILS_ENV="staging3" ;;
    *)
        echo "Error: Invalid server name"
        exit 1
        ;;
esac

echo "Deploying $BRANCH to $SERVER (Rails env: $RAILS_ENV)"

# Run deployment
ansible-playbook -i "$INVENTORY_FILE" \
                 --limit "$LIMIT" \
                 --extra-vars "rails_env=$RAILS_ENV branch_name=$BRANCH" \
                 deploy.yml
EOF

chmod +x ansible/deploy.sh

# Create README
print_status "Creating README..."
cat > ansible/README.md << 'EOF'
# Simple Rails Deployment

This is a simplified deployment setup that only runs your three required commands:

1. `RAILS_ENV=<EnvName> bundle exec rake db:create`
2. `RAILS_ENV=<EnvName> bundle exec rake db:migrate`  
3. `RAILS_ENV=<EnvName> bundle exec rake assets:precompile`

Plus Apache restart.

## Usage

### Deploy to specific server:
```bash
cd ansible
./deploy.sh dev dev1 dev1
./deploy.sh staging staging1 staging1
```

### Manual deployment:
```bash
# Development
ansible-playbook -i inventory/dev/hosts --limit dev1_servers --extra-vars "rails_env=development1 branch_name=dev1" deploy.yml

# Staging  
ansible-playbook -i inventory/staging/hosts --limit staging1_servers --extra-vars "rails_env=staging1 branch_name=staging1" deploy.yml
```

## Configuration

Update these files with your actual settings:
- `inventory/dev/hosts` - Development server IPs
- `inventory/staging/hosts` - Staging server IPs
- Update git repository URL in both inventory files

## File Structure

```
ansible/
├── deploy.yml                 # Main playbook
├── deploy.sh                  # Deployment script
├── ansible.cfg                # Ansible config
├── README.md                  # This file
└── inventory/
    ├── dev/hosts              # Dev servers
    └── staging/hosts          # Staging servers
```

No extra complexity, just your three commands!
EOF

print_header "Setup Complete!"
print_status "Created simplified deployment structure:"
echo "  ansible/"
echo "  ├── deploy.yml"
echo "  ├── deploy.sh"
echo "  ├── ansible.cfg"
echo "  ├── README.md"
echo "  └── inventory/"
echo "      ├── dev/hosts"
echo "      └── staging/hosts"

print_header "Next Steps"
echo "1. Update server IPs in inventory files"
echo "2. Update git repository URL"
echo "3. Test deployment: cd ansible && ./deploy.sh dev dev1 dev1"

print_status "Simple setup complete! No redis, master keys, or other extras."
EOF

You're absolutely right! I was adding unnecessary complexity. Here's a **simplified version** that focuses only on your three required commands:

## **What This Simplified Version Does:**

### **Only Your 3 Commands:**
1. `RAILS_ENV=<EnvName> bundle exec rake db:create`
2. `RAILS_ENV=<EnvName> bundle exec rake db:migrate`  
3. `RAILS_ENV=<EnvName> bundle exec rake assets:precompile`
4. Apache restart

### **No Extra Complexity:**
- ❌ No Redis URLs
- ❌ No Rails master keys  
- ❌ No SSL configurations
- ❌ No backup systems
- ❌ No health checks
- ❌ No complex templates

### **Simple Structure:**
```
ansible/
├── deploy.yml                 # Simple playbook (your 3 commands)
├── deploy.sh                  # Easy deployment script
├── ansible.cfg                # Basic config
└── inventory/
    ├── dev/hosts              # Dev servers only
    └── staging/hosts          # Staging servers only
```

### **Usage:**
```bash
# Setup
chmod +x simplified_setup.sh
./simplified_setup.sh

# Deploy
cd ansible
./deploy.sh dev dev1 dev1
./deploy.sh staging staging1 staging1
```

### **What You Need to Update:**
1. **Server IPs** in inventory files
2. **Git repository URL** 
3. **Database credentials** (they'll be in your Rails app's database.yml)

This simplified version removes all the extra features and focuses only on:
- Git pull
- Bundle install
- Your 3 rake commands
- Apache restart

Much cleaner and exactly what you need!