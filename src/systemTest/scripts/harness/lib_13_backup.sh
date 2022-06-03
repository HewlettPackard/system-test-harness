#!/usr/bin/env bash

### A library with functions for handling of backups.

function backup_file {
	### Creates backup of a file by appending suffix to its name.
	### Automatically restores a previous backup if one exists.
	### Usage: [user=user] backup_file file
	local user=${user:-$(whoami)}
	local file="$1"
	local backup="$file.bkp"
	if test -f "$backup"
	then
		warn "Existing backup found. Restoring"
		as_user_linux $user mv -v -f "$backup" "$file"
	fi
	as_user_linux $user cp -v -p --remove-destination "$file" "$backup"
}

function restore_file {
	### Restores file from backup created by backup_file.
	### Usage: [user=user] [fail_if_missing=true] restore_file file
	local user=${user:-$(whoami)}
	local file="$1"
	local backup="$file.bkp"
	if test -f "$backup"
	then
		as_user_linux $user mv -v -f "$backup" "$file"
	else
		error "Backup file is missing: $backup"
		if ${fail_if_missing:-true}
		then
			return 1
		fi
	fi
	return 0
}
