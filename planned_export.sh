#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Define the CSV header
csv_header="Set;your;csv;header;here"

# Example call (in root)
# chmod +x monthly_data_export.sh
# ./monthly_data_export.sh

# Environment variables (set these in your environment or in a .env file)
export FILE_NAME = "${FILE_NAME:-file_name}"
export EXPORTED_DATA_FOLDER="${EXPORTED_DATA_FOLDER:-/path/to/exported_data/}"
export REPORT_DESTINATION_FOLDER="${REPORT_DESTINATION_FOLDER:-/path/to/Destination/}"
export DB_NAME="${DB_NAME:-default_DB}"
export DB_USER="${DB_USER:-your_db_user}"
export DB_PASSWORD="${DB_PASSWORD:-your_db_password}"
export DB_HOST="${DB_HOST:-your_db_host}"

current_year=$(date +'%Y')
log_file="${EXPORTED_DATA_FOLDER}data-last-month.log"
printf "Script started at $(date)\n" | tee -a "$log_file"

if [ ! -d "$EXPORTED_DATA_FOLDER" ]; then
    mkdir -p "$EXPORTED_DATA_FOLDER"
    chmod 777 -R "$EXPORTED_DATA_FOLDER"
fi

# Get first and last day of last month
first_day=$(date -d "$(date +'%Y-%m-01') -1 month" +'%Y-%m-01')
last_day=$(date -d "$(date +'%Y-%m-01') -1 day" +'%Y-%m-%d')
first_shift_start_time="00:00:00"
last_shift_end_time="23:59:59"

# ex: DB_2024-02-01_2024-02-29
csv_file_name="${FILE_NAME}_${first_day}_${last_day}"

start_date="${first_day} ${first_shift_start_time}"
end_date="${last_day} ${last_shift_end_time}"

# Define SQL query
sql="
SELECT
    Id,
    Timestamp,
    ProductId
FROM
    Orders
WHERE
    Timestamp >= '$start_date'
    AND Timestamp <= '$end_date'
ORDER BY
    Timestamp ASC
INTO OUTFILE '${EXPORTED_DATA_FOLDER}${csv_file_name}.csv'
FIELDS TERMINATED BY ';' OPTIONALLY ENCLOSED BY '\"' LINES TERMINATED BY '\\r\\n';
"

# Run SQL query and handle errors
printf "Running SQL query...\n" | tee -a "$log_file"

# log the sql query
sql_log_file=$(mktemp "${EXPORTED_DATA_FOLDER}sql_${csv_file_name}.XXXXXX.sql")
printf "%s" "$sql" > "$sql_log_file"

mysql -u "$DB_USER" -p"$DB_PASSWORD" -D "$DB_NAME" -h "$DB_HOST" -e "$sql" || {
    printf "An error occurred while executing the SQL query.\n" | tee -a "$log_file"
    error_sql_file="${EXPORTED_DATA_FOLDER}error_${csv_file_name}.sql"
    printf "%s" "$sql" > "$error_sql_file"
    printf "Error SQL file created at %s\n" "$error_sql_file" | tee -a "$log_file"
    exit 1
}

# Add the CSV header to the file
sed -i "1i $csv_header" "${EXPORTED_DATA_FOLDER}${csv_file_name}.csv"

# Check if the source directory exists
if [ ! -d "${EXPORTED_DATA_FOLDER}" ]; then
    printf "Source directory does not exist.\n" | tee -a "$log_file"
    exit 1
fi

# Check if the destination directory exists, create it if it doesn't
if [ ! -d "${REPORT_DESTINATION_FOLDER}${current_year}/" ]; then
    printf "Destination directory does not exist, creating it now.\n" | tee -a "$log_file"
    mkdir -p "${REPORT_DESTINATION_FOLDER}${current_year}/"
fi

# Move the CSV file and handle errors
printf "Moving CSV file...\n" | tee -a "$log_file"
mv "${EXPORTED_DATA_FOLDER}${csv_file_name}.csv" "${REPORT_DESTINATION_FOLDER}${current_year}/" || {
    printf "An error occurred while moving the CSV file.\n" | tee -a "$log_file"
    exit 1
}

printf "Script completed at $(date)\n" | tee -a "$log_file"