#!/bin/bash

DB_PORT_MAPPING="15432:5432"
DB_PORT_1=15432 

# New variables initialized beforehand
db_username=""
db_name=""
db_password=""
github_username=""
github_token=""

# Log function for printing messages with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$1" >> track.txt  # Log to track file
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

# Function to check prerequisites for running the script
recheck_prerequisites() {
    # Check if the user has repo access and GitHub credentials ready
    prompt_user "Do you have access to the repository (recon-stgwe-documentation)?"
    
    prompt_user "Do you have your GitHub credentials (username & GitHub PAT) ready?"
}

# Function to prompt user for database and GitHub credentials
prerequisite_credential() {
    # Always ask user for credentials
    echo -e "\e[33mEnter DB username: \e[0m"
    read db_username

    echo -e "\e[33mEnter DB name: \e[0m"
    read db_name

    echo -e "\e[33mEnter DB password: \e[0m"
    read db_password
    echo  

    # Prompt the user for GitHub credentials
    echo -e "\e[33mEnter GitHub username: \e[0m"
    read github_username

    echo -e "\e[33mEnter GitHub Personal Access Token (PAT): \e[0m"
    read github_token
    echo  

    # Store the credentials in the input_creds.txt file for future use (overwrite every time)
    echo "db_username=$db_username" > input_creds.txt
    echo "db_name=$db_name" >> input_creds.txt
    echo "db_password=$db_password" >> input_creds.txt
    echo "github_username=$github_username" >> input_creds.txt
    echo "github_token=$github_token" >> input_creds.txt
}


# Recheck prerequisites at the start of the script
recheck_prerequisites

# Now take DB and GitHub credentials
prerequisite_credential

# Step 1: Test Docker installation by running hello-world image
log_message 'Testing Docker installation with hello-world image...'
docker run hello-world
check_command_status "Docker hello-world test"

sleep_after_command

# --> Prompt if user wants to continue (y/N)
prompt_user "Do you want to continue?"

# Step 2: Pull PostgreSQL image and run the container with user inputs
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
sleep_after_command

# Step 3: Verify Docker images and containers
log_message 'Listing Docker images and running containers...'
docker images
docker ps

sleep_after_command

# Step 5: Clone the repository
log_message "Cloning repository..."
if [ ! -d "recon-stgwe-documentation" ]; then
    git clone https://github.com/thesummitgrp/recon-stgwe-documentation.git
    check_command_status "Repository cloned"
else
    log_message "Repository 'recon-stgwe-documentation' already exists. Skipping cloning."
fi
sleep_after_command

# Step 6: Navigate to the home directory and copy env-pdi file
cd ~ || exit_on_error "Failed to navigate to home directory."
log_message "Copying env-pdi file to the home directory..."
if [ ! -f /home/$USER/recon-stgwe-documentation/db-init/env-pdi ]; then
    exit_on_error "env-pdi file not found. Exiting script."
else
    cp /home/$USER/recon-stgwe-documentation/db-init/env-pdi .env-pdi
    check_command_status "Copying env-pdi file"
fi
sleep_after_command

# Step 7: Update values inside .env-pdi file
log_message "Updating values inside .env-pdi file..."
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
check_command_status "Updating .env-pdi file"

# Step 8: Test the DB connection
log_message "Testing DB connection using .env-pdi file ...(Enter \q to exit the db connection prompt)"
docker run -it --rm --network host -v /home/$USER:/home/$USER --env-file /home/$USER/.env-pdi postgres psql --port $DB_PORT_1 --host localhost --username $db_username --dbname $db_name
check_command_status "DB connection test"

sleep_after_command

# Step 9: Create or update database_sql_new.sh file and execute it
log_message "Checking if database_sql_new.sh exists..."
if [ ! -f /home/$USER/database_sql_new.sh ]; then
    log_message "database_sql_new.sh not found. Creating it..."
    cat << 'EOF' > /home/$USER/database_sql_new.sh
#!/bin/bash
for FILE in $(ls -a /home/stgwe/*/*/*/*.sql); do
    docker run --rm --network host -v /home/stgwe:/home/stgwe --env-file /home/stgwe/.env-pdi postgres psql --port 15432 --host localhost --username summit --dbname summit -f $FILE
done
EOF
    check_command_status "Creating database_sql_new.sh"
    chmod +x /home/$USER/database_sql_new.sh
    check_command_status "Making database_sql_new.sh executable"
else
    log_message "database_sql_new.sh already exists. Skipping creation."
fi
sleep_after_command

# Step 10: Execute SQL commands (run after tables are created)
log_message "Running SQL commands on DB..."
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

check_command_status "Running SQL commands on DB"

sleep_after_command

# Step 11: Create db_backups directory if it doesn't exist
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
empty_backups=$(find /home/$USER/db_backups/ -size 0 -print0)
if [ -z "$empty_backups" ]; then
    log_message "No empty backups found. Moving forward."
else
    echo "$empty_backups" | xargs -0 rm
    check_command_status "Removing empty backups"
fi
sleep_after_command

# Step 14: Remove and restart PostgreSQL container and restore backup
log_message "Restoring backup to PostgreSQL container..."
docker rm --force filemover-db
sleep 5
docker run --name filemover-db -e POSTGRES_DB=$db_name -e POSTGRES_USER=$db_username -e POSTGRES_PASSWORD=$PGPASSWORD -p $PORT_MAPPING -d postgres
sleep 10
docker run -i --rm --network host -v /home/$USER:/home/$USER --env-file /home/$USER/.env-pdi postgres pg_restore -d $db_name -h localhost -p $DB_PORT_1 -U $db_username -w < $(ls -td /home/$USER/db_backups/* | head -1)
if [ $? -ne 0 ]; then
    exit_on_error "Failed to restore DB from backup. Exiting script."
else
    log_message "DB restore completed successfully."
fi
sleep_after_command

# Final completion message
log_message "Script execution completed successfully."
