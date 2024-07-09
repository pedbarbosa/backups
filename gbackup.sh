#!/usr/bin/env bash

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $@" >>"${LOGFILE}"; }

archive() {
    ARCHIVE="/tmp/${BOX}-${TIMESTAMP}.bz2"

    if LOG_MSG=$(tar jcf "$ARCHIVE" -P "$TARGETS" 2>&1); then
        log "Backup file '${ARCHIVE}' created successfully."
    else
        log "Backup file '${ARCHIVE}' failed to create."
        log "Tar command output: ${LOG_MSG}"
        exit 1
    fi

    if mv "$ARCHIVE" "$FOLDER/"; then
        log "Backup file '${ARCHIVE}' moved to '${FOLDER}'."
    else
        log "Backup file '${ARCHIVE}' failed to move to '${FOLDER}'."
        exit 1
    fi
}

determine_host() {
    if [[ -z ${HOST} ]]; then
        if [[ -z ${HOSTNAME} ]]; then
            log "Couldn't determine 'hostname', aborting!"
            exit 1
        else
            BOX=${HOSTNAME}
        fi
    else
        BOX=${HOST}
    fi
}

determine_dir() {
    if [[ ! ${ZSH_VERSION} ]]; then
        SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    else
        SCRIPT_DIR=$(dirname "$0")
    fi
}

perform_backup() {
    determine_host
    determine_dir
    TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)

    if [[ ! -d ${FOLDER} ]]; then
        mkdir -p "${SCRIPT_DIR}/${FOLDER}"
    fi

    for i in ${ALLTARGETS}; do
        if [[ -e ${i} ]]; then
            TARGETS="${TARGETS} ${i}"
        fi
    done

    UNAME=$(uname -a | sed -E 's/ .*//')
    if [[ ${UNAME} == 'Darwin' ]]; then
        mac_backup
    elif [[ ${UNAME} == 'Linux' ]]; then
        linux_backup
    else
        log "Could not detect Operating System. Aborting."
        exit 1
    fi
}

mac_backup() {
    ARCHIVE=${SCRIPT_DIR}/${FOLDER}/${BOX}-${TIMESTAMP}.bz2
    archive
}

linux_backup() {
    if [[ ! -f "$HOME/.gdrive_token" ]]; then
        log "Google Drive token missing, creating local backup only..."
        
        ARCHIVE=${SCRIPT_DIR}/${FOLDER}/${BOX}-${TIMESTAMP}.bz2
        archive
    else
        ARCHIVE=/tmp/${BOX}-${TIMESTAMP}.bz2
        archive
        gdrive_upload
    fi
}

gdrive_upload() {
    GDRIVE_PARENT=$(cat "$HOME/.gdrive_token")
    MAX_ATTEMPTS=5
    ATTEMPT=0
    TIMEOUT=1

    while [[ ${ATTEMPT} < ${MAX_ATTEMPTS} ]]; do

        LOG_MSG=$(gdrive upload "${ARCHIVE}" -p "${GDRIVE_PARENT}")

        if [[ $? -eq 0 ]]; then
            log "Backup file '${ARCHIVE}' successfully uploaded to Google Drive."
            break
        else
            ATTEMPT=$((ATTEMPT + 1))
            log "Google Drive upload returned an error on attempt ${ATTEMPT}, retrying in ${TIMEOUT} seconds."
            log "gdrive command output: ${LOG_MSG}"
            sleep ${TIMEOUT}
            TIMEOUT=$((TIMEOUT * 2))
        fi

    done

    if [[ "${ATTEMPT}" == "${MAX_ATTEMPTS}" ]]; then
        log "Google Drive upload maximum number of attempts reached (${MAX_ATTEMPTS}), aborting!"
        exit 1
    fi

    rm "${ARCHIVE}"
}

### Script Configuration
LOGFILE=/tmp/gbackup.log
FOLDER="Machines"
ALLTARGETS="$HOME/.aws $HOME/.bash* $HOME/.chef $HOME/.gitconfig $HOME/.m2/settings* $HOME/.p10k.zsh $HOME/.profile $HOME/.router_conf $HOME/.ssh $HOME/.vimrc* $HOME/.zsh*"

### Script start
log "Execution started."
perform_backup
