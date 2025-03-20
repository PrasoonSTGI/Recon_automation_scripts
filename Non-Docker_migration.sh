# The script is intended to run on a non-Docker platform, ensuring the PostgreSQL database is backed up locally before the migration.
# 
# Make sure to have access to the PostgreSQL database and required user permissions for pg_dump.
# This script assumes that the PostgreSQL service is running on localhost with the default port 5432.
#
# This script should be executed on a non-Docker platform.

#!/bin/bash

db_username=""
db_name=""
db_password="" 
db_host="localhost"
db_port="5432" 

# Function to print an error message and exit
handle_error() {
    echo "$1"
    exit 1
}

# Log messages with timestamps
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to sleep for a few seconds (to allow time for processes to settle)
sleep_after_command() {
    sleep 4  # Sleep for 4 seconds (you can adjust the duration)
}

# Function to prompt user for database credentials
prerequisite_db_credentials() {
    echo -e "\e[33mDatabase Credentials \e[0m"
    echo -e "\e[34m################################################################################################################################################### \e[0m"

    echo -e "\e[36mEnter DB username: \e[0m"
    read db_username

    echo -e "\e[36mEnter DB name: \e[0m"
    read db_name

    echo -e "\e[36mEnter DB password: \e[0m"
    read db_password
    echo  

    echo -e "\e[34m################################################################################################################################################### \e[0m"
}

# Function to handle database backup
perform_db_backup() {
    # Ask for user directory
    echo -e "\e[36mEnter the user directory (default: stgwe): \e[0m"
    read user_dir
    user_dir=${user_dir:-stgwe} 

    # Check if the provided user directory exists
    if [ ! -d "/home/$user_dir" ]; then
        handle_error "Error: The specified directory /home/$user_dir does not exist."
    fi

    # Define the backup directory path
    local backup_dir="/home/$user_dir/archive/DB_Backups"
    

    # Construct the dump file name with the current date
    local date=$(date '+%Y-%m-%d_%H-%M-%S')  # Avoid spaces in filename
    local dump_file="$backup_dir/CurrProd_DB_Backup_$date.dump"

    # Run the pg_dump command to create the backup
    echo "Creating database backup..."
    pg_dump -d "$db_name" -h localhost -p 5432 -U "$db_username" -Fc > "$dump_file"

    # Check if the pg_dump command was successful
    if [ $? -eq 0 ]; then
        echo "Database backup created successfully: $dump_file"
    else
        handle_error "Error: Failed to create database backup."
    fi
}

echo -e "\e[34m################################################################################################################################################### \e[0m"
echo -e "\e[33mSCRIPT STARTED.... \e[0m" 
echo -e "\e[34m################################################################################################################################################### \e[0m"

prerequisite_db_credentials

# Perform database backup
perform_db_backup

echo -e "\e[34m################################################################################################################################################### \e[0m"
echo -e "\e[32mScript completed successfully!!! \e[0m"

# Guide the user about the next steps:
echo -e "\e[33mNext Steps:\e[0m"
echo -e "\e[36m1. The database dump file has been created successfully: $dump_file.\e[0m"
echo -e "\e[36m2. Please transfer this dump file to the new production server (Docker platform).\e[0m"
echo -e "\e[36m3. After transferring, fetch the 'Dockerized_migration.sh' script from the 'Recon_automation_scripts' repository on the production server.\e[0m"
echo -e "\e[36m4. Execute the 'Dockerized_migration.sh' script to complete the database migration from the non-Docker platform to the Docker platform.\e[0m"
echo -e "\e[34m################################################################################################################################################### \e[0m"
