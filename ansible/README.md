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
