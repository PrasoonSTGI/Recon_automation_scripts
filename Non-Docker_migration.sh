#put a pre test in the start explaing what ius script about and also menmtion its should run on current non docker platform
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

# Function to check the status of a command
# check_command_status() {
#     if [ $? -ne 0 ]; then
#         log_message "$1 failed. Exiting script."
#         exit 1
#     else
#         log_message "$1 succeeded."
#     fi
# }

# Function to validate DB credentials
validate_db_credentials() {
    local db_username=$1
    local db_password=$2
    local db_name=$3
    local db_host="localhost"
    local db_port="5432"

    # Validate DB credentials using psql command
    PGPASSWORD=$db_password psql -h "$db_host" -U "$db_username" -d "$db_name" -p "$db_port" -c "\q" &>/dev/null
    return $?  # Return the status of the psql command
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

# Function to authenticate DB credentials
authenticate_db() {
    prerequisite_db_credentials
    log_message "DB credentials provided. Validating..."

    local attempts=3
    while [[ $attempts -gt 0 ]]; do
        validate_db_credentials "$db_username" "$db_password" "$db_name"
        if [ $? -eq 0 ]; then
            echo -e "\e[32mDB Credentials Verified \e[0m"
            log_message "DB connection successful."
            return 0
        else
            echo -e "\e[31mWrong Credentials!!!! \e[0m"
            ((attempts--))
            log_message "DB connection failed. $attempts attempt(s) remaining."
            if [[ $attempts -eq 0 ]]; then
                log_message "Failed to authenticate DB credentials after 3 attempts. Exiting script."
                exit 1
            fi
            echo -e "\e[36mPlease re-enter DB credentials.\e[0m"
            prerequisite_db_credentials  # Prompt user to input DB credentials again
        fi
    done
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

    # Construct the dump file name with the current date
    local date=$(date "+%Y%m%d") #add time stamp also
    local dump_file="/home/$user_dir/archive/DB_Backup/CurrProd_DB_Backup_$date.dump"

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

# Authenticate DB credentials before proceeding
authenticate_db### not required
#echo -e "\e[34m################################################################################################################################################### \e[0m"
# Perform database backup
perform_db_backup
echo -e "\e[34m################################################################################################################################################### \e[0m"
echo -e "\e[32mScript completed successfully!!! \e[0m"

