#!/bin/bash

# Navigate to your Rails project root directory
cd /path/to/your/hello-world-app

# Create Ansible directory structure
echo "📁 Creating Ansible directory structure..."
mkdir -p ansible/{inventories,playbooks,roles,group_vars}
mkdir -p ansible/inventories/{staging,production}
mkdir -p ansible/inventories/staging/group_vars
mkdir -p ansible/inventories/production/group_vars
mkdir -p ansible/roles/{common,rails-app,user-management}
mkdir -p ansible/roles/common/{tasks,templates,files,vars,handlers}
mkdir -p ansible/roles/rails-app/{tasks,templates,files,vars,handlers}
mkdir -p ansible/roles/user-management/{tasks,templates,files,vars,handlers}

echo "✅ Directory structure created"

# Create ansible.cfg
echo "📝 Creating ansible.cfg..."
cat > ansible/ansible.cfg << 'EOF'
[defaults]
host_key_checking = False
retry_files_enabled = False
inventory = inventories/staging/hosts
roles_path = roles
remote_user = deploy
private_key_file = ~/.ssh/deploy_key
timeout = 30

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no
EOF

# Create staging inventory
echo "📝 Creating staging inventory..."
cat > ansible/inventories/staging/hosts << 'EOF'
[webservers]
staging-server ansible_host=44.197.187.21 ansible_user=deploy

[all:vars]
ansible_ssh_private_key_file=~/.ssh/deploy_key
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
rails_env=staging
app_name=hello-world-app
deploy_user=deploy
deploy_path=/var/www/hello-world-app
EOF

# Create staging group variables
echo "📝 Creating staging group variables..."
cat > ansible/inventories/staging/group_vars/all.yml << 'EOF'
---
# Environment
rails_env: staging
app_name: hello-world-app
deploy_user: deploy
deploy_path: /var/www/hello-world-app

# Ruby configuration
ruby_version: "3.1.3"
bundler_version: "2.3.0"

# Database configuration
database_name: hello_world_staging
database_user: rails_user
database_password: "secure_password_123"

# Server configuration
server_name: staging.yourdomain.com
nginx_port: 80
rails_port: 3000

# User Management Groups
user_groups:
  admin_group:
    name: admin_group
    description: "Full administrative access"
  ops_group:
    name: ops_group
    description: "Operations access - no delete permissions"
  readonly_group:
    name: readonly_group
    description: "Read-only access"
EOF

# Create production inventory
echo "📝 Creating production inventory..."
cat > ansible/inventories/production/hosts << 'EOF'
[webservers]
production-server ansible_host=YOUR_PRODUCTION_EC2_IP ansible_user=deploy

[all:vars]
ansible_ssh_private_key_file=~/.ssh/deploy_key
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
rails_env=production
app_name=hello-world-app
deploy_user=deploy
deploy_path=/var/www/hello-world-app
EOF

# Create production group variables
echo "📝 Creating production group variables..."
cat > ansible/inventories/production/group_vars/all.yml << 'EOF'
---
# Environment
rails_env: production
app_name: hello-world-app
deploy_user: deploy
deploy_path: /var/www/hello-world-app

# Ruby configuration
ruby_version: "3.1.3"
bundler_version: "2.3.0"

# Database configuration
database_name: hello_world_production
database_user: rails_user
database_password: "production_secure_password_456"

# Server configuration
server_name: yourdomain.com
nginx_port: 80
rails_port: 3000

# User Management Groups
user_groups:
  admin_group:
    name: admin_group
    description: "Full administrative access"
  ops_group:
    name: ops_group
    description: "Operations access - no delete permissions"
  readonly_group:
    name: readonly_group
    description: "Read-only access"
EOF

# Create common role tasks
echo "📝 Creating common role..."
cat > ansible/roles/common/tasks/main.yml << 'EOF'
---
- name: Update apt cache
  apt:
    update_cache: yes
    cache_valid_time: 3600
  become: yes

- name: Install system dependencies
  apt:
    name:
      - curl
      - wget
      - git
      - build-essential
      - libssl-dev
      - libreadline-dev
      - zlib1g-dev
      - libyaml-dev
      - libxml2-dev
      - libxslt1-dev
      - libcurl4-openssl-dev
      - libffi-dev
      - postgresql
      - postgresql-contrib
      - libpq-dev
      - nginx
      - auditd
    state: present
  become: yes

- name: Start and enable services
  systemd:
    name: "{{ item }}"
    state: started
    enabled: yes
  loop:
    - postgresql
    - nginx
    - auditd
  become: yes

- name: Create deployment directories
  file:
    path: "{{ item }}"
    state: directory
    owner: "{{ deploy_user }}"
    group: "{{ deploy_user }}"
    mode: '0755'
  loop:
    - "{{ deploy_path }}"
    - "{{ deploy_path }}/{{ rails_env }}"
    - "{{ deploy_path }}/{{ rails_env }}/releases"
    - "{{ deploy_path }}/{{ rails_env }}/shared"
    - "{{ deploy_path }}/{{ rails_env }}/shared/log"
    - "{{ deploy_path }}/{{ rails_env }}/shared/tmp"
    - "{{ deploy_path }}/{{ rails_env }}/shared/config"
  become: yes

- name: Setup rbenv for deploy user
  shell: |
    if [ ! -d /home/{{ deploy_user }}/.rbenv ]; then
      git clone https://github.com/rbenv/rbenv.git /home/{{ deploy_user }}/.rbenv
      git clone https://github.com/rbenv/ruby-build.git /home/{{ deploy_user }}/.rbenv/plugins/ruby-build
      echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> /home/{{ deploy_user }}/.bashrc
      echo 'eval "$(rbenv init -)"' >> /home/{{ deploy_user }}/.bashrc
      chown -R {{ deploy_user }}:{{ deploy_user }} /home/{{ deploy_user }}/.rbenv
    fi
  become: yes

- name: Install Ruby and Bundler
  shell: |
    export PATH="/home/{{ deploy_user }}/.rbenv/bin:$PATH"
    eval "$(rbenv init -)"
    if ! rbenv versions | grep -q {{ ruby_version }}; then
      rbenv install {{ ruby_version }}
      rbenv global {{ ruby_version }}
      rbenv rehash
      # Install bundler
      ~/.rbenv/versions/{{ ruby_version }}/bin/gem install bundler -v {{ bundler_version }}
      rbenv rehash
    fi
  become: yes
  become_user: "{{ deploy_user }}"
  environment:
    PATH: "/home/{{ deploy_user }}/.rbenv/bin:{{ ansible_env.PATH }}"

- name: Setup PostgreSQL database
  postgresql_db:
    name: "{{ database_name }}"
    owner: "{{ database_user }}"
    state: present
  become: yes
  become_user: postgres

- name: Create PostgreSQL user
  postgresql_user:
    name: "{{ database_user }}"
    password: "{{ database_password }}"
    role_attr_flags: CREATEDB,NOSUPERUSER
    state: present
  become: yes
  become_user: postgres
EOF

# Create rails-app role tasks
echo "📝 Creating rails-app role..."
cat > ansible/roles/rails-app/tasks/main.yml << 'EOF'
---
- name: Create release directory
  file:
    path: "{{ deploy_path }}/{{ rails_env }}/releases/{{ ansible_date_time.epoch }}"
    state: directory
    owner: "{{ deploy_user }}"
    group: "{{ deploy_user }}"
    mode: '0755'
  become: yes

- name: Set release directory variable
  set_fact:
    release_dir: "{{ deploy_path }}/{{ rails_env }}/releases/{{ ansible_date_time.epoch }}"
    current_dir: "{{ deploy_path }}/{{ rails_env }}/current"

- name: Check if application archive exists
  stat:
    path: "{{ app_archive_path }}"
  register: archive_stat

- name: Extract application archive
  unarchive:
    src: "{{ app_archive_path }}"
    dest: "{{ release_dir }}"
    owner: "{{ deploy_user }}"
    group: "{{ deploy_user }}"
    mode: '0755'
    remote_src: yes
  become: yes
  when: archive_stat.stat.exists

- name: Generate Rails secret key
  shell: ruby -e "require 'securerandom'; puts SecureRandom.hex(64)"
  register: rails_secret
  become_user: "{{ deploy_user }}"

- name: Create environment file
  template:
    src: env.j2
    dest: "{{ deploy_path }}/{{ rails_env }}/shared/config/.env.{{ rails_env }}"
    owner: "{{ deploy_user }}"
    group: "{{ deploy_user }}"
    mode: '0600'
  become: yes

- name: Create symlinks to shared directories
  file:
    src: "{{ deploy_path }}/{{ rails_env }}/shared/{{ item }}"
    dest: "{{ release_dir }}/{{ item }}"
    state: link
    owner: "{{ deploy_user }}"
    group: "{{ deploy_user }}"
    force: yes
  loop:
    - log
    - tmp
    - config/.env.{{ rails_env }}
  become: yes

- name: Install gems
  shell: |
    export PATH="/home/{{ deploy_user }}/.rbenv/bin:$PATH"
    eval "$(rbenv init -)"
    rbenv rehash
    cd {{ release_dir }}
    
    # Ensure bundle is available
    if ! command -v bundle &> /dev/null; then
      ~/.rbenv/versions/{{ ruby_version }}/bin/gem install bundler -v {{ bundler_version }}
      rbenv rehash
    fi
    
    bundle install --deployment --without development test
  become: yes
  become_user: "{{ deploy_user }}"
  environment:
    PATH: "/home/{{ deploy_user }}/.rbenv/bin:/home/{{ deploy_user }}/.rbenv/shims:{{ ansible_env.PATH }}"

- name: Run database migrations
  shell: |
    export PATH="/home/{{ deploy_user }}/.rbenv/bin:$PATH"
    eval "$(rbenv init -)"
    rbenv rehash
    cd {{ release_dir }}
    source config/.env.{{ rails_env }}
    bundle exec rake db:create db:migrate
  become: yes
  become_user: "{{ deploy_user }}"
  environment:
    RAILS_ENV: "{{ rails_env }}"
    PATH: "/home/{{ deploy_user }}/.rbenv/bin:/home/{{ deploy_user }}/.rbenv/shims:{{ ansible_env.PATH }}"

- name: Precompile assets
  shell: |
    export PATH="/home/{{ deploy_user }}/.rbenv/bin:$PATH"
    eval "$(rbenv init -)"
    rbenv rehash
    cd {{ release_dir }}
    source config/.env.{{ rails_env }}
    bundle exec rake assets:precompile
  become: yes
  become_user: "{{ deploy_user }}"
  environment:
    RAILS_ENV: "{{ rails_env }}"
    PATH: "/home/{{ deploy_user }}/.rbenv/bin:/home/{{ deploy_user }}/.rbenv/shims:{{ ansible_env.PATH }}"

- name: Update current symlink
  file:
    src: "{{ release_dir }}"
    dest: "{{ current_dir }}"
    state: link
    owner: "{{ deploy_user }}"
    group: "{{ deploy_user }}"
    force: yes
  become: yes

- name: Cleanup old releases
  shell: |
    cd {{ deploy_path }}/{{ rails_env }}/releases
    ls -t | tail -n +6 | xargs rm -rf
  become: yes
  become_user: "{{ deploy_user }}"
  ignore_errors: yes
EOF

# Create environment template
echo "📝 Creating environment template..."
cat > ansible/roles/rails-app/templates/env.j2 << 'EOF'
RAILS_ENV={{ rails_env }}
DATABASE_URL=postgresql://{{ database_user }}:{{ database_password }}@localhost:5432/{{ database_name }}
SECRET_KEY_BASE={{ rails_secret.stdout }}
RAILS_LOG_TO_STDOUT=true
RAILS_SERVE_STATIC_FILES=true
EOF

# Create user-management role
echo "📝 Creating user-management role..."
cat > ansible/roles/user-management/tasks/main.yml << 'EOF'
---
- name: Create user groups
  group:
    name: "{{ item.value.name }}"
    state: present
  loop: "{{ user_groups | dict2items }}"
  become: yes

- name: Create user with specified access level
  user:
    name: "{{ new_username }}"
    shell: /bin/bash
    groups: "{{ user_access_group }}"
    append: yes
    create_home: yes
    state: present
  become: yes
  when: new_username is defined

- name: Setup SSH directory for new user
  file:
    path: "/home/{{ new_username }}/.ssh"
    state: directory
    owner: "{{ new_username }}"
    group: "{{ new_username }}"
    mode: '0700'
  become: yes
  when: new_username is defined

- name: Copy SSH key to new user (optional)
  copy:
    src: "/home/{{ deploy_user }}/.ssh/authorized_keys"
    dest: "/home/{{ new_username }}/.ssh/authorized_keys"
    owner: "{{ new_username }}"
    group: "{{ new_username }}"
    mode: '0600'
    remote_src: yes
  become: yes
  when: new_username is defined and copy_ssh_key | default(false)

- name: Setup sudoers configuration
  template:
    src: sudoers_config.j2
    dest: /etc/sudoers.d/tiered_access
    mode: '0440'
    validate: 'visudo -cf %s'
  become: yes

- name: Display user creation summary
  debug:
    msg: |
      User '{{ new_username }}' created successfully!
      Access Level: {{ user_access_level }}
      Group: {{ user_access_group }}
      SSH Access: {{ 'Enabled' if copy_ssh_key | default(false) else 'Disabled' }}
  when: new_username is defined
EOF

# Create sudoers template
echo "📝 Creating sudoers template..."
cat > ansible/roles/user-management/templates/sudoers_config.j2 << 'EOF'
# Tiered Access Sudoers Configuration
# Generated by Ansible

# Admin Group - Full access to everything
%admin_group ALL=(ALL) NOPASSWD: ALL

# Operations Group - Can do most things but cannot delete files
%ops_group ALL=(ALL) NOPASSWD: ALL, !/bin/rm, !/bin/rmdir, !/usr/bin/rm, !/usr/bin/rmdir, !/bin/rm *, !/usr/bin/rm *, !/bin/unlink, !/usr/bin/unlink

# Read-only Group - Limited to viewing commands only
%readonly_group ALL=(ALL) NOPASSWD: /bin/cat, /bin/less, /bin/more, /bin/head, /bin/tail, /bin/grep, /bin/find, /bin/ls, /usr/bin/du, /usr/bin/df, /bin/ps, /usr/bin/top, /usr/bin/htop, /bin/netstat, /bin/ss
EOF

# Create deploy playbook
echo "📝 Creating deploy playbook..."
cat > ansible/playbooks/deploy.yml << 'EOF'
---
- name: Deploy Rails Application
  hosts: webservers
  become: yes
  vars:
    app_archive_path: "/tmp/{{ app_name }}-{{ build_number | default('latest') }}.tar.gz"
  
  pre_tasks:
    - name: Verify archive exists
      stat:
        path: "{{ app_archive_path }}"
      register: archive_stat
      
    - name: Fail if archive doesn't exist
      fail:
        msg: "Application archive not found at {{ app_archive_path }}"
      when: not archive_stat.stat.exists

  roles:
    - common
    - rails-app

  post_tasks:
    - name: Start Rails application
      shell: |
        cd {{ deploy_path }}/{{ rails_env }}/current
        export PATH="/home/{{ deploy_user }}/.rbenv/bin:$PATH"
        eval "$(rbenv init -)"
        rbenv rehash
        source config/.env.{{ rails_env }}
        pkill -f 'rails server' || true
        nohup bundle exec rails server -e {{ rails_env }} -p {{ rails_port }} -b 0.0.0.0 > log/rails.log 2>&1 &
      become: yes
      become_user: "{{ deploy_user }}"
      environment:
        PATH: "/home/{{ deploy_user }}/.rbenv/bin:/home/{{ deploy_user }}/.rbenv/shims:{{ ansible_env.PATH }}"
      
    - name: Wait for application to start
      wait_for:
        port: "{{ rails_port }}"
        host: "{{ ansible_host }}"
        delay: 10
        timeout: 60
      delegate_to: localhost
      
    - name: Display deployment information
      debug:
        msg: |
          🎉 Deployment completed successfully!
          Environment: {{ rails_env }}
          Server: {{ ansible_host }}
          Application URL: http://{{ ansible_host }}:{{ rails_port }}
          Deploy path: {{ deploy_path }}/{{ rails_env }}/current
EOF

# Create setup playbook
echo "📝 Creating setup playbook..."
cat > ansible/playbooks/setup-server.yml << 'EOF'
---
- name: Initial Server Setup
  hosts: webservers
  become: yes
  
  roles:
    - common
    - user-management
    
  post_tasks:
    - name: Display setup completion
      debug:
        msg: |
          🎉 Server setup completed successfully!
          ✅ Ruby {{ ruby_version }} installed
          ✅ PostgreSQL configured
          ✅ User management system configured
          ✅ Security groups created:
             - admin_group (full access)
             - ops_group (no delete permissions)
             - readonly_group (view only)
          
          📝 Next steps:
          1. Create users with: ansible-playbook playbooks/create-user.yml
          2. Deploy application with: ansible-playbook playbooks/deploy.yml
EOF

# Create user creation playbook
echo "📝 Creating user creation playbook..."
cat > ansible/playbooks/create-user.yml << 'EOF'
---
- name: Create User with Tiered Access
  hosts: webservers
  become: yes
  
  vars_prompt:
    - name: new_username
      prompt: "Enter username to create"
      private: no
      
    - name: user_access_level
      prompt: |
        Select access level:
        1. admin (Full access - can run anything)
        2. operations (Can read/write but not delete files)
        3. readonly (Can only view files)
        Enter choice (1/2/3)
      private: no
      
    - name: copy_ssh_key
      prompt: "Copy SSH key from deploy user? (yes/no)"
      private: no
      default: "no"

  pre_tasks:
    - name: Validate access level choice
      set_fact:
        user_access_group: "{{ 
          'admin_group' if user_access_level == '1' or user_access_level == 'admin' else
          'ops_group' if user_access_level == '2' or user_access_level == 'operations' else
          'readonly_group' if user_access_level == '3' or user_access_level == 'readonly' else
          'invalid'
        }}"
        
    - name: Fail if invalid access level
      fail:
        msg: "Invalid access level. Please choose 1, 2, or 3"
      when: user_access_group == 'invalid'
      
    - name: Convert ssh key choice to boolean
      set_fact:
        copy_ssh_key: "{{ copy_ssh_key | lower == 'yes' or copy_ssh_key | lower == 'y' }}"

  roles:
    - user-management

  post_tasks:
    - name: Display user creation summary
      debug:
        msg: |
          🎉 User created successfully!
          👤 Username: {{ new_username }}
          🔐 Access Level: {{ user_access_group }}
          🔑 SSH Access: {{ 'Enabled' if copy_ssh_key else 'Disabled' }}
          🔗 Login: ssh {{ new_username }}@{{ ansible_host }}
EOF

# Create fix-ruby playbook
echo "📝 Creating fix-ruby playbook..."
cat > ansible/playbooks/fix-ruby.yml << 'EOF'
---
- name: Fix Ruby and Bundler Installation
  hosts: webservers
  become: yes
  
  tasks:
    - name: Fix rbenv paths and install bundler
      shell: |
        export PATH="/home/{{ deploy_user }}/.rbenv/bin:$PATH"
        eval "$(rbenv init -)"
        
        # Ensure Ruby is properly installed
        if rbenv versions | grep -q {{ ruby_version }}; then
          rbenv global {{ ruby_version }}
          rbenv rehash
          
          # Install bundler using full path
          /home/{{ deploy_user }}/.rbenv/versions/{{ ruby_version }}/bin/gem install bundler -v {{ bundler_version }}
          rbenv rehash
          
          echo "✅ Ruby and Bundler fixed successfully"
        else
          echo "❌ Ruby {{ ruby_version }} not found"
          exit 1
        fi
      become_user: "{{ deploy_user }}"
      
    - name: Test bundle command
      shell: |
        export PATH="/home/{{ deploy_user }}/.rbenv/bin:$PATH"
        eval "$(rbenv init -)"
        rbenv rehash
        bundle --version
      become_user: "{{ deploy_user }}"
      register: bundle_test
      
    - name: Display bundle version
      debug:
        msg: "Bundle version: {{ bundle_test.stdout }}"
        
    - name: Update bashrc with correct paths
      lineinfile:
        path: "/home/{{ deploy_user }}/.bashrc"
        line: "{{ item }}"
        state: present
      loop:
        - 'export PATH="$HOME/.rbenv/bin:$PATH"'
        - 'eval "$(rbenv init -)"'
        - 'export PATH="$HOME/.rbenv/shims:$PATH"'
EOF

# Add to .gitignore
echo "📝 Updating .gitignore..."
cat >> .gitignore << 'EOF'

# Ansible
ansible/extra_vars.yml
ansible/user_vars.yml
*.retry
EOF

echo ""
echo "🎉 Ansible setup completed successfully!"
echo ""
echo "📋 What was created:"
echo "✅ Complete Ansible directory structure"
echo "✅ Inventory files for staging and production"
echo "✅ Roles: common, rails-app, user-management"
echo "✅ Playbooks: deploy, setup-server, create-user, fix-ruby"
echo "✅ Configuration files and templates"
echo ""
echo "📝 Next steps:"
echo "1. Update your EC2 IP address in ansible/inventories/staging/hosts"
echo "2. Install Ansible: brew install ansible"
echo "3. Test connectivity: cd ansible && ansible -i inventories/staging/hosts webservers -m ping"
echo "4. Commit to Git: git add ansible/ && git commit -m 'Add Ansible deployment'"
echo "5. Replace your Jenkinsfile.cd with the Ansible version"
echo ""
echo "🚀 Ready to deploy with Ansible!"