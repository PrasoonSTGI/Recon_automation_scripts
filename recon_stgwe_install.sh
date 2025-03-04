#!/bin/bash

# Log function for printing messages with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Exit function for handling errors and stopping further execution
exit_on_error() {
    log_message "$1"
    exit 1
}

# Function to check the success or failure of the last command
check_command_status() {
    if [ $? -ne 0 ]; then
        log_message "$1 failed. Exiting script."
        exit 1
    else
        log_message "$1 succeeded."
    fi
}

# Sleep function for waiting
sleep_after_command() {
    sleep 4  # sleep for 4 seconds
}

# Prompt for user confirmation (y/N) with color
prompt_user() {
    # ANSI escape code for cyan text color
    echo -e "\e[36m$1 (y/N): \e[0m"  
    read confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_message "User chose not to proceed. Exiting script."
        exit 1
    fi
}

# Check if yum is available
log_message "Checking if yum is installed..."
if ! command -v yum &> /dev/null; then
    log_message "yum package manager not found."
    log_message "Attempting to install yum..."
    sudo dnf install -y yum  # Using dnf (for RHEL/CentOS 8 and later) to install yum
    check_command_status "Installing yum"
else
    log_message "yum is already installed."
fi

# Step 1: Check if Docker is installed
log_message "Checking if Docker is installed..."
if command -v docker &> /dev/null; then
    log_message "Docker is already installed."
else
    log_message "Installing Docker..."
    
    # Add Docker repository
    sleep_after_command
    sudo yum config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
    check_command_status "Adding Docker repository"
    
    # Step 2: Install Docker
    log_message "Installing Docker..."
    log_message "###################################################################################################################################################"
    sleep_after_command
    sudo yum install -y docker-ce docker-ce-cli docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras containerd
    check_command_status "Docker installation"
fi
log_message "###################################################################################################################################################"
# Ask user if they want to proceed with Docker service
prompt_user "Do you want to proceed with starting and enabling the Docker service?"

# Step 3: Configure Docker service to autostart
log_message "Starting Docker service..."
sudo systemctl start docker
check_command_status "Starting Docker service"

log_message "Enabling Docker service to start on boot..."
sudo systemctl enable docker
check_command_status "Enabling Docker service on boot"
sleep_after_command

# Ask user if they want to proceed with user and group creation
prompt_user "Do you want to proceed with creating a user and group?"

# Step 4: Standardize group name and user name (no input from user)
group_name="docker"
user_name="stgwe"

log_message "Checking if group '$group_name' exists..."
getent group "$group_name" &> /dev/null
if [ $? -eq 0 ]; then
    log_message "Group '$group_name' already exists."
else
    log_message "Creating group '$group_name'..."
    sudo groupadd "$group_name"
    check_command_status "Creating group '$group_name'"
fi
sleep_after_command

# Step 5: Create user (with fixed user name)
log_message "Checking if user '$user_name' exists..."
id "$user_name" &> /dev/null
if [ $? -eq 0 ]; then
    log_message "User '$user_name' already exists."
else
    log_message "Creating user '$user_name'..."
    sudo useradd "$user_name"
    check_command_status "Creating user '$user_name'"
fi
sleep_after_command

# Step 6: Check if the user is already in the group
log_message "Checking if user '$user_name' is already in group '$group_name'..."
if id "$user_name" | grep -q "$group_name"; then
    log_message "User '$user_name' is already a member of group '$group_name'."
else
    log_message "Adding user '$user_name' to group '$group_name'..."
    sudo usermod -aG "$group_name" "$user_name"
    check_command_status "Adding user '$user_name' to group '$group_name'"
fi

log_message "###################################################################################################################################################"
sleep_after_command

# Step 7: Clone the GitHub repository containing the shell script or use existing repo
log_message "Checking if the Recon Automation scripts repository already exists..."

repo_url="https://github.com/PrasoonSTGI/Recon_automation_scripts.git"
original_user_home=$(eval echo ~$USER)
clone_dir="$original_user_home/Recon_automation_scripts"

# Check if the repository already exists
if [ -d "$clone_dir" ]; then
    log_message "Repository already exists. Skipping clone."
else
    log_message "Please enter your GitHub credentials to clone the repository."

    # Prompt for GitHub username and Personal Access Token (PAT)
    echo -e "\e[36mGitHub Username: \e[0m"
    read github_username

    echo -e "\e[36mGitHub Personal Access Token: \e[0m"
    read -s github_token  # -s hides the input for the token (for security)

    # Create the GitHub URL with the username and token
    repo_url="https://$github_username:$github_token@github.com/PrasoonSTGI/Recon_automation_scripts.git"

    log_message "Cloning the repository containing 'recon_stgwe_filemover.sh'..."
    git clone "$repo_url" "$clone_dir"
    check_command_status "Cloning the GitHub repository"
fi

# Step 8: Move the script to the current user's home directory, make it executable, and copy to the new user
script_name="recon_stgwe_filemover.sh"
script_path="$clone_dir/$script_name"

# Check if the script exists in the cloned repository
if [ -f "$script_path" ]; then
    log_message "Moving '$script_name' to the current user's home directory..."
    
    # Move the script to the current user's home directory
    cp "$script_path" "$original_user_home/$script_name"
    
    # Make the script executable
    chmod +x "$original_user_home/$script_name"
    check_command_status "Making script executable"
    
    log_message "Copying '$script_name' to the user '$user_name' directory..."
    # Copy the script to the new user's directory
    sudo cp "$original_user_home/$script_name" "/home/$user_name/$script_name"
    sudo chown "$user_name:$user_name" "/home/$user_name/$script_name"
    check_command_status "Copying script to '$user_name'"
else
    exit_on_error "Script '$script_name' not found in the repository."
fi
log_message "###################################################################################################################################################"
sleep_after_command

# Step 9: Switching user at the end with the new log message
log_message "Docker installation, user addition, and script copying are completed successfully!"
log_message "Now switching from user '$(whoami)' to user '$user_name'..."
sudo su - "$user_name"
