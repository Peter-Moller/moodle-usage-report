# moodle-usage-report

**moodle-usage-report** is a lightweight reporting tool designed to give teachers a clear, daily overview of user activity on a Moodle server. It extracts and summarizes log data using SQL and Bash, and publishes the results to a remote server in a human-readable format.

---

## ✨ Features

- Tracks user activity per course and role
- Publishes daily reports with one line per day
- Designed for Moodle servers running in Docker
- Minimal dependencies: just `bash` and `SQL`
- Easy to automate via `cron`
- Output can be integrated into dashboards or shared via web

---

## 📸 Example Output

_A sample screenshot will be added here._

![Screendump of report](moodle-usage-report_example_sm.png)

---

## ⚙️  Requirements

- Bash (tested with Bash 5+)
- Access to Moodle's SQL database
- SSH access to the report publishing server
- Moodle with logging enabled (`mdl_logstore_standard_log`)

---

## 📦 Deployment Notes

- Works best on Moodle servers running in Docker.
- The report is written to a remote server via SSH and updated daily.
- Each report file contains one line per day, updated hourly.

---

## 🛠️ Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/peter-moller/moodle-usage-report.git
   cd moodle-usage-report
   ```
2. Create a settings-file, `~/.moodle_usage_report.settings` containing the following items:
   ```bash
   box_h_bgc=22458a
   box_h_c=white
   DB_DockerName=moodledb
   DB_PASSWORD=SuperSecretPassword
   DB_User=username
   jobe_th_bgc=22458a
   jobe_th_c=white
   ReportHead=https://fileadmin.cs.lth.se/intern/backup/custom_report_head.html
   ServerName=moodle.example.dns
   SCP_HOST=web-server.some.dns
   SCP_DIR=/some/dir/moodle
   SCP_USER=remoteuser
   ```

3. Set up `cron` to run the project, i.e. `/etc/cron.d/moodle` (or something similar) with the following:
   ```bash
   0 * * * * root [ -x /path/to/moodle-usage-report/report.sh ] && /path/to/moodle-usage-report/report.sh >> /var/log/moodle-usage-report.log 2>&1
   ```
