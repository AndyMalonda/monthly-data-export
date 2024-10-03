# Monthly Data Export Script

This script is designed to export data from a MySQL database to a CSV file based on a date range. The script loads environment variables from a [`.env`] file, constructs a SQL query to fetch data between the first and last day of the previous month, and saves the results to a CSV file.

I used to run this script on a Docker environment, but you can run it on any Linux environment with MySQL installed.

## Prerequisites

- MySQL database
- Bash shell
- [`.env`] file with the necessary environment variables

## Environment Variables

The script uses the following environment variables, which should be defined in a [`.env`] file in the same directory as the script:

```env
DB_NAME=your_db_name
EXPORTED_DATA_FOLDER=/path/to/exported_data/
REPORT_DESTINATION_FOLDER=/path/to/Destination/
DB_USER=your_db_user
DB_PASSWORD=your_db_password
DB_HOST=your_db_host
```

## Usage

1. **Create a [`.env`] file** in the same directory as the script with the necessary environment variables.

2. **Make the script executable**:

    ```sh
    chmod +x monthly_data_export.sh
    ```

3. **Run the script**:

    ```sh
    ./monthly_data_export.sh
    ```

## Setting Up a Cron Job

To execute the script automatically each month, you can set up a cron job. Here’s how you can do it:

1. **Open the crontab editor**:

    ```sh
    crontab -e
    ```

2. **Add the following line to schedule the script to run at midnight on the first day of each month**:

    ```sh
    0 0 1 * * /path/to/monthly_data_export.sh
    ```

    Replace `/path/to/monthly_data_export.sh` with the actual path to your script.

3. **Save and close the crontab editor**.

## Script Details

1. **Load Environment Variables**: The script loads environment variables from a [`.env`] file if it exists.

    ```sh
    if [ -f .env ]; then
        export $(grep -v '^#' .env | xargs)
    fi
    ```

2. **Define the CSV Header**: The script defines the CSV header.

    ```sh
    csv_header="Set;your;csv;header;here"
    ```

3. **Set Default Environment Variables**: The script sets default values for environment variables if they are not already set.

    ```sh
    export DB_NAME="${DB_NAME:-default_DB}"
    export EXPORTED_DATA_FOLDER="${EXPORTED_DATA_FOLDER:-/path/to/exported_data/}"
    export REPORT_DESTINATION_FOLDER="${REPORT_DESTINATION_FOLDER:-/path/to/Destination/}"
    export DB_USER="${DB_USER:-your_db_user}"
    export DB_PASSWORD="${DB_PASSWORD:-your_db_password}"
    export DB_HOST="${DB_HOST:-your_db_host}"
    ```

4. **Create Export Directory**: The script creates the export directory if it does not exist.

    ```sh
    if [ ! -d "$EXPORTED_DATA_FOLDER" ]; then
        mkdir -p "$EXPORTED_DATA_FOLDER"
        chmod 777 -R "$EXPORTED_DATA_FOLDER"
    fi
    ```

5. **Calculate Date Range**: The script calculates the first and last day of the previous month.

    ```sh
    first_day=$(date -d "$(date +'%Y-%m-01') -1 month" +'%Y-%m-01')
    last_day=$(date -d "$(date +'%Y-%m-01') -1 day" +'%Y-%m-%d')
    first_shift_start_time="00:00:00"
    last_shift_end_time="23:59:59"
    ```

6. **Construct CSV File Name**: The script constructs the CSV file name based on the date range.

    ```sh
    csv_file_name="${DB_NAME}_${first_day}_${last_day}"
    ```

7. **Define SQL Query**: The script defines the SQL query to fetch data between the calculated date range.

    ```sh
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
    ```

8. **Run SQL Query**: The script runs the SQL query and handles any errors.

    ```sh
    mysql -u "$DB_USER" -p"$DB_PASSWORD" -D "$DB_NAME" -h "$DB_HOST" -e "$sql" || {
        printf "An error occurred while executing the SQL query.\n" | tee -a "$log_file"
        error_sql_file="${EXPORTED_DATA_FOLDER}error_${csv_file_name}.sql"
        printf "%s" "$sql" > "$error_sql_file"
        printf "Error SQL file created at %s\n" "$error_sql_file" | tee -a "$log_file"
        exit 1
    }
    ```

9. **Add CSV Header**: The script adds the CSV header to the file.

    ```sh
    sed -i "1i $csv_header" "${EXPORTED_DATA_FOLDER}${csv_file_name}.csv"
    ```

10. **Move CSV File**: The script moves the CSV file to the destination directory.

    ```sh
    if [ ! -d "${REPORT_DESTINATION_FOLDER}${current_year}/" ]; then
        mkdir -p "${REPORT_DESTINATION_FOLDER}${current_year}/"
    fi

    mv "${EXPORTED_DATA_FOLDER}${csv_file_name}.csv" "${REPORT_DESTINATION_FOLDER}${current_year}/" || {
        printf "An error occurred while moving the CSV file.\n" | tee -a "$log_file"
        exit 1
    }
    ```

## Example

To run the script for the previous month, simply execute:

```sh
./monthly_data_export.sh
```

This will generate a CSV file with data from the previous month and move it to the specified destination folder.