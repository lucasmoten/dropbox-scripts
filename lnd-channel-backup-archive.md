# LND Channel Backup Archive

This script supports making local and offsite backups of the Static Channel Backup (channel.backup) file for a Bitcoin Lightning node.  For offsite backups, this script saves to Dropbox via the API leveraging OAuth2. With the older long lived access tokens being phased out in September 2021, this script promotes usage of the new model whereby a long lived refresh token is used to acquire a new short lived access token on demand.  Configuration of the script is easy, walking you through how to setup the application.

Influenced by the works of [Arvin](https://github.com/vindard), and [Stadicus Raspibolt](https://stadicus.github.io/RaspiBolt/raspibolt_73_static_backup_dropox.html)

## Installation

This assumes it will be running in the same folder as where local backups will reside and will use a user named `bitcoin`.

First, change to the bitcoin user
```sh
sudo su - bitcoin
```

Then create the backup folder, retrieve the script and mark as executable 
```sh
mkdir -p /home/bitcoin/backups/lnd ;; cd /home/bitcoin/backups/lnd
wget https://raw.githubusercontent.com/lucasmoten/dropbox-scripts/main/lnd-channel-backup-archive.sh
chmod +x 
```

## Configuration

From the location where the script is at, run it to start configuration

```sh
cd /home/bitcoin/backups/lnd
./lnd-channel-backup-archive.sh
```

![Screenshot from 2021-04-11 22-36-39](https://user-images.githubusercontent.com/14304023/114333554-936e5780-9b16-11eb-8690-cc4a49ecdfff.png)


Follow the on screen prompts to create the Dropbox application, get the app key and secret, authorize the app to access your account for writing files, and get the appropriate tokens for running.  

The Name for the app must be unique across Dropbox as a whole, so one way to do this is to add a date string like a version as depicted below

![Screenshot from 2021-04-11 22-58-04](https://user-images.githubusercontent.com/14304023/114334828-653e4700-9b19-11eb-8f22-80735128abdd.png)

The first time you run the configuration, all the values with be `not-set`.  After saved, and editing configuration in the future, the prompts will show the current values.  Here is a sample with blurred values.

![Screenshot from 2021-04-11 22-41-28](https://user-images.githubusercontent.com/14304023/114335307-7f2c5980-9b1a-11eb-8253-d10b161de4f2.png)



When all values are set, a summary will be displayed and you will be prompted to save the configuration.

The configuration file is saved in JSON format and is referenced when running as a service.

## Creating Service

Setup script as `systemd` service

```sh
sudo nano /etc/systemd/system/lnd-channel-backup-archive.service
```

Paste the following contents

```ini
[Service]
WorkingDirectory=/home/bitcoin/backups/lnd
ExecStart=/bin/sh -c '/home/bitcoin/backups/lnd/lnd-channel-backup-archive.sh doloop'
Restart=always
RestartSec=1
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=backup-channels
User=bitcoin
Group=bitcoin

[Install]
WantedBy=multi-user.target
```

Press CTRL+O to save, and CTRL+X to exit nano.

## Start up the service

```sh
sudo systemctl start lnd-channel-backup-archive
```

## Review the logs 

This is to ensure it had no configuration errors preventing startup

```sh
journalctl -fu lnd-channel-backup-archive
```

Press CTRL+C to stop the logging

## Test 

Test the script by touching the channel.backup file

```sh
sudo touch /home/bitcoin/.lnd/data/chain/bitcoin/mainnet/channel.backup
```
## Second Review

Check the journal again to verify that the script successfully saw the change and uploaded to dropbox

```sh
journalctl -fu lnd-channel-backup-archive
```

Output should look somethig like this

![Screenshot from 2021-04-11 22-50-19](https://user-images.githubusercontent.com/14304023/114334338-5c00aa80-9b18-11eb-8559-efdb7e38cd14.png)

Press CTRL+C to stop the logging

And you can also verify in your Dropbox Account that a copy was uploaded in the App folder

![Screenshot from 2021-04-11 22-53-27](https://user-images.githubusercontent.com/14304023/114334565-cb769a00-9b18-11eb-9f74-f45e8ed491be.png)



