# moodle-usage-report

**moodle-usage-report** is a lightweight reporting tool designed to give teachers a clear, daily overview of user activity on a Moodle server. It extracts and summarizes log data using SQL and Bash, and publishes the results to a remote server in a human-readable format.

---

## 📄 License

This project is licensed under the 2-clause BSD License — see [LICENSE]or details.

---

## ✨ Features

- Tracks user activity per course and role
- Publishes daily reports with one line per day
- Supports Moodle servers running in Docker
- Minimal dependencies: just `bash` and `SQL`
- Easy to automate via `cron`
- Output can be integrated into dashboards or shared via web
- If a user want to hide one or more courses in the printout, write the course id (numerical value) into the settings variable `COURSE_ID_TO_HIDE` as a comma-separated list
- If local processing needs to be done on the material, an external script can be specified in the `LOCAL_PROCESSING` settings variable. (We use this to feed our departmental monitoring system with data from this script). This is done by using `source` and thus all variables in this script may be used by the extension
- Columns can be sorted by clicking the column headers
- Courses can be searched
- Maintains a textfile with the total number of users per day

---

## 📸 Example Output

![Screendump of report](moodle-usage-report_example_sm.png)

---

## ⚙️  Requirements

- Bash (tested with Bash 5+)
- Access to Moodle's SQL database (tested with Moodle 4.5)
- SSH access to the report publishing server
- Moodle with logging enabled (`mdl_logstore_standard_log`)

---

## 📦 Deployment Notes

- Can be extended with local script (running as same user, so use it wisely).
- The report is written to a remote server via SSH and updated daily.
- Each report file contains one line per day, updated hourly.

---

## 🛠️ Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/peter-moller/moodle-usage-report.git
   cd moodle-usage-report
   ```
2. Create a settings-file, `~/.moodle_usage_report.settings` containing the following items (customise to your local need):
   ```bash
   box_h_bgc=22458a
   box_h_c=white
   COURSE_ID_TO_HIDE="1234, 102"
   DB_COMMAND="docker exec moodledb /usr/bin/mariadb"
   DB_PASSWORD=SuperSecretPassword
   DB_User=username
   jobe_th_bgc=22458a
   jobe_th_c=white
   LOCAL_PROCESSING="/some/path/to/script"
   ReportHead=https://fileadmin.cs.lth.se/intern/backup/custom_report_head_sorting.html
   ServerName=moodle.example.dns
   SCP_HOST=web-server.some.dns
   SCP_DIR=/some/dir/moodle
   SCP_USER=remoteuser
   ```

3. Set up `cron` to run the project, i.e. `/etc/cron.d/moodle` (or something similar) with the following:
   ```bash
   0 * * * * root [ -x /path/to/moodle-usage-report/report.sh ] && /path/to/moodle-usage-report/report.sh >> /var/log/moodle-usage-report.log 2>&1
   ```
