#!/bin/bash

# deploy.sh

# (c) 2025 Yakiv Koliada. Coach Ba software. All rights reserved.
# This program is free software: you can redistribute it and/or modify
# it under the terms version 3.0 of the GNU General Public License as published by
# the Free Software Foundation. This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY. See the GNU General Public License for more details.

# This script deploys the Coach Ba software by creating users, groups, and copying necessary files.

# Pre-requisites:
# sudo apt install acl

declare -a cb_users=(ya)
declare -a cb_package=('cbc.sh' 'cbl.sh' '.env')
declare CB_GROUP="cb"

getent group $CB_GROUP >/dev/null 2>&1 || groupadd -r $CB_GROUP

# Function: Check if the user exists, if not create it
function check_and_create_user() {
    local user="$1"

    if ! id -u "$user" >/dev/null 2>&1; then
        useradd -m -s /bin/bash -G $CB_GROUP $user
        echo "User: ${user}, created and added to group $CB_GROUP."
    else
        echo "User: ${user}, already exists."
    fi
}

# Function: Check if the bin folder exists and create it if not
function check_and_create_bin_folder() {
    local user="$1"

    if [[ ! -d "/home/$user/bin" ]]; then
        mkdir -p "/home/$user/bin"
        chown -R $user:$CB_GROUP "/home/$user/bin"
        chmod 755 "/home/$user/bin"
        echo "User: ${user}, created /home/$user/bin/ directory and set permissions."
    fi

    if [[ ! -d "/opt/$CB_GROUP" ]]; then
        mkdir -p "/opt/$CB_GROUP"
        chown -R :$CB_GROUP "/opt/$CB_GROUP"
        chmod 770 "/opt/$CB_GROUP"
        chmod g+s "/opt/$CB_GROUP"
        setfacl -d -m g::rwx "/opt/$CB_GROUP"
        echo "Created /opt/$CB_GROUP directory and set permissions."
    fi
}

# Function: Ensure the user is part of the CB_GROUP
function ensure_user_in_group() {
    local user="$1"

    if ! id -nG "$user" | grep -qw "$CB_GROUP"; then
        usermod -aG $CB_GROUP $user
        echo "User: ${user}, added to group $CB_GROUP."
    fi
}

# Function: Create a backup directory for existing packages
function create_backup_directory() {
    local user="$1"

    backup_dir="/home/$user/bin/backup/cb-$(date +'%Y-%m-%d-%H-%M-%S')"
    if [[ ! -d "$backup_dir" ]]; then
        mkdir -p "$backup_dir"
        chown -R $user:$CB_GROUP "$backup_dir"
        chmod 755 "$backup_dir"
        echo "User: ${user}, created backup directory $backup_dir."
    fi
}

# Function: Copy package files to the user's bin directory
function copy_package_files() {
    local user="$1"

    for package in "${cb_package[@]}"; do
        mv "/home/$user/bin/$package" "$backup_dir/" 2>/dev/null
        if [[ $? -eq 0 ]]; then
            echo "User: ${user}, moved existing $package to backup directory."
        fi
        if [[ ! -f "/home/$user/bin/$package" ]]; then
            cp "./$package" "/home/$user/bin"
            if [[ $? -eq 0 ]]; then
                chown -R $user:$CB_GROUP "/home/$user/bin/$package"
                if [[ $package =~ '.env' ]]; then
                    chmod 644 "/home/$user/bin/.env"
                    sed -i "s/CB_USERNAME=.*/CB_USERNAME=$user/" "/home/$user/bin/.env"
                else
                    chmod 755 "/home/$user/bin/$package"
                fi
                echo "User: ${user}, copied $package to /home/$user/bin/ and set permissions."
            fi
        fi
    done
}

# Function: Main function to orchestrate the deployment
function main() {
    for user in "${cb_users[@]}"; do
        check_and_create_user "$user"
        check_and_create_bin_folder "$user"
        ensure_user_in_group "$user"
        create_backup_directory "$user"
        copy_package_files "$user"
    done
}

main
