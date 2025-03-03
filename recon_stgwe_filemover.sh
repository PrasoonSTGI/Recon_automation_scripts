#!/bin/bash

# Log function for printing messages with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Sleep function for waiting
sleep_after_command() {
    sleep 4  # sleep for 4 seconds (you can change the duration)
}

# Exit function for handling errors and stopping further execution
exit_on_error() {
    log_message "$1"
    exit 1
}



USER_NAME=$USER  # Store username in a variable instead of asking every time
# (whom) is better to use USER_NAME variable directly

# User home = $HOME
# Default Port Mapping renamed to db port mapping
DB_PORT_MAPPING="15432:5432"

# Step 1: Test Docker installation by running hello-world image
log_message 'Testing Docker installation with hello-world image...'
docker run hello-world
if [ $? -ne 0 ]; then
    exit_on_error 'Docker hello-world test failed. Exiting script.'
else
    log_message 'Docker hello-world test successful.'
fi
sleep_after_command

# --> Prompt if user wants to continue (y/N)
read -p "Do you want to continue? (y/N): " CONTINUE
if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
    exit_on_error "User chose to stop the execution."
fi
----------------
# Step 2: Pull PostgreSQL image and run the container with user inputs
log_message 'Checking if PostgreSQL container "filemover-db" is already running...'

# Check if the PostgreSQL container is already running
docker ps | grep -q "filemover-db"
if [ $? -eq 0 ]; then
    log_message "PostgreSQL container 'filemover-db' is already running. Skipping the PostgreSQL container creation."
else
    log_message 'Enter PostgreSQL container details:'
    read -p 'Enter POSTGRES_DB_NAME: ' POSTGRES_DB
    read -p 'Enter POSTGRES_USER: ' POSTGRES_USER
    read -p 'Enter POSTGRES_PASSWORD: ' POSTGRES_PASSWORD
    
    log_message 'Pulling and running PostgreSQL container...'
    docker run --name filemover-db -e POSTGRES_DB="$POSTGRES_DB" -e POSTGRES_USER="$POSTGRES_USER" -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" -p $DB_PORT_MAPPING -d postgres
    if [ $? -ne 0 ]; then
        exit_on_error 'Failed to deploy PostgreSQL container. Exiting script.'
    else
        log_message 'PostgreSQL container deployed successfully.'
    fi
fi
sleep_after_command

# Step 3: Verify Docker images and containers
log_message 'Listing Docker images and running containers...'
docker images
docker ps
sleep_after_command

# Step 4: Take input for DB username and DB name
read -p "Enter DB username: " db_username
read -p "Enter DB name: " db_name

# Step 5: Clone the repository
log_message "Cloning repository..."
if [ ! -d "recon-stgwe-documentation" ]; then
    git clone https://github.com/thesummitgrp/recon-stgwe-documentation.git
    if [ $? -ne 0 ]; then
        exit_on_error "Failed to clone the repository. Exiting script."
    else
        log_message "Repository cloned successfully."
    fi
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
    if [ $? -ne 0 ]; then
        exit_on_error "Failed to copy the env-pdi file. Exiting script."
    else
        log_message "env-pdi file copied successfully."
    fi
fi
sleep_after_command

# Step 7: Update values inside .env-pdi file (remove cat step, don't show content)
log_message "Updating values inside .env-pdi file..."

# Taking input for variables to update
P_STGWE_UID=$(id -u)  # Get user ID
P_STGWE_GID=$(id -g)  # Get group ID
PGPASSWORD=$POSTGRES_PASSWORD  # Pass PG_PASSWORD variable
DB_PASSWORD_1=$POSTGRES_PASSWORD  # Pass pgpassword from earlier variable
DB_USERNAME_1=$POSTGRES_USER  # Pass from earlier variable
DB_NAME_1=$POSTGRES_DB  # Pass from earlier variable
DB_PORT_1=15432  # Hardcode port

# Use sed to update values inside .env-pdi
sed -i "s/^P_STGWE_UID=[^ ]*/P_STGWE_UID=$P_STGWE_UID/" .env-pdi
sed -i "s/^P_STGWE_GID=[^ ]*/P_STGWE_GID=$P_STGWE_GID/" .env-pdi
sed -i "s/^PGPASSWORD=[^ ]*/PGPASSWORD=$PGPASSWORD/" .env-pdi
sed -i "s/^DB_PORT_1=[^ ]*/DB_PORT_1=$DB_PORT_1/" .env-pdi
sed -i "s/^DB_PASSWORD_1=[^ ]*/DB_PASSWORD_1=$DB_PASSWORD_1/" .env-pdi
sed -i "s/^DB_USERNAME_1=[^ ]*/DB_USERNAME_1=$DB_USERNAME_1/" .env-pdi
sed -i "s/^DB_NAME_1=[^ ]*/DB_NAME_1=$DB_NAME_1/" .env-pdi

log_message "Database attributes are updated successfully in {$HOME/.env-pdi}. This file will be used for db connection."
sleep_after_command

# Step 8: Test the DB connection
log_message "Testing DB connection using .env-pdi file ..."
log_message "You will be redirected to database prompt (Enter \q to exit the psql prompt)"
docker run -it --rm --network host -v /home/$USER:/home/$USER --env-file /home/$USER/.env-pdi postgres psql --port $DB_PORT_1 --host localhost --username $db_username --dbname $db_name
if [ $? -ne 0 ]; then
    exit_on_error "DB connection test failed. Exiting script."
else
    log_message "DB connection test successful."
fi
sleep_after_command

# Step 9: Create or update database_sql_new.sh file and execute it
log_message "Checking if database_sql_new.sh exists..."

# Use absolute path instead of relative path
if [ ! -f /home/$USER/database_sql_new.sh ]; then
    log_message "database_sql_new.sh not found. Creating it..."

    # Create the database_sql_new.sh file with the given content
    cat << 'EOF' > /home/$USER/database_sql_new.sh
#!/bin/bash

# Loop through all .sql files and execute them
for FILE in $(ls -a /home/stgwe/*/*/*/*.sql); do
    docker run --rm --network host -v /home/stgwe:/home/stgwe --env-file /home/stgwe/.env-pdi postgres psql --port 15432 --host localhost --username summit --dbname summit -f $FILE
done
EOF

    # Check if the file creation was successful
    if [ $? -ne 0 ]; then
        exit_on_error "Failed to create database_sql_new.sh. Exiting script."
    else
        log_message "database_sql_new.sh created successfully."
    fi

    # Make the script executable
    chmod +x /home/$USER/database_sql_new.sh
    if [ $? -ne 0 ]; then
        exit_on_error "Failed to make database_sql_new.sh executable. Exiting script."
    else
        log_message "database_sql_new.sh is now executable."
    fi
else
    log_message "database_sql_new.sh already exists. Skipping creation."
fi
sleep_after_command

# --> Prompt to proceed with executing the database_sql_new.sh file
read -p "Do you want to continue and execute the database_sql_new.sh file? (y/N): " EXECUTE_SQL
if [[ ! "$EXECUTE_SQL" =~ ^[Yy]$ ]]; then
    exit_on_error "User chose to stop the execution."
fi

# Now execute the database_sql_new.sh file
log_message "Executing database_sql_new.sh..."
/home/$USER/database_sql_new.sh
if [ $? -ne 0 ]; then
    exit_on_error "Failed to execute database_sql_new.sh. Exiting script."
else
    log_message "database_sql_new.sh executed successfully."
fi
sleep_after_command
#--> dump all the creation logs and alter logs in a txt file for reference
# Step 10: Create db_backups directory if it doesn't exist
log_message "Checking if db_backups directory exists..."
if [ ! -d /home/$USER/db_backups ]; then
    mkdir /home/$USER/db_backups
    log_message "Created db_backups directory."
else
    log_message "db_backups directory already exists."
fi
sleep_after_command

# Step 14: Setting up the Recon client
log_message "Setting up Recon client..."
cd /home/$USER
mkdir -p etl/output etl/archive pentaho/data-integration/lib pentaho/repository
log_message "Created Recon client directory structure."

# Step 15: Copy Dockerfile for Recon client
log_message "Copying Dockerfile for Recon client..."
cp /home/$USER/recon-stgwe-documentation/Dockerfile /home/$USER
if [ $? -ne 0 ]; then
    exit_on_error "Failed to copy Dockerfile. Exiting script."
else
    log_message "Dockerfile copied successfully."
fi
sleep_after_command

# Step 16: Build Docker image
log_message "Building Docker image..."
read -p "Enter your GitHub username: " GH_USERNAME
read -p "Enter your GitHub token: " GH_TOKEN
echo $GH_TOKEN | docker login ghcr.io -u $GH_USERNAME --password-stdin
if [ $? -ne 0 ]; then
    exit_on_error "Docker login failed. Exiting script."
fi

# Step 17: Update Dockerfile content
log_message "Updating Dockerfile content..."

# Take input for the new image version
read -p "Enter the latest filemover image version (e.g., 3810569831.69): " IMAGE_VERSION

# Update Dockerfile with the provided version
sed -i "s|FROM ghcr.io/thesummitgrp/stgwe-framework-pdi-filemover:[^ ]*|FROM ghcr.io/thesummitgrp/stgwe-framework-pdi-filemover:$IMAGE_VERSION|" Dockerfile

if [ $? -ne 0 ]; then
    exit_on_error "Failed to update Dockerfile. Exiting script."
else
    log_message "Dockerfile updated with the new image version."
fi

# Step 18: Verify Dockerfile content
log_message "Displaying updated Dockerfile content:"
cat Dockerfile


# --> Prompt to continue (y/N) for filemover image build
read -p "Do you want to continue and build the filemover image? (y/N): " BUILD_IMAGE
if [[ ! "$BUILD_IMAGE" =~ ^[Yy]$ ]]; then
    exit_on_error "User chose to stop the execution."
fi

docker build -t filemover .
if [ $? -ne 0 ]; then
    exit_on_error "Docker build failed. Exiting script."
else
    log_message "Docker image built successfully."
fi
sleep_after_command

# Step 19: Verify the built Docker image
log_message "Verifying built Docker image..."
docker images | grep "filemover"
if [ $? -ne 0 ]; then
    exit_on_error "Docker image verification failed. Exiting script."
else
    log_message "Docker image verification successful."
fi
sleep_after_command
