#!/bin/bash
set -e

echo "🚀 Starting Flask Dashboard deployment..."

# Check if we're in the right directory
if [ ! -f "terraform/main.tf" ]; then
    echo "❌ Error: terraform/main.tf not found. Please run this script from the project root."
    exit 1
fi

# Step 1: Deploy infrastructure
echo "📋 Step 1: Deploying infrastructure with Terraform..."
cd terraform/
terraform init
terraform plan
terraform apply -auto-approve

# Get the public IP
PUBLIC_IP=$(terraform output -raw elastic_ip)
echo "✅ Instance deployed with IP: $PUBLIC_IP"

# Step 2: Wait for instance to be ready
echo "⏳ Step 2: Waiting for instance to be ready..."
sleep 60

# Step 3: Update Ansible inventory
echo "📝 Step 3: Updating Ansible inventory..."
cd ../ansible/
sed -i.bak "s/ansible_host=REPLACE_WITH_IP/ansible_host=$PUBLIC_IP/" inventory.ini

# Step 4: Test SSH connectivity
echo "🔐 Step 4: Testing SSH connectivity..."
max_attempts=12
attempt=1
while [ $attempt -le $max_attempts ]; do
    echo "Attempt $attempt/$max_attempts: Testing SSH connection..."
    if ssh -i /Users/anu/.ssh/tom.pem -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP "echo 'SSH connection successful'"; then
        echo "✅ SSH connection established!"
        break
    else
        if [ $attempt -eq $max_attempts ]; then
            echo "❌ Failed to establish SSH connection after $max_attempts attempts"
            exit 1
        fi
        echo "⏳ SSH not ready yet, waiting 30 seconds..."
        sleep 30
        ((attempt++))
    fi
done

# Step 5: Run Ansible playbook
echo "⚙️  Step 5: Configuring instance with Ansible..."
ansible-playbook -i inventory.ini playbook.yml

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📊 Access your Flask dashboard at:"
echo "   ➤ http://$PUBLIC_IP"
echo "   ➤ http://$PUBLIC_IP:5000 (direct Flask)"
echo "   ➤ http://$PUBLIC_IP/health (health check)"
echo ""
echo "🔐 SSH into your server:"
echo "   ➤ ssh -i /Users/anu/.ssh/tom.pem ubuntu@$PUBLIC_IP"
echo ""
echo "📋 Monitor logs:"
echo "   ➤ sudo tail -f /var/log/flask-dashboard.log"
echo "   ➤ sudo supervisorctl status flask-dashboard"
echo "   ➤ sudo systemctl status nginx"
echo ""