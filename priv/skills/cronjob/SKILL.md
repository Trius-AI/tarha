---
description: Manage cronjobs and scheduled tasks on Unix/Linux systems
always: false
requires:
  bins: [crontab]
  env: []
---

# Cronjob Skill

Use this skill to manage cronjobs (scheduled tasks) on Unix/Linux systems.

## Overview

Cron is a time-based job scheduler in Unix-like systems. It enables users to schedule jobs (commands or scripts) to run periodically at fixed times, dates, or intervals.

## Basic Commands

### List current crontab

```bash
crontab -l    # List current user's crontab
crontab -l -u username    # List another user's crontab (requires sudo)
```

### Edit crontab

```bash
crontab -e    # Edit current user's crontab
crontab -e -u username    # Edit another user's crontab (requires sudo)
```

### Remove crontab

```bash
crontab -r    # Remove current user's crontab
crontab -r -u username    # Remove another user's crontab
```

## Cron Syntax

```
┌───────────── minute (0 - 59)
│ ┌───────────── hour (0 - 23)
│ │ ┌───────────── day of month (1 - 31)
│ │ │ ┌───────────── month (1 - 12)
│ │ │ │ ┌───────────── day of week (0 - 6) (Sunday = 0)
│ │ │ │ │
* * * * * command_to_run
```

### Special Characters

| Character | Meaning |
|-----------|---------|
| `*` | Any value (every minute/hour/etc.) |
| `,` | Value list separator (e.g., `1,3,5`) |
| `-` | Range (e.g., `1-5` for days 1 through 5) |
| `/` | Step (e.g., `*/5` for every 5 minutes) |

### Examples

```bash
# Every minute
* * * * * /path/to/script.sh

# Every hour at minute 0
0 * * * * /path/to/script.sh

# Every day at 2:30 AM
30 2 * * * /path/to/script.sh

# Every Monday at 9:00 AM
0 9 * * 1 /path/to/script.sh

# Every 15 minutes
*/15 * * * * /path/to/script.sh

# First day of every month at midnight
0 0 1 * * /path/to/script.sh

# Weekdays (Mon-Fri) at 6:30 PM
30 18 * * 1-5 /path/to/script.sh

# Multiple times (8 AM and 8 PM)
0 8,20 * * * /path/to/script.sh

# Range: every hour from 9 AM to 5 PM
0 9-17 * * * /path/to/script.sh
```

## Special Strings

Some cron implementations support special strings:

| String | Equivalent | Description |
|--------|------------|-------------|
| `@yearly` | `0 0 1 1 *` | Once a year (Jan 1, midnight) |
| `@annually` | `0 0 1 1 *` | Same as @yearly |
| `@monthly` | `0 0 1 * *` | Once a month (1st, midnight) |
| `@weekly` | `0 0 * * 0` | Once a week (Sunday, midnight) |
| `@daily` | `0 0 * * *` | Once a day (midnight) |
| `@hourly` | `0 * * * *` | Once an hour |
| `@reboot` | - | Run at startup |

## Environment Variables

Cron jobs run in a limited environment. Set these in the crontab:

```bash
# Set PATH
PATH=/usr/local/bin:/usr/bin:/bin

# Set shell
SHELL=/bin/bash

# Set home directory
HOME=/home/user

# Email output (requires mail setup)
MAILTO=user@example.com

# Then add your jobs
0 * * * * /home/user/scripts/backup.sh
```

## Output Handling

By default, cron sends output via email. Redirect output:

```bash
# Discard all output
* * * * * /path/to/script.sh > /dev/null 2>&1

# Log to file
* * * * * /path/to/script.sh >> /var/log/script.log 2>&1

# Only log errors
* * * * * /path/to/script.sh > /dev/null 2>> /var/log/script_errors.log
```

## System-wide Cron Directories

| Directory | Description |
|-----------|-------------|
| `/etc/crontab` | System crontab (requires user field) |
| `/etc/cron.d/` | Drop-in cron files |
| `/etc/cron.daily/` | Scripts run daily |
| `/etc/cron.hourly/` | Scripts run hourly |
| `/etc/cron.weekly/` | Scripts run weekly |
| `/etc/cron.monthly/` | Scripts run monthly |

## Common Use Cases

### Backup script daily at midnight

```bash
0 0 * * * /home/user/scripts/backup.sh >> /var/log/backup.log 2>&1
```

### Clean temp files weekly

```bash
0 0 * * 0 find /tmp -type f -mtime +7 -delete
```

### Monitor disk space every 5 minutes

```bash
*/5 * * * * df -h | mail -s "Disk Usage Report" admin@example.com
```

### Renew SSL certificate monthly

```bash
0 0 1 * * certbot renew --quiet
```

### Sync files every hour

```bash
0 * * * * rsync -av /source/ /backup/ >> /var/log/rsync.log 2>&1
```

### Run Python script

```bash
*/30 * * * * cd /home/user/project && /usr/bin/python3 script.py
```

## Environment Tips

1. **Use full paths**: Cron has a limited PATH. Always use full paths:
   ```bash
   /usr/bin/python3 /home/user/script.py
   ```

2. **Set working directory**: Jobs run in the user's home directory:
   ```bash
   cd /path/to/project && ./script.sh
   ```

3. **Source profile for environment**:
   ```bash
   * * * * * /bin/bash -c 'source ~/.bashrc && command'
   ```

4. **Check cron logs**:
   ```bash
   # Debian/Ubuntu
   grep CRON /var/log/syslog
   
   # RHEL/CentOS
   grep CRON /var/log/cron
   ```

5. **Test cron syntax online**: Use https://crontab.guru to validate expressions

## Using the run_background Tool

When creating scheduled tasks, you can use the `run_background` tool to start long-running processes. However, for true persistence across reboots, use cron:

```bash
# Add to crontab with -e flag
crontab -e
```

## Common Issues

| Issue | Solution |
|-------|----------|
| Command not found | Use full path: `/usr/bin/command` |
| Permission denied | Check file permissions: `chmod +x script.sh` |
| Environment variables missing | Set PATH and other vars in crontab |
| No output | Check MAILTO or redirect to log file |
| Script works manually but not in cron | Use full paths and set environment |

## Crontab File Format

```
# Minute Hour Day Month Weekday Command
# ========================================
  0      2    *     *      *     /path/to/backup.sh
  */5    *    *     *      *     /path/to/check.sh
  30     9    1-5   *      *     /path/to/weekday.sh
```

## Viewing Active Jobs

```bash
# Show all cron jobs for current user
crontab -l

# Show all system cron jobs
ls -la /etc/cron.d/

# Show user's cron jobs (root only)
crontab -l -u username
```

## Best Practices

1. **Use comments**: Document each job with a comment above it
2. **Log output**: Always redirect output to log files
3. **Use full paths**: Avoid path-related failures
4. **Test first**: Run command manually before adding to cron
5. **Lock files**: Prevent overlapping runs with lock files
6. **Monitor**: Set up alerts for failed jobs
7. **Time zones**: cron uses system timezone; verify with `date`
8. **Avoid peak times**: Don't schedule heavy jobs at common times (minute 0)