#!/bin/bash

DB_PORT_MAPPING="15432:5432"
DB_PORT_1=15432 

# Variables initialized 
db_username=""
db_name=""
db_password=""
github_username=""
github_token=""

# Log function for printing messages with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$1" >> InstallationStage.txt  # Log to track file
}

# Function to sleep for a few seconds (to allow time for processes to settle)
sleep_after_command() {
    sleep 4  # Sleep for 4 seconds (you can adjust the duration)
}

# Exit function for handling errors and stopping further execution
exit_on_error() {
    log_message "$1"
    exit 1
}

# Function to check the status of a command
check_command_status() {
    if [ $? -ne 0 ]; then
        log_message "$1 failed. Exiting script."
        exit 1
    else
        log_message "$1 succeeded."
    fi
}

# Function to prompt the user with a colored message (Cyan color)
prompt_user() {
    echo -e "\e[36m$1 (y/N): \e[0m"  # Cyan color prompt
    read confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_message "User chose not to proceed. Exiting script."
        exit 1
    fi
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

# Function to authenticate GitHub credentials
authenticate_github() {
    log_message "Authenticating GitHub credentials..."
    local attempts=3  # Maximum attempts
    while [[ $attempts -gt 0 ]]; do
        validate_github_credentials "$github_username" "$github_token"
        if [ $? -eq 0 ]; then
            log_message "GitHub authentication successful."
            return 0  # Successful authentication
        else
            log_message "GitHub authentication failed. $attempts attempt(s) remaining."
            ((attempts--))
            if [[ $attempts -eq 0 ]]; then
                log_message "Failed to authenticate GitHub credentials after 3 attempts. Exiting script."
                exit 1  # Exit after 3 failed attempts
            fi
            echo -e "\e[36mPlease re-enter GitHub credentials.\e[0m"
            prerequisite_github_credential  # This will prompt the user to input GitHub username and token again
        fi
    done
}

# Function to prompt user for GitHub credentials
prerequisite_github_credential() {
    echo -e "\e[33mGitHub Credentials \e[0m"
    echo -e "\e[34m################################################################################################################################################### \e[0m"
    # Prompt the user for GitHub credentials
    echo -e "\e[36mEnter GitHub username: \e[0m"
    read github_username

    echo -e "\e[36mEnter GitHub Personal Access Token (PAT): \e[0m"
    read github_token
    echo  

    # Authenticate GitHub
    authenticate_github

    # Store the credentials in the input_creds.txt file for future use (overwrite every time)
    echo "github_username=$github_username" > input_creds.txt
    echo "github_token=$github_token" >> input_creds.txt
}

# Function to validate DB credentials
validate_db_credentials() {
    local username=$1
    local password=$2
    local dbname=$3
    # Check DB credentials using PostgreSQL client
    docker run --rm --network host -v /home/$USER:/home/$USER --env-file /home/$USER/.env-pdi postgres psql --port 15432 --host localhost --username "$username" --dbname "$dbname" -c "\q"
    return $?
}

# Function to authenticate DB credentials
authenticate_db() {
    log_message "Validating DB credentials..."
    local attempts=3
    while [[ $attempts -gt 0 ]]; do
        validate_db_credentials "$db_username" "$db_password" "$db_name"
        if [ $? -eq 0 ]; then
            log_message "DB connection successful."
            return 0
        else
            log_message "DB connection failed. $attempts attempt(s) remaining."
            ((attempts--))
            if [[ $attempts -eq 0 ]]; then
                log_message "Failed to authenticate DB credentials after 3 attempts. Exiting script."
                exit 1
            fi
            echo -e "\e[36mPlease re-enter DB credentials.\e[0m"
            prerequisite_db_credential  # This will prompt the user to input DB credentials again
        fi
    done
}

# Function to prompt user for database credentials
prerequisite_db_credential() {
    echo -e "\e[33mDatabase Credentials \e[0m"
    echo -e "\e[34m################################################################################################################################################### \e[0m"
    # Prompt the user for database credentials
    echo -e "\e[36mEnter DB username: \e[0m"
    read db_username

    echo -e "\e[36mEnter DB name: \e[0m"
    read db_name

    echo -e "\e[36mEnter DB password: \e[0m"
    read db_password
    echo  

    # Store the credentials in the input_creds.txt file for future use (overwrite every time)
    echo "db_username=$db_username" > input_creds.txt
    echo "db_name=$db_name" >> input_creds.txt
    echo "db_password=$db_password" >> input_creds.txt
}

# Recheck prerequisites at the start of the script
recheck_prerequisites() {
    # Check if the user has repo access and GitHub credentials ready
    prompt_user "Do you have access to the git repository (recon-stgwe-documentation)?"

    prompt_user "Do you have your GitHub credentials (username & GitHub PAT) ready?"
}

# Function to check prerequisites for running the script
recheck_prerequisites

docker ps | grep -q "filemover-db"
if [ $? -eq 0 ]; then
    authenticate_db
else
    # If the container is not running, prompt for DB credentials
    prerequisite_db_credential
fi
prerequisite_github_credential
echo -e "\e[34m################################################################################################################################################### \e[0m"
# Now proceed with the rest of the script...
# Step 1: Test Docker installation by running hello-world image
echo -e "\e[33mValidating Docker installation with hello-world image... \e[0m" 
docker run hello-world
check_command_status "Docker hello-world test"

# --> Prompt if user wants to continue (y/N)
prompt_user "Do you want to continue?"
# Step 2: Pull PostgreSQL image and run the container with user inputs
echo -e "\e[33mDeploying PostgreSQL container  \e[0m" 
log_message 'Checking if PostgreSQL container "filemover-db" is already running...'

# Check if the PostgreSQL container is already running
docker ps | grep -q "filemover-db"
if [ $? -eq 0 ]; then
    log_message "PostgreSQL container 'filemover-db' is already running. Skipping the PostgreSQL container creation."
else
    # Use the credentials provided earlier
    log_message 'Pulling and running PostgreSQL container...'
    docker run --name filemover-db -e POSTGRES_DB="$db_name" -e POSTGRES_USER="$db_username" -e POSTGRES_PASSWORD="$db_password" -p $DB_PORT_MAPPING -d postgres
    check_command_status 'Deploying PostgreSQL container'
fi
echo -e "\e[34m################################################################################################################################################### \e[0m"
sleep_after_command

# Step 3: Verify Docker images and containers
echo -e "\e[33mListing Docker images and running containers...  \e[0m" 
docker images
docker ps
echo -e "\e[34m################################################################################################################################################### \e[0m"
sleep_after_command

# Step 5: Clone the repository
log_message "Cloning repository..."
if [ ! -d "recon-stgwe-documentation" ]; then
    log_message "Cloning repository using GitHub credentials..."

    # Use GitHub username and token for cloning
    git clone https://$github_username:$github_token@github.com/thesummitgrp/recon-stgwe-documentation.git
    check_command_status "Repository cloned"
else
    log_message "Repository 'recon-stgwe-documentation' already exists. Skipping cloning."
fi
echo -e "\e[34m################################################################################################################################################### \e[0m"
sleep_after_command

# Continue the rest of the script...
# The rest of the steps will be similar and have been omitted for brevity, but they would continue from here as in your original script.

