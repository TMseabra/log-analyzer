# log-analyzer

A small Bash tool that reads a Linux authentication log and tells you who has been trying to get into your server over SSH.

It turns thousands of raw `sshd` lines into a short report: how many logins failed, which IP addresses and usernames were tried most, who actually logged in, and which days were the busiest.

## Features

- Counts failed passwords, invalid users and accepted logins
- Top IP addresses with failed logins
- Most-tried usernames (`root`, `admin`, `ubuntu`, ...)
- Successful logins grouped by user and source IP
- Failed logins per day
- Supports both classic syslog timestamps (`Oct 11 08:15:31`) and ISO timestamps (`2026-10-11T08:15:31`)
- Colored output in a terminal, plain text when piped or redirected
- No dependencies beyond standard tools (`bash`, `grep`, `sed`, `awk`, `sort`, `uniq`)

## Requirements

- Linux or macOS with Bash 4+
- Read access to the log file (usually needs `sudo`)

## Installation

```bash
git clone https://github.com/TMseabra/log-analyzer.git
cd log-analyzer
chmod +x log-analyzer.sh
```

## Usage

```bash
# Analyze the default log (/var/log/auth.log)
sudo ./log-analyzer.sh

# Analyze another file and show the top 5 of each list
./log-analyzer.sh -f /var/log/secure -n 5

# Save the report to a file
sudo ./log-analyzer.sh > report.txt
```

### Options

| Option    | Description                                         | Default             |
|-----------|-----------------------------------------------------|---------------------|
| `-f FILE` | Log file to analyze                                 | `/var/log/auth.log` |
| `-n NUM`  | Number of entries shown in each top list            | `10`                |
| `-h`      | Show help and exit                                  |                     |
| `-v`      | Show version and exit                               |                     |

> On Debian/Ubuntu the SSH log is `/var/log/auth.log`. On RHEL, Fedora and CentOS it is `/var/log/secure`.

## Try it with the sample log

The repo includes a fake log so you can test the tool without touching real data:

```bash
./log-analyzer.sh -f samples/auth.log.sample -n 5
```

Output:

```text
SSH log analysis - samples/auth.log.sample

Summary
  Failed passwords : 14
  Invalid users    : 4
  Accepted logins  : 3

Top 5 IPs with failed logins
  6      203.0.113.45
  5      198.51.100.23
  1      203.0.113.99
  1      198.51.100.77
  1      192.0.2.55

Top 5 usernames tried
  7      root
  2      admin
  1      ubuntu
  1      tomas
  1      test

Successful logins (user from IP)
  3      tomas from 192.0.2.10

Failed logins per day
  8      Oct 11
  6      Oct 10
```

All IP addresses in the sample come from the documentation ranges reserved by RFC 5737, so they never point to real machines.

## How it works

The script is a pipeline of classic Unix tools:

1. `grep` selects the relevant lines (`Failed password`, `Invalid user`, `Accepted`)
2. `sed` extracts the field of interest (IP address or username) with a regular expression
3. `sort | uniq -c | sort -rn` counts and ranks the values
4. `head` keeps the top N and `awk` formats the columns

## Security notes

- The tool is **read-only**: it never modifies logs or system settings.
- Real log files contain IP addresses and usernames. The `.gitignore` blocks `*.log` files so you do not publish them by accident.
- A high number of failed logins is normal for any server exposed to the internet. If you see a lot, consider key-only authentication, `fail2ban` and a firewall (`ufw`).

## Roadmap

- [ ] Support `journalctl -u ssh` as an input source
- [ ] Export the report as JSON or CSV
- [ ] Filter by date range
- [ ] Optional `--ban-list` output with the worst offending IPs
- [ ] GeoIP lookup for the top IPs

## License

Released under the [MIT License](LICENSE).

## Author

Made by Tomás Seabra as part of a Linux and scripting learning project.
