# backups
Mac and Linux backups to Google Drive

## Requirements

### Google Drive

On a Mac it requires "Backup and sync from Google" to be installed and a symbolic link created into the synced folder.
On Linux it requires a Google Drive token for target folder

## Instructions

### Mac - first setup

Create a symbolic link for the backups to be added straight to Google Drive:

```
mkdir -p ~/Google\ Drive/Backups/Machines
ln -s ~/Google\ Drive/Backups/Machines .
```

### Linux - first setup

Retrieve a Google Drive token for the corresponding backup folder in Google Drive, and write it to `~/.gdrive_token`

## Execute the backup

```
bash gbackup.sh
```

