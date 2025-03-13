
# This script automates the migration of the PostgreSQL database.
# It performs a full database dump, backs up the 'fm_action' table, stops and removes the current "filemover-db" container,
# creates a new container, restores the database from the backup, and makes alterations to certain tables.
# It will guide the user through each step of the migration and provide confirmation prompts to continue.
# The script assumes PostgreSQL is running in a Docker container and the necessary files are in place.
#!/bin/bash


DB_PORT_MAPPING="15432:5432"
DB_PORT_1=15432


db_username=""
db_name=""
db_password=""
HOME_DIR="/home/stgwe"


exit_on_error() {
    log_message "$1"
    exit 1
}

check_command_status() {
    if [ $? -ne 0 ]; then
        log_message "$1 failed. Exiting script."
        exit 1
    else
        log_message "$1 succeeded."
    fi
}
prompt_user() {
   
    echo -e "\e[36m$1 (y/N): \e[0m"  
    read confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_message "User chose not to proceed. Exiting script."
        exit 1
    fi
}

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
}


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

docker ps | grep -q "filemover-db"
if [ $? -eq 0 ]; then
    authenticate_db  # If the DB container is running, authenticate DB credentials
else
    # If the container is not running, prompt for DB credentials
    prerequisite_db_credential
fi

echo -e "\e[34m################################################################################################################################################### \e[0m"
echo -e "\e[33mGETTING STARTED WITH THE MIGRATION SCRIPT \e[0m" 
echo -e "\e[34m################################################################################################################################################### \e[0m"
sleep_after_command


if [ ! -d "$HOME_DIR/db_backups" ]; then
    echo "Creating backup directory: $HOME_DIR/db_backups"
    mkdir -p "$HOME_DIR/db_backups"
    check_command_status " db_backups directory creation."
fi
echo -e "\e[34m################################################################################################################################################### \e[0m"
prompt_user "Do you want to continue to create the table_backups folder under /home/stgwe/db_backups?"

if [ ! -d "$HOME_DIR/db_backups/table_backups" ]; then
    echo "Creating table backups directory: $HOME_DIR/db_backups/table_backups"
    mkdir -p "$HOME_DIR/db_backups/table_backups"
    check_command_status "table_backups directory creation."
fi
echo -e "\e[34m################################################################################################################################################### \e[0m"
echo -e "\e[33mTaking full database dump(to be on a safe side)...\e[0m" 
docker run --rm --network host -v $HOME_DIR:$HOME_DIR --env-file $HOME_DIR/.env-pdi postgres pg_dump -d $db_name -h localhost -p $DB_PORT_1 -U $db_username -w -Fc > $HOME_DIR/db_backups/NewProd_db_backup_$(date '+%Y-%m-%d %H:%M:%S').dump #use time stamp also
check_command_status "Taking full database dump"

echo -e "\e[34m################################################################################################################################################### \e[0m"
prompt_user "Do you want to continue to take fm_action table dump?"
echo -e "\e[33mNOTE : The fm_action table dump will be imported post the full db import from the db backup dump taken from current prod(Non Docker platform)...\e[0m" 
echo -e "\e[33mTaking table specific dump for fm_action...\e[0m" 
docker run --rm --network host -v $HOME_DIR:$HOME_DIR --env-file $HOME_DIR/.env-pdi postgres pg_dump -d $db_name -t fm_action -h localhost -p $DB_PORT_1 -U $db_username -w -Fc > $HOME_DIR/db_backups/table_backups/fm_action_backup_$(date '+%Y-%m-%d %H:%M:%S').dump ## use timestamp
check_command_status "Taking fm_action table dump"

echo -e "\e[34m################################################################################################################################################### \e[0m"
sleep_after_command
# Step 4: Bring down the "filemover-db" container
echo -e "\e[33mStopping and removing the 'filemover-db' container...\e[0m" 
docker stop filemover-db || exit_on_error "Failed to stop 'filemover-db' container.Exiting...."
docker rm filemover-db || exit_on_error "Failed to remove 'filemover-db' container.Exiting...."
echo -e "\e[34m################################################################################################################################################### \e[0m"
sleep_after_command   

# Step 5: Spin up a fresh "filemover-db" container
echo -e "\e[33mStarting fresh filemover-db container...\e[0m" 
docker run --name filemover-db -e POSTGRES_DB=$db_name -e POSTGRES_USER=$db_username -e POSTGRES_PASSWORD=$db_password -p $DB_PORT_MAPPING -d postgres
check_command_status "Starting fresh filemover-db container"
echo -e "\e[34m################################################################################################################################################### \e[0m"


# Step 6: Import the database from the backup
prompt_user "Do you want to import db from current prod db dump?"
echo -e "\e[33mRestoring database from backup(CurrProd_DB_Backup dump)...\e[0m" 
docker run -i --rm --network host -v $HOME_DIR:$HOME_DIR --env-file $HOME_DIR/.env-pdi postgres pg_restore -d $db_name -h localhost -p $DB_PORT_1 -U $db_username -w < $(ls -td $HOME_DIR/db_backups/CurrProd_DB_Backup_*.dump | head -n 1)
check_command_status "Restoring the database from the backup"
echo -e "\e[34m################################################################################################################################################### \e[0m"

prompt_user "Do you want to continue to delete all rows from fm_action table?"
echo -e "\e[33mDeleting all rows from fm_action table...\e[0m" 
docker run -it --rm --network host -v $HOME_DIR:$HOME_DIR --env-file $HOME_DIR/.env-pdi postgres psql --port $DB_PORT_1 --host localhost --username $db_username --dbname $db_name -c "DELETE FROM fm_action;"
check_command_status "Deleting rows from fm_action table"
echo -e "\e[34m################################################################################################################################################### \e[0m"

prompt_user "Do you want to continue to run additional alter table commands?"
# Step 8: Run table alteration commands to upgrade the tables

echo "Running table alterations..."
docker run -it --rm --network host -v $HOME_DIR:$HOME_DIR --env-file $HOME_DIR/.env-pdi postgres psql --port $DB_PORT_1 --host localhost --username $db_username --dbname $db_name -c "ALTER TABLE fm_job ADD COLUMN parent_schema text;"
docker run -it --rm --network host -v $HOME_DIR:$HOME_DIR --env-file $HOME_DIR/.env-pdi postgres psql --port $DB_PORT_1 --host localhost --username $db_username --dbname $db_name -c "ALTER TABLE fm_job_event ADD COLUMN build_info text;"
docker run -it --rm --network host -v $HOME_DIR:$HOME_DIR --env-file $HOME_DIR/.env-pdi postgres psql --port $DB_PORT_1 --host localhost --username $db_username --dbname $db_name -c "ALTER TABLE fm_job_event ADD COLUMN initiator_id text;"
docker run -it --rm --network host -v $HOME_DIR:$HOME_DIR --env-file $HOME_DIR/.env-pdi postgres psql --port $DB_PORT_1 --host localhost --username $db_username --dbname $db_name -c "ALTER TABLE fm_action ADD COLUMN IF NOT EXISTS is_error_handler boolean NOT NULL DEFAULT FALSE;"
docker run -it --rm --network host -v $HOME_DIR:$HOME_DIR --env-file $HOME_DIR/.env-pdi postgres psql --port $DB_PORT_1 --host localhost --username $db_username --dbname $db_name -c "ALTER TABLE fm_action ADD COLUMN IF NOT EXISTS precondition_env jsonb;"
docker run -it --rm --network host -v $HOME_DIR:$HOME_DIR --env-file $HOME_DIR/.env-pdi postgres psql --port $DB_PORT_1 --host localhost --username $db_username --dbname $db_name -c "ALTER TABLE fm_action ADD COLUMN IF NOT EXISTS precondition_override text;"
docker run -it --rm --network host -v $HOME_DIR:$HOME_DIR --env-file $HOME_DIR/.env-pdi postgres psql --port $DB_PORT_1 --host localhost --username $db_username --dbname $db_name -c "ALTER TABLE fm_job_action_event ADD COLUMN IF NOT EXISTS resolved_action_parms text;"
docker run -it --rm --network host -v $HOME_DIR:$HOME_DIR --env-file $HOME_DIR/.env-pdi postgres psql --port $DB_PORT_1 --host localhost --username $db_username --dbname $db_name -c "ALTER TABLE fm_job_action_event ADD COLUMN IF NOT EXISTS end_tms timestamp without time zone;"
check_command_status "Execution of alter table commands"
echo -e "\e[34m################################################################################################################################################### \e[0m"
sleep_after_command

# Step 9: Import the fm_action table from the backup dump
echo -e "\e[33mImporting 'fm_action' table from table backup dump...\e[0m" 
docker run -i --rm --network host -v $HOME_DIR:$HOME_DIR --env-file $HOME_DIR/.env-pdi postgres pg_restore --data-only -d $db_name -t fm_action -h localhost -p $DB_PORT_1 -U $db_username -w < $(ls -td $HOME_DIR/db_backups/table_backups/fm_action_backup_*.dump | head -n 1)
check_command_status "Restoring fm_action table from table backup dump"
echo -e "\e[34m################################################################################################################################################### \e[0m"
sleep_after_command

echo "Creating absent table 'fm_env_parms'..."
docker run --rm --network host -v $HOME_DIR:$HOME_DIR --env-file $HOME_DIR/.env-pdi postgres psql -d $db_name -h localhost -p $DB_PORT_1 -U $db_username -w -f $HOME_DIR/recon-stgwe-documentation/db-init/15-FM-CORE-DDL/105-fm_env_parms.sql
check_command_status "fm_env_parms table creation"
echo -e "\e[34m################################################################################################################################################### \e[0m"
sleep_after_command

prompt_user "Do you want to run filemover HELLO_WORLD test?"
docker run --rm --network host -v $HOME_DIR/etl:$HOME_DIR/etl --env-file $HOME_DIR/.env-pdi filemover:latest HELLO_WORLD
check_command_status "HELLO_WORLD test"
echo -e "\e[34m################################################################################################################################################### \e[0m"
echo -e "\e[32mNew production DB setup completed successfully!!! \e[0m"

