#!/bin/bash
# Script to create a simple, yet useful, report of usage in a moodle server
# The information is presented on a web server and it’s assumed to be updated 
# every hour, on the hour
# Also, a directory (with the current year as name) contains a file each of the courses is maintained.
# The filename use the course shortname as file name, slightly edited to avoid filenames that will cause problems.
# These files contain a number of rows, one per day (YYYY-MM-DD) and the numbers of users that have been active
# in the course during the day. This line is updated (replaced with new values) during the day.

source ~/.moodle_usage_report.settings
CSS_colorfix="s/jobe_th_bgc/$jobe_th_bgc/g;s/jobe_th_c/$jobe_th_c/g;s/box_h_bgc/$box_h_bgc/g;s/box_h_c/$box_h_c/g"
NL=$'\n'
TitleString="Moodle usage report for “$ServerName” on $(date +%F" "+%T)"
export LC_ALL=en_US.UTF-8
LinkReferer='target="_blank" rel="noopener noreferrer"'

# Determine if the run time is 00:00. 
# If so, we must have a different SQL question and present slightly different text
if [ $(date +%H) -eq 0 ]; then
    SQL_TIME="UNIX_TIMESTAMP() - 86400"
    DayText="during $(date +%F -d '1 day ago')"
    DayTurn=true
    TODAY=$(date +%F -d'1 day ago')    # Ex: TODAY=2025-06-25
    THIS_YEAR=$(date +%G -d'1 day ago') 
else
    SQL_TIME="UNIX_TIMESTAMP(CURDATE())"
    DayText="since midnight today"
    DayTurn="false"
    TODAY=$(date +%F)                  # Ex: TODAY=2025-06-26
    THIS_YEAR=$(date +%G)              # Ex: THIS_YEAR=2025
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#   _____   _____    ___   ______   _____       _____  ______     ______   _   _   _   _   _____   _____   _____   _____   _   _   _____
#  /  ___| |_   _|  / _ \  | ___ \ |_   _|     |  _  | |  ___|    |  ___| | | | | | \ | | /  __ \ |_   _| |_   _| |  _  | | \ | | /  ___|
#  \ `--.    | |   / /_\ \ | |_/ /   | |       | | | | | |_       | |_    | | | | |  \| | | /  \/   | |     | |   | | | | |  \| | \ `--.
#   `--. \   | |   |  _  | |    /    | |       | | | | |  _|      |  _|   | | | | | . ` | | |       | |     | |   | | | | | . ` |  `--. \
#  /\__/ /   | |   | | | | | |\ \    | |       \ \_/ / | |        | |     | |_| | | |\  | | \__/\   | |    _| |_  \ \_/ / | |\  | /\__/ /
#  \____/    \_/   \_| |_/ \_| \_|   \_/        \___/  \_|        \_|      \___/  \_| \_/  \____/   \_/    \___/   \___/  \_| \_/ \____/


################################################################################
# Create a report from the Moodle Database
# Globals:
#   SQL_TIME
# From Settings-file:
#   DB_DockerName, DB_User, DB_PASSWORD
# Arguments:
#   None
# Outputs:
#   Produces 'TableText', a multi-line variable containing the 
#   output from the database
################################################################################
get_sql_data() {
    # Get the number of active people today:
    MoodleActiveUsersToday="$(docker exec $DB_DockerName /usr/bin/mariadb -u$DB_User -p"$DB_PASSWORD" -NB -e "USE moodle; SELECT COUNT(*) FROM mdl_user WHERE lastaccess > $SQL_TIME" 2>/dev/null)"  # Ex: MoodleActiveUsersToday=116

    SQLQ="USE moodle;WITH active_people AS (
      SELECT 
        u.username,
        u.firstname,
        u.lastname,
        u.email,
        FROM_UNIXTIME(u.lastaccess + 7200, '%Y-%m-%d %H:%i:%s') AS \`Time\`,
        r.shortname AS ROLE,
        c.fullname AS \`active course\`,
        c.shortname AS course_shortname,
        c.id AS course_id
      FROM 
        mdl_user u
      JOIN 
        mdl_logstore_standard_log l ON l.userid = u.id
      JOIN 
        mdl_course c ON c.id = l.courseid
      JOIN 
        mdl_context ctx ON ctx.instanceid = c.id AND ctx.contextlevel = 50
      JOIN 
        mdl_role_assignments ra ON ra.userid = u.id AND ra.contextid = ctx.id
      JOIN 
        mdl_role r ON r.id = ra.roleid
      WHERE 
        l.timecreated > $SQL_TIME
      GROUP BY 
        u.id, c.id, r.id
    ),
    enrolled_students AS (
      SELECT 
        c.id AS course_id,
        COUNT(DISTINCT u.id) AS total_students
      FROM 
        mdl_role_assignments ra
      JOIN 
        mdl_user u ON u.id = ra.userid
      JOIN 
        mdl_context ctx ON ctx.id = ra.contextid AND ctx.contextlevel = 50
      JOIN 
        mdl_course c ON c.id = ctx.instanceid
      WHERE 
        ra.roleid = 5  -- student role
      GROUP BY 
        c.id
    )
    SELECT 
      ap.ROLE, 
      ap.\`active course\`, 
      ap.course_shortname,
      ap.course_id,
      es.total_students,
      COUNT(*) AS active_user_count
    FROM 
      active_people ap
    LEFT JOIN 
      enrolled_students es ON ap.course_id = es.course_id
    GROUP BY 
      ap.ROLE, ap.\`active course\`, ap.course_shortname, ap.course_id, es.total_students
    ORDER BY 
      ap.\`active course\`, ap.ROLE;"

    TableText="$(docker exec $DB_DockerName /usr/bin/mariadb -u$DB_User -p$DB_PASSWORD -NB -e "$SQLQ" | tail -n +2)"
    # Ex:
    # TableText='editingteacher	EDAA01 Programmeringsteknik fördjupningskurs sommar 2025	EDAA01 sommar25	1103	358	1
    #            student	EDAA01 Programmeringsteknik fördjupningskurs sommar 2025	EDAA01 sommar25	1103	358	68
    #            editingteacher	EDAA01/TFRD49 Programmeringsteknik fördjupningskurs VT 2025	EDAA01/TFRD49 VT25	1082	489	1
    #            student	TFRD90 Design och kognitiv tillgänglighet (HT23)	Design och kognitiv tillgänglighet (HT23)	1057	33	1'

}

################################################################################
# Create a HTML-table element based and
# create/maintain a file for the specific course
# Globals:
#   TableText
# From Settings-file:
#   None
# Arguments:
#   None
# Outputs:
#   Writes the table to a temp file, 'TableHTMLFile'
################################################################################
generate_html_table() {
    TableHTMLFile=$(mktemp /tmp/.moodle_table_report.XXXX)
    echo "$TableText" | while IFS=$'\t' read -r role course shortname id enrolled count
    do
        if [ "$role" = "student" ]; then
        MyShortname="$(echo "$shortname" | sed 's:[ /]:_:g; s/[åä]/a/g; s/ö/o/g')"                      # Ex: MyShortname=EDAA10_-_HT24_-_Hbg
        #ssh ${SCP_USER}@${SCP_HOST} -t "echo \"$TODAY   $count\" >> ${SCP_DIR}/$THIS_YEAR/${MyShortname}.txt"
        ssh "${SCP_USER}@${SCP_HOST}" > /dev/null 2>&1 << EOF
            FILE="${SCP_DIR}/${THIS_YEAR}/${MyShortname}.txt"
            if [ ! -f "\$FILE" ]; then
                echo -e "${TODAY}  $count" > "\$FILE"
            else
                if grep -q "^${TODAY}" "\$FILE"; then
                    sed -i "/^${TODAY}/c\\${TODAY}  $count" "\$FILE"
                else
                    echo -e "${TODAY}  $count" >> "\$FILE"
                fi
            fi
EOF
        fi
        CourseFullNameCell="<a href=\"https://$ServerName/course/view.php?id=$id\" $LinkReferer>$course</a>"
        CourseShortNameCell="<a href=\"$THIS_YEAR/${MyShortname}.txt\" $LinkReferer>$shortname</a>"
        echo "          <tr><td align=\"left\">$CourseFullNameCell</td><td align=\"left\">$CourseShortNameCell</td><td align=\"left\">$role</td><td align=\"right\">$count</td><td align=\"right\">$enrolled</td></tr>" >> $TableHTMLFile
    done

    # Ex:
    # TableHTML='#          <tr><td align="left"><a href="https://moodle.cs.lth.se/course/view.php?id=1029" target="_blank" rel="noopener noreferrer">EDAP10 Flertrådad programmering 2024</a></td><td align="left"><a href="2025/edap10-ht24.txt" target="_blank" rel="noopener noreferrer">edap10-ht24</a></td><td align="left">student</td><td align="right">1</td><td align="right">489</td></tr>
    #                       <tr><td align="left"><a href="https://moodle.cs.lth.se/course/view.php?id=1108" target="_blank" rel="noopener noreferrer">EDAP10 Flertrådad programmering 2025</a></td><td align="left"><a href="2025/edap10-ht25.txt" target="_blank" rel="noopener noreferrer">edap10-ht25</a></td><td align="left">student</td><td align="right">3</td><td align="right">68</td></tr>
    #                       <tr><td align="left"><a href="https://moodle.cs.lth.se/course/view.php?id=1035" target="_blank" rel="noopener noreferrer">Java grundkurs</a></td><td align="left"><a href="2025/open_java.txt" target="_blank" rel="noopener noreferrer">open_java</a></td><td align="left">student</td><td align="right">2</td><td align="right">185</td></tr>


}

################################################################################
# Create the HTML page
# Globals:
#   TitleString, CSS_colorfix, TableHTMLFile
# From Settings-file:
#   ReportHead
# Arguments:
#   None
# Outputs:
#   Writes the completed file to a temp file, 'MoodleReportTemp'
################################################################################
assemble_web_page() {
    MoodleReportTemp=$(mktemp /tmp/moodle_report.XXXX)
    # Get the head of the custom report, replace SERVER and DATE
    curl --silent $ReportHead | sed "s/TITLE/$TitleString/;$CSS_colorfix;s/Backup/SQL/;s/1200/1250/" >> "$MoodleReportTemp"
    # Only continue if it worked
    if grep "Moodle usage report for" "$MoodleReportTemp" &>/dev/null ; then
        echo "<body>" >> "$MoodleReportTemp"
        echo '<div class="main_page">' >> "$MoodleReportTemp"
        echo '  <div class="flexbox-container">' >> "$MoodleReportTemp"
        echo '    <div id="box-header">' >> "$MoodleReportTemp"
        echo "      <h3>Moodle usage report for</h3>" >> "$MoodleReportTemp"
        echo "      <h1>$ServerName</h1>" >> "$MoodleReportTemp"
        echo "      <h4>$(date "+%Y-%m-%d %R")</h4>" >> "$MoodleReportTemp"
        echo "    </div>" >> "$MoodleReportTemp"
        echo "  </div>" >> "$MoodleReportTemp"
        echo "  <section>" >> "$MoodleReportTemp"
        echo "    <p>&nbsp;</p>" >> "$MoodleReportTemp"
        #echo "    <p align=\"left\"> Report generated by script: <code>${ScriptFullName}</code><br>" >> "$MoodleReportTemp"
        #echo "      Script launched $ScriptLaunchText by: <code>${ScriptLauncher:---no launcher detected--}</code> </p>" >> "$MoodleReportTemp"
        #echo '    <p align="left">&nbsp;</p>' >> "$MoodleReportTemp"
        echo '    <p align="left">&nbsp;</p>' >> "$MoodleReportTemp"
        echo '    <p align="left">&nbsp;</p>' >> "$MoodleReportTemp"
        echo '    <p align="left">Below is a presentation of a <code>SQL</code>-question put to the moodle database that aggregates the numbers of various roles that have been active in the moodle server '$DayText'.</p>' >> "$MoodleReportTemp"
        echo '    <p align="left">&nbsp;</p>' >> "$MoodleReportTemp"
        echo '    <p align="left">In total, <strong>'$MoodleActiveUsersToday'</strong> individuals have logged in to '$ServerName' '$DayText'. </p>' >> "$MoodleReportTemp"
        echo '    <p align="left">&nbsp;</p>' >> "$MoodleReportTemp"
	    echo '    <p align="left">The “Course fullname”-link goes to the specific course page on moodle and the “Course shortname”-link goes to a local file, containing a running daily count of users on that course. The table is sorted alphabetically by “Course fullname” and it, and the individual pages, are updated every hour, on the hour.</p>' >> "$MoodleReportTemp"
        echo '    <p align="left">&nbsp;</p>' >> "$MoodleReportTemp"
        echo '    <table id="jobe">' >> "$MoodleReportTemp"
        echo '      <tbody>' >> "$MoodleReportTemp"
        echo '          <tr><th>Course fullname</th><th>Course shortname</th><th>Role</th><th align="right">Count</th><th align="right">Enrolled</th></tr>' >> "$MoodleReportTemp"
        cat "$TableHTMLFile" >> "$MoodleReportTemp"
        echo '      </tbody>' >> "$MoodleReportTemp"
        echo '    </table>' >> "$MoodleReportTemp"
        echo '' >> "$MoodleReportTemp"
        echo "  </section>" >> "$MoodleReportTemp"
        echo '  <p align="center"><em>Report generated by &#8220;moodle-usage-report&#8221; (<a href="https://github.com/Peter-Moller/moodle-usage-report" '$LinkReferer'>GitHub</a> <span class="glyphicon">&#xe164;</span>)</em></p>' >> "$MoodleReportTemp"
        echo '  <p align="center"><em>Department of Computer Science, LTH/LU</em></p>' >> "$MoodleReportTemp"
        echo "</div>" >> "$MoodleReportTemp"
        echo "</body>" >> "$MoodleReportTemp"
        echo "</html>" >> "$MoodleReportTemp"
    else
        echo "<body>" >> "$MoodleReportTemp"
        echo "<h1>Could not get $ReportHead!!</h1>"
        echo "</body>" >> "$MoodleReportTemp"
        echo "</html>" >> "$MoodleReportTemp"
    fi

}

################################################################################
# Copy the HTML-file to remote server
# Globals:
#   MoodleReportTemp
# From Settings-file:
#   SCP_USER, SCP_HOST, SCP_DIR
# Arguments:
#   None
# Outputs:
#   Nothing
################################################################################
copy_result() {
    scp "${MoodleReportTemp}" "${SCP_USER}@${SCP_HOST}:${SCP_DIR}/index.html" &>/dev/null
}

#   _____   _   _  ______       _____  ______     ______   _   _   _   _   _____   _____   _____   _____   _   _   _____
#  |  ___| | \ | | |  _  \     |  _  | |  ___|    |  ___| | | | | | \ | | /  __ \ |_   _| |_   _| |  _  | | \ | | /  ___|
#  | |__   |  \| | | | | |     | | | | | |_       | |_    | | | | |  \| | | /  \/   | |     | |   | | | | |  \| | \ `--.
#  |  __|  | . ` | | | | |     | | | | |  _|      |  _|   | | | | | . ` | | |       | |     | |   | | | | | . ` |  `--. \
#  | |___  | |\  | | |/ /      \ \_/ / | |        | |     | |_| | | |\  | | \__/\   | |    _| |_  \ \_/ / | |\  | /\__/ /
#  \____/  \_| \_/ |___/        \___/  \_|        \_|      \___/  \_| \_/  \____/   \_/    \___/   \___/  \_| \_/ \____/
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


get_sql_data
generate_html_table
assemble_web_page
copy_result
