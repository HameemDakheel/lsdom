#!/usr/bin/env bash

# Function to collect domain data for a given cPanel user and output as a pipe-separated string
# Output format: username|parked_domains_csv|addon_domains_csv|sub_domains_csv
listDomains() {
    local user="$1"

    # Ensure user is not empty
    if [ -z "$user" ]; then
        # This error won't be visible in table output directly but good for debugging if function called manually
        echo "Error: Username not provided to listDomains function." >&2
        return 1
    fi

    local getdata
    getdata=$(uapi --user="$user" DomainInfo list_domains --output=json 2>/dev/null)

    # Check if uapi command was successful and data is valid JSON with expected structure
    if ! echo "$getdata" | jq -e '.result.status == 1 and .result.data.main_domain' > /dev/null 2>&1; then
        # Failure to get data for a user means this function returns 1, and no line is echoed.
        return 1
    fi

    # Parked domains (aliases)
    local parked_domains_list
    # '.result.data.parked_domains[]?' gets each parked domain, or nothing if array is empty/null.
    # 'paste -sd, -' joins them with a comma. If no input, outputs empty string.
    parked_domains_list=$(echo "$getdata" | jq --raw-output '.result.data.parked_domains[]?' | paste -sd, -)
    [ -z "$parked_domains_list" ] && parked_domains_list="N/A" # Set to N/A if list is empty

    # Addon domains
    local addon_domains_list
    addon_domains_list=$(echo "$getdata" | jq --raw-output '.result.data.addon_domains[]?' | paste -sd, -)
    [ -z "$addon_domains_list" ] && addon_domains_list="N/A"

    # Sub-domains
    # '.result.data.sub_domains[].domain?' gets the 'domain' field from each object in sub_domains array.
    local sub_domains_list
    sub_domains_list=$(echo "$getdata" | jq --raw-output '.result.data.sub_domains[].domain?' | paste -sd, -)
    [ -z "$sub_domains_list" ] && sub_domains_list="N/A"
    
    # Echo the structured string for the calling function to parse
    echo "$user|$parked_domains_list|$addon_domains_list|$sub_domains_list"
    return 0
}

# Function to print the table header
print_table_header() {
    # Define column widths - adjust as needed for your display
    local w_user=25
    local w_parked=40
    local w_addon=40
    local w_sub=45 # Subdomains can be FQDNs, so might need more width

    printf "| %-${w_user}s | %-${w_parked}s | %-${w_addon}s | %-${w_sub}s |\n" "Username" "Parked Domains" "Addon Domains" "Sub-Domains"
    # Create the separator line dynamically based on widths
    printf "|-%s-|-%s-|-%s-|-%s-|\n" \
        "$(printf '%*s' "$w_user" '' | tr ' ' '-')" \
        "$(printf '%*s' "$w_parked" '' | tr ' ' '-')" \
        "$(printf '%*s' "$w_addon" '' | tr ' ' '-')" \
        "$(printf '%*s' "$w_sub" '' | tr ' ' '-')"
}

# Function to print a table row
# Takes 4 arguments: username, parked_csv, addon_csv, sub_csv
print_table_row() {
    local cpanel_user="$1"
    local parked_list="$2"
    local addon_list="$3"
    local sub_list="$4"

    # Define column widths - must match header widths
    local w_user=25
    local w_parked=40
    local w_addon=40
    local w_sub=45

    # If lists are very long, they will wrap. For truncation, use e.g., "%.${w_parked}s"
    printf "| %-${w_user}s | %-${w_parked}s | %-${w_addon}s | %-${w_sub}s |\n" \
        "$cpanel_user" "$parked_list" "$addon_list" "$sub_list"
}

# --- Main script logic ---
header_printed=false # Flag to ensure header is printed only once

# Helper function to process a single user and print its table row
process_user() {
    local current_user="$1"
    local output_line
    
    output_line=$(listDomains "$current_user") # Call the modified listDomains

    if [ -n "$output_line" ]; then # Check if listDomains returned any data
        if ! $header_printed; then # Print header if not already printed
            print_table_header
            header_printed=true
        fi
        
        # Parse the pipe-separated output_line from listDomains
        local IFS='|' # Set Internal Field Separator to pipe for 'read'
        local cpanel_user_val parked_val addon_val sub_val
        # Read the values into separate variables
        read -r cpanel_user_val parked_val addon_val sub_val <<< "$output_line"
        
        print_table_row "$cpanel_user_val" "$parked_val" "$addon_val" "$sub_val"
    fi
}

# Argument parsing and execution logic
if [ "$#" -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: lsdom [OPTION] [ARGUMENT]"
    echo "Example: lsdom cpaneluser"
    echo "         lsdom -d example.com"
    echo "         lsdom -a"
    echo "         lsdom -U user1,user2,user3"
    echo "         lsdom -F /path/to/userlist.txt"
    echo ""
    echo "Lists main, parked, addon, and sub-domains for cPanel users in a table format."
    echo ""
    echo "Options:"
    echo "  [username]         Lists domains for the specified cPanel username."
    echo "  -d [domain]        Displays domains of the cPanel user who owns the input domain."
    echo "  -U [user1,user2,...] Lists domains for the specified comma-separated list of cPanel users."
    echo "  -F [filepath]      Lists domains for cPanel users specified in a file (one username per line)."
    echo "  -a, --all          Lists domains for all cPanel users on the server."
    echo "  -v, --version      Displays version information."
    echo "  -h, --help         Displays this help page."
    exit 0
elif [ "$1" = "-v" ] || [ "$1" = "--version" ]; then
    echo "lsdom 1.3.0" # Updated version for table output
    echo "Original script by Kevin \"nake89\" https://github.com/nake89/lsdom"
    echo "Edited by Hameem \"HameemDakheel\" https://github.com/HameemDakheel/lsdom"
    echo "Modifications for table output, enhanced domain collection, and multiple input methods."
    exit 0
elif [ "$1" = "-d" ]; then
    if [ -z "$2" ]; then
        echo "Error: -d option requires a domain name as an argument." >&2
        exit 1
    fi
    domain_to_check="$2"
    user_of_domain=$(/scripts/whoowns "$domain_to_check")
    if [ -z "$user_of_domain" ] || [ "$user_of_domain" = "nobody" ]; then
        echo "Error: Could not find a cPanel user for domain '$domain_to_check'." >&2
        exit 1
    fi
    process_user "$user_of_domain"
elif [ "$1" = "-U" ]; then
    if [ -z "$2" ]; then
        echo "Error: -U option requires a comma-separated list of usernames as an argument." >&2
        exit 1
    fi
    user_list="$2"
    OLD_IFS="$IFS"
    IFS=','
    read -r -a users_to_process <<< "$user_list"
    IFS="$OLD_IFS"

    if [ ${#users_to_process[@]} -eq 0 ]; then
        echo "Error: No usernames provided in the list for -U option." >&2
        exit 1
    fi
    for user_item in "${users_to_process[@]}"; do
        trimmed_user_item=$(echo "$user_item" | xargs) 
        if [ -n "$trimmed_user_item" ]; then
            process_user "$trimmed_user_item"
        fi
    done
elif [ "$1" = "-F" ]; then
    if [ -z "$2" ]; then
        echo "Error: -F option requires a file path as an argument." >&2
        exit 1
    fi
    user_file="$2"
    if [ ! -f "$user_file" ]; then
        echo "Error: File not found or is not a regular file: '$user_file'" >&2
        exit 1
    fi
    if [ ! -r "$user_file" ]; then
        echo "Error: File is not readable: '$user_file'" >&2
        exit 1
    fi
    while IFS= read -r user_item || [ -n "$user_item" ]; do
        trimmed_user_item=$(echo "$user_item" | xargs)
        if [ -n "$trimmed_user_item" ]; then
            process_user "$trimmed_user_item"
        fi
    done < "$user_file"
elif [ "$1" = "-a" ] || [ "$1" = "--all" ]; then
    trap "echo; echo 'Loop interrupted by user. Exiting.'; exit 1" SIGINT SIGTERM
    for user_file_path in /var/cpanel/users/*; do
        if [ -f "$user_file_path" ]; then
            user=$(basename "$user_file_path")
            # Skip common system/placeholder users
            if [[ "$user" == "system" || "$user" == "nobody" || "$user" == "cpanel" ]]; then
                continue
            fi
            process_user "$user"
        fi
    done
else 
    username_to_check="$1"
    if [[ "$username_to_check" == -* ]]; then
        echo "Error: Unknown option '$username_to_check'." >&2
        echo "Use 'lsdom --help' for usage instructions." >&2
        exit 1
    fi
    process_user "$username_to_check"
fi

# If the header was never printed, it means no data was processed.
if ! $header_printed; then
    echo "No domain data to display."
fi

exit 0