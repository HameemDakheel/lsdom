# cPanel Domain Lister (lsdom)

## Description

`lsdom` is a Bash script designed to run on cPanel & WHM servers. It lists main, parked (aliases), addon, and sub-domains associated with cPanel user accounts. The output is presented in a clear, tabular format. The script can list domains for a single user, multiple specified users, all users on the server, or the owner of a specific domain.

## Features

* Lists domains for a single cPanel account.
* Lists domains for multiple cPanel accounts specified as a comma-separated list.
* Lists domains for cPanel accounts specified in a file (one username per line).
* Identifies and lists domains for the cPanel account that owns a particular domain.
* Lists domains for all cPanel accounts on the server.
* Displays output in a formatted table with columns: Username, Parked Domains, Addon Domains, Sub-Domains.
* Uses `uapi` for accurate domain information retrieval.
* Provides help and version information.

## Requirements

* A cPanel & WHM server environment.
* Bash shell.
* `jq` (command-line JSON processor) must be installed.
* `uapi` command-line tool (part of cPanel).
* `/scripts/whoowns` cPanel script (for the `-d` option).
* Sufficient permissions to run `uapi` for other users (typically root or reseller with appropriate privileges).

## Installation

1.  **Download/Save the Script:**
    Save the script code to a file on your cPanel server (e.g., `lsdom.sh`).

2.  **Make it Executable:**
    Open your terminal and navigate to the directory where you saved the file. Then run:
    ```bash
    chmod +x lsdom.sh
    ```

3.  **Optional: Place in a PATH directory:**
    For easier access, you can move the script to a directory included in your system's PATH, like `/usr/local/bin/lsdom`.
    ```bash
    sudo mv lsdom.sh /usr/local/bin/lsdom
    ```
    If you do this, you can run the script by just typing `lsdom` instead of `./lsdom.sh`.

## Usage

### Synopsis

```bash
lsdom [OPTION] [ARGUMENT]