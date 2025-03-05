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

# Function to check prerequisites for running the script
check_prerequisites() {
    prompt_user "Do you have access to the git repository (Recon_automation_scripts)?"
    prompt_user "Do you have your GitHub credentials (username & GitHub PAT) ready?"
}

# Function to validate GitHub credentials
validate_github_credentials() {
    local username=$1
    local token=$2
    # Make an API call to GitHub to validate credentials
    response=$(curl -s -o /dev/null -w "%{http_code}" -u "$username:$token" https://api.github.com/user)
    if [ "$response" -eq 200 ]; then
        return 0  # Credentials are valid
    else
        return 1  # Invalid credentials
    fi
}

# Start the process
check_prerequisites

echo -e "\e[34m################################################################################################################################################### \e[0m"
echo -e "\e[33mGETTING STARTED WITH THE SCRIPT \e[0m"
echo -e "\e[34m################################################################################################################################################### \e[0m"
sleep_after_command

# Prompt for GitHub credentials
attempts=0
max_attempts=3

while true; do
    echo -e "\e[36mGitHub Username: \e[0m"
    read github_username

    echo -e "\e[36mGitHub Personal Access Token: \e[0m"
    read -s github_token  # -s hides the input for the token (for security)

    # Validate the credentials by calling GitHub API
    if validate_github_credentials "$github_username" "$github_token"; then
        log_message "GitHub credentials validated successfully."
        break  # Exit the loop if credentials are valid
    else
        ((attempts++))
        log_message "Invalid GitHub credentials. Attempt $attempts of $max_attempts."
        if [ "$attempts" -ge "$max_attempts" ]; then
            exit_on_error "Credentials are wrong. Please try again later."
        fi
    fi
done

# Set up the repository URL with credentials
repo_url="https://$github_username:$github_token@github.com/PrasoonSTGI/Recon_automation_scripts.git"
log_message "Cloning the repository from GitHub..."

# Clone the repository
original_user_home=$(eval echo ~$USER)
clone_dir="$original_user_home/Recon_automation_scripts"

if [ -d "$clone_dir" ]; then
    log_message "Repository already exists. Skipping clone."
else
    git clone "$repo_url" "$clone_dir"
    check_command_status "Cloning the GitHub repository"
fi

echo -e "\e[34m################################################################################################################################################### \e[0m"
sleep_after_command

# Move to the cloned repo folder
cd "$clone_dir" || exit_on_error "Failed to navigate to the cloned repo directory."

# Check if the script 'recon_stgwe_install.sh' exists in the repository
script_name="recon_stgwe_install.sh"
script_path="$clone_dir/$script_name"

if [ -f "$script_path" ]; then
    log_message "Found '$script_name' in the repository. Proceeding with copying it to home directory..."
    
    # Copy the script to the current user's home directory
    cp "$script_path" "$original_user_home/$script_name"
    
    # Make the script executable
    chmod +x "$original_user_home/$script_name"
    check_command_status "Making script executable"

else
    exit_on_error "Script '$script_name' not found in the repository."
fi

echo -e "\e[34m################################################################################################################################################### \e[0m"
sleep_after_command

# Prompt user for confirmation before executing the script
prompt_user "Do you want to execute the script '$script_name' now?"

# Execute the script
log_message "Executing '$script_name'..."
$original_user_home/$script_name
check_command_status "Executing the script"

log_message "Script execution completed successfully!"
echo -e "\e[34m################################################################################################################################################### \e[0m"
