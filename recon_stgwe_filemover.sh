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

    # Validate GitHub credentials with limited attempts
    attempts=0
    max_attempts=3

    while true; do
        # Validate the credentials by calling GitHub API
        if validate_github_credentials "$github_username" "$github_token"; then
            echo -e "\e[32mGitHub credentials validated successfully.\e[0m"
            break  # Exit the loop if credentials are valid
        else
            ((attempts++))
            echo -e "\e[31mWrong Credentials!!!!! \e[0m"
            log_message "Invalid GitHub credentials. Attempt $attempts of $max_attempts."
            if [ "$attempts" -ge "$max_attempts" ]; then
                exit_on_error "Failed to authenticate GitHub credentials after $max_attempts attempts. Please try again later."
            fi
            # If credentials are invalid, prompt user again
            echo -e "\e[36mPlease re-enter your GitHub credentials.\e[0m"
            echo -e "\e[36mGitHub Username: \e[0m"
            read github_username

            echo -e "\e[36mGitHub Personal Access Token: \e[0m"
            read github_token
        fi
    done

    # Store the credentials in the input_creds.txt file for future use (overwrite every time)
    echo "github_username=$github_username" > GitHub_input_creds.txt
    echo "github_token=$github_token" >> GitHub_input_creds.txt
}

# Function to validate DB credentials
validate_db_credentials() {
    local username=$1
    local password=$2
    local dbname=$3
    sed -i "s/^PGPASSWORD=[^ ]*/PGPASSWORD=$password/" .env-pdi
    # Check DB credentials using PostgreSQL client
    docker run --rm --network host -v /home/$USER:/home/$USER --env-file /home/$USER/.env-pdi postgres psql --port 15432 --host localhost --username "$username" --dbname "$dbname" -c "\q"
    return $?
}

# Function to authenticate DB credentials
authenticate_db() {
    prerequisite_db_credential
    log_message "DB is already present Validating DB credentials..."
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
    echo "db_username=$db_username" > DB_input_creds.txt
    echo "db_name=$db_name" >> DB_input_creds.txt
    echo "db_password=$db_password" >> DB_input_creds.txt
}

# Function to prompt for user decision to continue
prompt_user() {
    # ANSI escape code for cyan text color
    echo -e "\e[36m$1 (y/N): \e[0m"  
    read confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_message "User chose not to proceed. Exiting script."
        exit 1
    fi
}

# Recheck prerequisites at the start of the script
recheck_prerequisites() {
    # Check if the user has repo access and GitHub credentials ready
    prompt_user "Do you have access to the git repository (recon-stgwe-documentation)?"
    prompt_user "Do you have your GitHub credentials (username & GitHub PAT) ready?"
}

# Main Script Execution

# Check prerequisites
recheck_prerequisites

# Validate GitHub credentials
prerequisite_github_credential

# Check if the user is running the DB container
docker ps | grep -q "filemover-db"
if [ $? -eq 0 ]; then
    authenticate_db  # If the DB container is running, authenticate DB credentials
else
    # If the container is not running, prompt for DB credentials
    prerequisite_db_credential
fi
echo -e "\e[34m################################################################################################################################################### \e[0m"
echo -e "\e[33mGETTING STARTED WITH THE SCRIPT \e[0m" 
echo -e "\e[34m################################################################################################################################################### \e[0m"
sleep_after_command
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

# Step 6: Navigate to the home directory and copy env-pdi file
cd ~ || exit_on_error "Failed to navigate to home directory."
log_message "Creating /home/stgwe/.env-pdi file. This file will be used for database connection......"
if [ ! -f /home/$USER/recon-stgwe-documentation/db-init/env-pdi ]; then
    exit_on_error "env-pdi file not found. Exiting script."
else
    cp /home/$USER/recon-stgwe-documentation/db-init/env-pdi .env-pdi
    #check_command_status "Copying env-pdi file"
fi
sleep_after_command

# Step 7: Update values inside .env-pdi file
#log_message "Updating values inside .env-pdi file..."
P_STGWE_UID=$(id -u)  # Get user ID
P_STGWE_GID=$(id -g)  # Get group ID
PGPASSWORD=$db_password
DB_PASSWORD_1=$db_password
DB_USERNAME_1=$db_username
DB_NAME_1=$db_name
DB_PORT_1=15432

sed -i "s/^P_STGWE_UID=[^ ]*/P_STGWE_UID=$P_STGWE_UID/" .env-pdi
sed -i "s/^P_STGWE_GID=[^ ]*/P_STGWE_GID=$P_STGWE_GID/" .env-pdi
sed -i "s/^PGPASSWORD=[^ ]*/PGPASSWORD=$PGPASSWORD/" .env-pdi
sed -i "s/^DB_PORT_1=[^ ]*/DB_PORT_1=$DB_PORT_1/" .env-pdi
sed -i "s/^DB_PASSWORD_1=[^ ]*/DB_PASSWORD_1=$DB_PASSWORD_1/" .env-pdi
sed -i "s/^DB_USERNAME_1=[^ ]*/DB_USERNAME_1=$DB_USERNAME_1/" .env-pdi
sed -i "s/^DB_NAME_1=[^ ]*/DB_NAME_1=$DB_NAME_1/" .env-pdi
#check_command_status "Updating .env-pdi file"
echo -e "\e[34m################################################################################################################################################### \e[0m"
# Step 8: Test the DB connection
echo -e "\e[33mDatabase connection establishment  \e[0m" 
log_message "Testing DB connection using .env-pdi file ..."
echo -e "\e[31mEnter \q to exit the db connection prompt \e[0m"
docker run -it --rm --network host -v /home/$USER:/home/$USER --env-file /home/$USER/.env-pdi postgres psql --port $DB_PORT_1 --host localhost --username $db_username --dbname $db_name
check_command_status "DB connection test"
echo -e "\e[34m################################################################################################################################################### \e[0m"
sleep_after_command

# Step 9: Create or update database_sql_new.sh file and execute it
log_message "Checking if database_sql_new.sh exists..."
if [ ! -f /home/$USER/database_sql_new.sh ]; then
    log_message "database_sql_new.sh not found. Creating database_sql_new.sh file. It will be executed to create the database objects"
    cat << 'EOF' > /home/$USER/database_sql_new.sh
#!/bin/bash
for FILE in $(ls -a /home/stgwe/*/*/*/*.sql); do
    docker run --rm --network host -v /home/stgwe:/home/stgwe --env-file /home/stgwe/.env-pdi postgres psql --port 15432 --host localhost --username summit --dbname summit -f $FILE >> /home/$USER/sql_execution_logs.txt 2>&1
done
EOF
    check_command_status "Creating database_sql_new.sh"
    chmod +x /home/$USER/database_sql_new.sh
    check_command_status "Making database_sql_new.sh executable"
else
    log_message "database_sql_new.sh already exists. Skipping creation."
fi

echo -e "\e[34m################################################################################################################################################### \e[0m"
prompt_user "Do you want to continue and execute the database_sql_new.sh file?"
# Now execute the database_sql_new.sh file
log_message "Executing database_sql_new.sh..."
/home/$USER/database_sql_new.sh
check_command_status "database_sql_new.sh execution"
echo -e "\e[34m################################################################################################################################################### \e[0m"
sleep_after_command

# Step 10: Execute SQL commands (run after tables are created)
log_message "Running Update and Alter SQL commands to bring up the DB is shape ...."
{
  docker run -it --rm --network host -v /home/$USER:/home/$USER --env-file /home/$USER/.env-pdi postgres psql --port $DB_PORT_1 --host localhost --username $db_username --dbname $db_name -c "alter table fm_job add column parent_schema text;" 
  docker run -it --rm --network host -v /home/$USER:/home/$USER --env-file /home/$USER/.env-pdi postgres psql --port $DB_PORT_1 --host localhost --username $db_username --dbname $db_name -c "alter table fm_job_event add column build_info text;"
  docker run -it --rm --network host -v /home/$USER:/home/$USER --env-file /home/$USER/.env-pdi postgres psql --port $DB_PORT_1 --host localhost --username $db_username --dbname $db_name -c "alter table fm_job_event add column initiator_id text;"
  docker run -it --rm --network host -v /home/$USER:/home/$USER --env-file /home/$USER/.env-pdi postgres psql --port $DB_PORT_1 --host localhost --username $db_username --dbname $db_name -c "update fm_job set precondition_sql = null where name='HELLO_WORLD';"
  docker run -it --rm --network host -v /home/$USER:/home/$USER --env-file /home/$USER/.env-pdi postgres psql --port $DB_PORT_1 --host localhost --username $db_username --dbname $db_name -c "update fm_action set precondition_override='BAD' where id=2;"
  docker run -it --rm --network host -v /home/$USER:/home/$USER --env-file /home/$USER/.env-pdi postgres psql --port $DB_PORT_1 --host localhost --username $db_username --dbname $db_name -c "update fm_action set precondition_override='BAD', precondition_sql='select ''BAD''' where id=2;"
  docker run -it --rm --network host -v /home/$USER:/home/$USER --env-file /home/$USER/.env-pdi postgres psql --port $DB_PORT_1 --host localhost --username $db_username --dbname $db_name -c "ALTER TABLE fm_action ADD COLUMN IF NOT EXISTS is_error_handler boolean NOT NULL DEFAULT FALSE;"
  docker run -it --rm --network host -v /home/$USER:/home/$USER --env-file /home/$USER/.env-pdi postgres psql --port $DB_PORT_1 --host localhost --username $db_username --dbname $db_name -c "ALTER TABLE fm_action ADD COLUMN IF NOT EXISTS precondition_env jsonb;"
  docker run -it --rm --network host -v /home/$USER:/home/$USER --env-file /home/$USER/.env-pdi postgres psql --port $DB_PORT_1 --host localhost --username $db_username --dbname $db_name -c "ALTER TABLE fm_action ADD COLUMN IF NOT EXISTS precondition_override text;"
  docker run -it --rm --network host -v /home/$USER:/home/$USER --env-file /home/$USER/.env-pdi postgres psql --port $DB_PORT_1 --host localhost --username $db_username --dbname $db_name -c "ALTER TABLE fm_job_action_event ADD COLUMN IF NOT EXISTS resolved_action_parms text;"
  docker run -it --rm --network host -v /home/$USER:/home/$USER --env-file /home/$USER/.env-pdi postgres psql --port $DB_PORT_1 --host localhost --username $db_username --dbname $db_name -c "ALTER TABLE fm_job_action_event ADD COLUMN IF NOT EXISTS end_tms timestamp without time zone;"
} >> /home/$USER/sql_execution_logs.txt 2>&1
check_command_status "Running SQL commands on DB"

echo -e "\e[34m################################################################################################################################################### \e[0m"
sleep_after_command

# Now prompt the user to check the logs
log_message "Object creation logs are captured in (sql_execution_logs.txt). Please check the logs and fix any errors if any."
prompt_user "Do you want to proceed after checking and fixing any issues?"


# Step 11: Setting up the Recon client
echo -e "\e[34m################################################################################################################################################### \e[0m"
echo -e "\e[33mSetting up Recon client...  \e[0m" 
cd /home/$USER
mkdir -p etl/output etl/archive pentaho/data-integration/lib pentaho/repository
log_message "Created Recon client directory structure."
echo -e "\e[34m################################################################################################################################################### \e[0m"
# Step 15: Copy Dockerfile for Recon client
sleep_after_command
echo -e "\e[33mDockerfile creation....., which will be used to build the filemover application image  \e[0m" 
cp /home/$USER/recon-stgwe-documentation/Dockerfile /home/$USER
#check_command_status "Copying Dockerfile"
echo -e "\e[34m################################################################################################################################################### \e[0m"
sleep_after_command

# Step 16: Build Docker image
echo -e "\e[33mSETTING UP FILEMOVER  \e[0m" 
log_message "Building Filemover Docker image..."
echo $github_token | docker login ghcr.io -u $github_username --password-stdin
check_command_status "Docker Login"

log_message "Updating Dockerfile content..."

# Take input for the new image version
echo -e "\e[36mEnter the latest filemover image version (e.g., 3810569831.69): \e[0m"
read IMAGE_VERSION

# Update Dockerfile with the provided version
sed -i "s|FROM ghcr.io/thesummitgrp/stgwe-framework-pdi-filemover:[^ ]*|FROM ghcr.io/thesummitgrp/stgwe-framework-pdi-filemover:$IMAGE_VERSION|" Dockerfile

check_command_status "Dockerfile update with the new image version."
echo -e "\e[34m################################################################################################################################################### \e[0m"
echo -e "\e[33mDisplaying updated Dockerfile content: \e[0m"
cat Dockerfile
echo -e "\e[34m################################################################################################################################################### \e[0m"
prompt_user "Do you want to continue and build the filemover image?"

docker build -t filemover .

check_command_status "Base Filemover image build"
echo -e "\e[34m################################################################################################################################################### \e[0m"
sleep_after_command

# Step 19: Verify the built Docker image
log_message "Verifying built Base Filemover image..."
docker images | grep "filemover"
check_command_status "Base Filemover image verification"

echo -e "\e[34m################################################################################################################################################### \e[0m"
# Step 11: Create db_backups directory if it doesn't exist
echo -e "\e[33mDATABASE BACKUP AND RESTORE \e[0m"
log_message "Checking if db_backups directory exists..."
if [ ! -d /home/$USER/db_backups ]; then
    mkdir /home/$USER/db_backups
    log_message "Created db_backups directory."
else
    log_message "db_backups directory already exists."
fi
sleep_after_command


# Step 12: Take DB backup
log_message "Taking DB backup..."
docker run --rm --network host -v /home/$USER:/home/$USER --env-file /home/$USER/.env-pdi postgres pg_dump -d $db_name -h localhost -p $DB_PORT_1 -U $db_username -w -Fc > /home/$USER/db_backups/db_backup_$(date "+%Y%m%d").dump
check_command_status "DB backup"

sleep_after_command

# Step 13: Remove empty backups
log_message "Removing empty backups..."
if find /home/$USER/db_backups/ -size 0 -print0 | grep -q .; then
    find /home/$USER/db_backups/ -size 0 -print0 | xargs -0 rm
    check_command_status "Removing empty backups"
else
    log_message "No empty backups found. Moving forward."
fi
sleep_after_command

# Step 14: Remove and restart PostgreSQL container and restore backup
log_message "Restoring backup to filemover-db container..."
docker rm --force filemover-db
sleep 5
docker run --name filemover-db -e POSTGRES_DB=$db_name -e POSTGRES_USER=$db_username -e POSTGRES_PASSWORD=$db_password -p $DB_PORT_MAPPING -d postgres
sleep 10
docker run -i --rm --network host -v /home/$USER:/home/$USER --env-file /home/$USER/.env-pdi postgres pg_restore -d $db_name -h localhost -p $DB_PORT_1 -U $db_username -w < $(ls -td /home/$USER/db_backups/* | head -1)
if [ $? -ne 0 ]; then
    exit_on_error "Failed to restore DB from backup. Exiting script."
else
    log_message "DB restore completed successfully."
fi
echo -e "\e[34m################################################################################################################################################### \e[0m"
sleep_after_command

prompt_user "Do you want to run filemover HELLO_WORLD job to test the filemover installation?"
log_message "Running the job using base filemover image..."
docker run --rm --network host -v /home/$USER/etl:/home/$USER/etl --env-file /home/$USER/.env-pdi filemover:latest HELLO_WORLD
check_command_status "Job execution"
echo -e "\e[34m################################################################################################################################################### \e[0m"
# Final step: Prompt to clean up input_creds.txt
echo -e "\e[33mScript execution completed successfully!!! \e[0m"
echo -e "\e[34m################################################################################################################################################### \e[0m"
prompt_user "Do you want to perform file clean-up (remove DB_input_creds.txt & GitHub_input_creds.txt)?"

# If user chooses to delete input_creds.txt
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    log_message "Removing DB_input_creds.txt & GitHub_input_creds.txt..."
    rm -f DB_input_creds.txt
    rm -f GitHub_input_creds.txt
else
    log_message "DB_input_creds.txt & GitHub_input_creds.txt have not been removed."
fi

echo -e "\e[34m################################################################################################################################################### \e[0m"

# Final completion message
echo -e "\e[32mEND OF SCRIPT THANKYOU!!! \e[0m"
