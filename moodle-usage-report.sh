#!/bin/bash
# Script to create a simple, yet useful, report of usage in a moodle server
# The information is presented on a web server and it’s assumed to be updated 
# every hour, on the hour
# Also, a directory (with the current year as name) contains a file each of the courses is maintained.
# The filename use the course shortname as file name, slightly edited to avoid filenames that will cause problems.
# These files contain a number of rows, one per day (YYYY-MM-DD) and the numbers of users that have been active
# in the course during the day. This line is updated (replaced with new values) during the day.

source ~/.moodle_usage_report.settings
CSS_COLORFIX="s/JOBE_TH_BGC/$BLUE/g; s/JOBE_TH_C/$JOBE_TH_C/g; s/BOX_H_BGC/$BLUE/g; s/BOX_H_C/$BOX_H_C/g; s/ORANGE/$ORANGE/; s/JOBE_TH_SORTED_BGC/$JOBE_TH_SORTED_BGC/"
# Ex: CSS_COLORFIX='s/JOBE_TH_BGC/#22458a/g; s/JOBE_TH_C/white/g; s/BOX_H_BGC/#22458a/g; s/BOX_H_C/white/g; s/ORANGE/#F9A510/; s/JOBE_TH_SORTED_BGC/#2A55AC/'
NL=$'\n'
TITLE_STRING="Moodle usage report for “$SERVER_NAME” on $(date +%F" "+%T)"
export LC_ALL=en_US.UTF-8
LINKREFERER='target="_blank" rel="noopener noreferrer"'
BASIC_DATA_FILE='/tmp/.basic_moodle_data'

# Determine if the run time is 00:00. 
# If so, we must have a different SQL question and present slightly different text
if [ $(date +%H) -eq 0 ]; then
    SQL_TIME="UNIX_TIMESTAMP() - 86400"
    DayText="during $(date +%F -d '1 day ago')"
    DayTurn=true
    TODAY=$(date +%F -d'1 day ago')              # Ex: TODAY=2025-06-25
    DAYNAME="$(date +%A -d'1 day ago')"          # Ex: DAYNAME=Sunday
    THIS_YEAR=$(date +%G -d'1 day ago') 
else
    SQL_TIME="UNIX_TIMESTAMP(CURDATE())"
    DayText="since midnight today"
    DayTurn="false"
    TODAY=$(date +%F)                            # Ex: TODAY=2025-06-26
    THIS_YEAR=$(date +%G)                        # Ex: THIS_YEAR=2025
    DAYNAME="$(date +%A)"                        # Ex: DAYNAME=Monday
fi
DailySummaryFile="$LOCAL_DIR/DAILY_SUMMARIES_$THIS_YEAR.txt"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#   _____   _____    ___   ______   _____       _____  ______     ______   _   _   _   _   _____   _____   _____   _____   _   _   _____
#  /  ___| |_   _|  / _ \  | ___ \ |_   _|     |  _  | |  ___|    |  ___| | | | | | \ | | /  __ \ |_   _| |_   _| |  _  | | \ | | /  ___|
#  \ `--.    | |   / /_\ \ | |_/ /   | |       | | | | | |_       | |_    | | | | |  \| | | /  \/   | |     | |   | | | | |  \| | \ `--.
#   `--. \   | |   |  _  | |    /    | |       | | | | |  _|      |  _|   | | | | | . ` | | |       | |     | |   | | | | | . ` |  `--. \
#  /\__/ /   | |   | | | | | |\ \    | |       \ \_/ / | |        | |     | |_| | | |\  | | \__/\   | |    _| |_  \ \_/ / | |\  | /\__/ /
#  \____/    \_/   \_| |_/ \_| \_|   \_/        \___/  \_|        \_|      \___/  \_| \_/  \____/   \_/    \___/   \___/  \_| \_/ \____/
#


################################################################################
# Make sure all directories are created
# Globals:
#   THIS_YEAR
# From Settings-file:
#   LOCAL_DIR
# Arguments:
#   None
# Outputs:
#   Nothing
################################################################################
check_directories() {
    if [ ! -d "$LOCAL_DIR/$THIS_YEAR" ]; then
        mkdir -p "$LOCAL_DIR/$THIS_YEAR"
    fi
}


################################################################################
# Get basic data about moodle
# Globals:
#   THIS_YEAR
# From Settings-file:
#   DB_COMMAND, DB_DockerName, DB_User, DB_PASSWORD
# Arguments:
#   None
# Outputs:
#   Nothing
################################################################################
get_basic_moodle_data() {
    if [ "$DayTurn" = "true" ] || [ ! -f "$BASIC_DATA_FILE" ]; then
        MoodleRelease=$($DB_COMMAND -u$DB_USER -p"$DB_PASSWORD" -NB -e "USE moodle; SELECT VALUE FROM mdl_config WHERE name = 'release'" | awk '{print $1}')      # Ex: MoodleRelease=4.5.5
        echo "MoodleRelease	$MoodleRelease" > $BASIC_DATA_FILE
        MoodleUsersTotal=$($DB_COMMAND -u$DB_USER -p"$DB_PASSWORD" -NB -e "USE moodle; SELECT COUNT(*) FROM mdl_user")                                            # Ex: MoodleUsersTotal=12812
        echo "MoodleUsersTotal	$MoodleUsersTotal" >> $BASIC_DATA_FILE
        MoodleUsersNotDeleted=$($DB_COMMAND -u$DB_USER -p"$DB_PASSWORD" -NB -e "USE moodle; SELECT COUNT(*) FROM mdl_user WHERE deleted = 0")                     # Ex: MoodleUsersNotDeleted=9518
        echo "MoodleUsersNotDeleted	$MoodleUsersNotDeleted" >> $BASIC_DATA_FILE
        MoodleUsersDeleted=$($DB_COMMAND -u$DB_USER -p"$DB_PASSWORD" -NB -e "USE moodle; SELECT COUNT(*) FROM mdl_user WHERE deleted = 1")                        # Ex: MoodleUsersDeleted=3294
        echo "MoodleUsersDeleted	$MoodleUsersDeleted" >> $BASIC_DATA_FILE
        SQLUsers6mon="USE moodle; SELECT COUNT(*) FROM mdl_user WHERE lastaccess > UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 6 MONTH))"
        MoodleUsers6mon=$($DB_COMMAND -u$DB_USER -p"$DB_PASSWORD" -NB -e "$SQLUsers6mon")                                                                         # Ex: MoodleUsers6mon=3538
        echo "MoodleUsers6mon	$MoodleUsers6mon" >> $BASIC_DATA_FILE
        SQLUserRoles="USE moodle; SELECT r.shortname AS role, COUNT(DISTINCT ra.userid) AS user_count FROM mdl_role r JOIN mdl_role_assignments ra ON ra.roleid = r.id JOIN mdl_context ctx ON ctx.id = ra.contextid JOIN mdl_user u ON u.id = ra.userid WHERE u.deleted = 0   AND ctx.contextlevel = 10 GROUP BY r.shortname ORDER BY user_count DESC"
        MoodleUserRoles=$($DB_COMMAND -u$DB_USER -p"$DB_PASSWORD" -NB -e "$SQLUserRoles")
        # Ex: MoodleUserRoles='coursecreator	28
        #                      viewingteacher	23
        #                      questionsharer	9
        #                      manager	7'
        MoodleCourseCreators=$(echo "$MoodleUserRoles" | grep coursecreator | awk '{print $NF}')                                                                  # Ex: MoodleCourseCreators=28
        echo "MoodleCourseCreators	$MoodleCourseCreators" >> $BASIC_DATA_FILE
        MoodleManagers=$(echo "$MoodleUserRoles" | grep manager | awk '{print $NF}')                                                                              # Ex: MoodleManagers=7
        echo "MoodleManagers	$MoodleManagers" >> $BASIC_DATA_FILE
        SQLCourses6mon="USE moodle; SELECT COUNT(*) AS active_courses FROM mdl_course WHERE visible = 1 AND id != 1 AND startdate >= UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 6 MONTH)) AND (enddate = 0 OR enddate >= UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 6 MONTH)));"
        MoodleCourses6mon=$($DB_COMMAND -u$DB_USER -p"$DB_PASSWORD" -NB -e "$SQLCourses6mon")                                                                     # Ex: MoodleCourses6mon=31
        echo "MoodleCourses6mon	$MoodleCourses6mon" >> $BASIC_DATA_FILE
    else
        MoodleRelease="$(grep MoodleRelease $BASIC_DATA_FILE | awk '{print $NF}')"
        MoodleUsersNotDeleted=$(grep MoodleUsersNotDeleted $BASIC_DATA_FILE | awk '{print $NF}')
        MoodleUsers6mon=$(grep MoodleUsers6mon $BASIC_DATA_FILE | awk '{print $NF}')
        MoodleCourses6mon=$(grep MoodleCourses6mon $BASIC_DATA_FILE | awk '{print $NF}')
    fi
    MoodleMetaInfoString="The server runs Moodle version $MoodleRelease and <strong>$(printf "%'d" $MoodleUsers6mon)</strong> (out of $(printf "%'d" $MoodleUsersNotDeleted)) users have been active in <strong>$(printf "%'d" $MoodleCourses6mon)</strong> courses during the last 6 months."
}


################################################################################
# Create a report from the Moodle Database
# Globals:
#   SQL_TIME
# From Settings-file:
#   DB_COMMAND, DB_DockerName, DB_User, DB_PASSWORD
# Arguments:
#   None
# Outputs:
#   Produces 'TableText', a multi-line variable containing the 
#   output from the database
################################################################################
get_sql_data() {
    # Get the number of active people today:
    MoodleActiveUsersToday="$($DB_COMMAND -u$DB_USER -p"$DB_PASSWORD" -NB -e "USE moodle; SELECT COUNT(*) FROM mdl_user WHERE lastaccess > $SQL_TIME" 2>/dev/null)"  # Ex: MoodleActiveUsersToday=116

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

    TableTextRaw="$($DB_COMMAND -u$DB_USER -p$DB_PASSWORD -NB -e "$SQLQ" | tail -n +2)"
    # Ex:
    # TableTextRaw='editingteacher	EDAA01 Programmeringsteknik fördjupningskurs sommar 2025	EDAA01 sommar25	1103	358	1
    #               student	EDAA01 Programmeringsteknik fördjupningskurs sommar 2025	EDAA01 sommar25	1103	358	68
    #               editingteacher	EDAA01/TFRD49 Programmeringsteknik fördjupningskurs VT 2025	EDAA01/TFRD49 VT25	1082	489	1
    #               student	TFRD90 Design och kognitiv tillgänglighet (HT23)	Design och kognitiv tillgänglighet (HT23)	1057	33	1'
    
    # Filter out courses that should be hidden:
    if [ -n "$COURSE_ID_TO_HIDE" ]; then
        TableText="$(echo "$TableTextRaw" | grep -Ev "${COURSE_ID_TO_HIDE//[, ]/|}")"
    else
        TableText="$TableTextRaw"
    fi

    # If some extra processing is to be done (via 'LOCAL_PROCESSING'), do it here
    if [ -n "$LOCAL_PROCESSING" ] && [ -f "$LOCAL_PROCESSING" ]; then
        source "$LOCAL_PROCESSING"
    fi

    # Get the number of courses as well:
    NumCourses=$(echo "$TableText" | awk -F $'\t' '{print $2}' | sort -u | wc -l)        # Ex: NumCourses=28
    if [ $NumCourses -gt 5 ]; then
        local CourseText="and been active in <strong>$NumCourses</strong> courses "
    else
        local CourseText=""
    fi

    # Deal with no activity since midnight:
    if [ -n "$TableText" ]; then
        MoodleActivityText='In total, <strong>'$MoodleActiveUsersToday'</strong> individuals have logged in to '$SERVER_NAME' '$CourseText$DayText'. You can find a daily summary for '$THIS_YEAR' <a href="DAILY_SUMMARIES_'$THIS_YEAR'.txt" '$LINKREFERER'>here</a>.'
    else
        MoodleActivityText='No users have logged in to '$SERVER_NAME' since midnight. You can find a daily summary for '$THIS_YEAR' <a href="'$THIS_YEAR'/DAILY_SUMMARIES_'$THIS_YEAR'.txt" '$LINKREFERER'>here</a>.'
    fi
}


################################################################################
# Create a single course file
# Globals:
#   TODAY, count, MyShortname, THIS_YEAR
# From Settings-file:
#   LOCAL_DIR
# Arguments:
#   None
# Outputs:
#   Noting
################################################################################
update_course_page() {
    local FILE="${LOCAL_DIR}/${THIS_YEAR}/${MyShortname}.txt"
    if [ ! -f "$FILE" ]; then
        echo -e "${TODAY}  $count	$DAYNAME" > "$FILE"
    else
        if grep -q "^${TODAY}" "$FILE"; then
            sed -i "/^${TODAY}/c\\${TODAY}  $count	$DAYNAME" "$FILE"
        else
            echo -e "${TODAY}  $count	$DAYNAME" >> "$FILE"
        fi
    fi
}


################################################################################
# Create a HTML-table element based and
# create/maintain a file for the specific course
# Globals:
#   TableText, shortname, LINKREFERER, course
# From Settings-file:
#   SERVER_NAME
# Arguments:
#   None
# Outputs:
#   Writes the table to a temp file, 'TableTempFile'
################################################################################
generate_html_table() {
    if [ -n "$TableText" ]; then
        TableTempFile=$(mktemp /tmp/.moodle_table_report.XXXX)
        echo "$TableText" | while IFS=$'\t' read -r role course shortname id enrolled count
        do
            if [ "$role" = "student" ]; then
                MyShortname="$(echo "$shortname" | sed 's:[ /]:_:g; s/[åä]/a/g; s/ö/o/g')"                      # Ex: MyShortname=EDAA10_-_HT24_-_Hbg
                update_course_page
            fi
            CourseFullNameCell="<a href=\"https://$SERVER_NAME/course/view.php?id=$id\" $LINKREFERER>$course</a>"
            CourseShortNameCell="<a href=\"$THIS_YEAR/${MyShortname}.txt\" $LINKREFERER>$shortname</a>"
            echo '          <tr class="course"><td align="left">'$CourseFullNameCell'</td><td align="left">'$CourseShortNameCell'</td><td align="left">'$role'</td><td align="right">'$count'</td><td align="right">'$enrolled'</td></tr>' >> $TableTempFile
        done
    else
        echo '          <tr class="course"><td align="left" colspan="5"><p>&nbsp;</p><p>The system has not logged any activity since the start of the day.</p><p>&nbsp;</p></td></tr>' >> $TableTempFile
    fi

}


################################################################################
# Create the HTML page
# Globals:
#   TITLE_STRING, CSS_COLORFIX, TableTempFile
# From Settings-file:
#   ReportHead
# Arguments:
#   None
# Outputs:
#   Writes the completed file to a temp file, 'MoodleReportFile'
################################################################################
assemble_web_page() {
    MoodleReportFile=$LOCAL_DIR/index.html
    # Get the head of the custom report, replace SERVER and DATE
    curl --silent $REPORT_HEAD | sed "s/TITLE_STRING/$TITLE_STRING/; $CSS_COLORFIX" > "$MoodleReportFile"
    # Only continue if it worked
    if grep "Moodle usage report for" "$MoodleReportFile" &>/dev/null ; then
        echo "<body>" >> "$MoodleReportFile"
        echo '<div class="main_page">' >> "$MoodleReportFile"
        echo '  <div class="flexbox-container">' >> "$MoodleReportFile"
        echo '    <div id="box-header">' >> "$MoodleReportFile"
        echo "      <h3>Moodle usage report for</h3>" >> "$MoodleReportFile"
        echo "      <h1 style=\"color: $ORANGE;\">$SERVER_NAME</h1>" >> "$MoodleReportFile"
        echo "      <h4>$(date "+%A %Y-%m-%d %R %Z")</h4>" >> "$MoodleReportFile"
        echo "    </div>" >> "$MoodleReportFile"
        echo "  </div>" >> "$MoodleReportFile"
        echo "  <section>" >> "$MoodleReportFile"
        echo "    <p>&nbsp;</p>" >> "$MoodleReportFile"
        echo '    <p align="left">&nbsp;</p>' >> "$MoodleReportFile"
        echo '    <p align="left">&nbsp;</p>' >> "$MoodleReportFile"
        echo '    <p align="left">The table below is a presentation of a <code>SQL</code>-question put to the moodle database that aggregates the numbers of users of various roles that have been active in the moodle server '$DayText'.</p>' >> "$MoodleReportFile"
        echo '    <p align="left">&nbsp;</p>' >> "$MoodleReportFile"
        echo '    <p align="left">'$MoodleActivityText'</a>' >> "$MoodleReportFile"
        echo '    <p align="left">'$MoodleMetaInfoString'</a>' >> "$MoodleReportFile"
        echo '    <p align="left">&nbsp;</p>' >> "$MoodleReportFile"
	    echo '    <p align="left">The “Course fullname”-link goes to the specific course page on moodle and the “Course shortname”-link goes to a local file, containing a running daily count of users on that course. You can sort the table by clicking on the column headers. This page, and the individual pages, are updated every hour, on the hour.</p>' >> "$MoodleReportFile"
        echo '    <p>&nbsp;</p>' >> "$MoodleReportFile"
	    echo '    <p>Search for course: <input id="searchbar" onkeyup="search_course()" type="text"	name="search" placeholder="Search..."></p>' >> "$MoodleReportFile"
        echo '    <p align="left">&nbsp;</p>' >> "$MoodleReportFile"
        echo '    <table id="jobe">' >> "$MoodleReportFile"
        echo '      <thead>' >> "$MoodleReportFile"
        echo '        <tr><th onclick="sortTable(0)">Course fullname</th><th onclick="sortTable(1)">Course shortname</th><th onclick="sortTable(2)">Role</th><th align="right" onclick="sortTable(3)">Count</th><th align="right" onclick="sortTable(4)">Enrolled</th></tr>' >> "$MoodleReportFile"
        echo '      </thead>' >> "$MoodleReportFile"
        echo '      <tbody>' >> "$MoodleReportFile"
        cat "$TableTempFile" >> "$MoodleReportFile"
        echo '      </tbody>' >> "$MoodleReportFile"
        echo '    </table>' >> "$MoodleReportFile"
        echo '' >> "$MoodleReportFile"
        echo "  </section>" >> "$MoodleReportFile"
        echo '  <p align="center"><em>Report generated by &#8220;moodle-usage-report&#8221; (<a href="https://github.com/Peter-Moller/moodle-usage-report" '$LINKREFERER'>GitHub</a> <span class="glyphicon">&#xe164;</span>)</em></p>' >> "$MoodleReportFile"
        echo '  <p align="center"><em>Department of Computer Science, LTH/LU</em></p>' >> "$MoodleReportFile"
        echo '  <hr>' >> "$MoodleReportFile"
        echo '  <p align="center" style="color: '$BLUE';">This tool is an independent project and is not affiliated with or endorsed by Moodle Pty Ltd. ‘Moodle’ is a registered trademark of Moodle Pty Ltd.<br>' >> "$MoodleReportFile"
        echo '  Learn more about Moodle at <a href="https://moodle.com/" '$LINKREFERER'>moodle.com</a> (commercial services) and <a href="https://moodle.org" '$LINKREFERER'>moodle.org</a> (community hub)</p>' >> "$MoodleReportFile"
        echo "</div>" >> "$MoodleReportFile"
        echo "</body>" >> "$MoodleReportFile"
        echo "</html>" >> "$MoodleReportFile"
    else
        echo "<body>" >> "$MoodleReportFile"
        echo "<h1>Could not get $ReportHead!!</h1>"
        echo "</body>" >> "$MoodleReportFile"
        echo "</html>" >> "$MoodleReportFile"
    fi

}


################################################################################
# At the turn of the day, add one row to the 'total' file
# Globals:
#   DayTurn, MoodleActiveUsersToday, TODAY, THIS_YEAR
# From Settings-file:
#   RSYNC_USER, RSYNC_HOST, RSYNC_DIR
# Arguments:
#   None
# Outputs:
#   Nothing
################################################################################
dayturn_fixes() {
    if [ "$DayTurn" = "true" ]; then
        if [ ! -f "$DailySummaryFile" ]; then
            echo "Date	∑ students	∑ courses" > "$DailySummaryFile"
        fi
        echo "$TODAY	${MoodleActiveUsersToday:-0}	${NumCourses:-0}	$DAYNAME" >> "$DailySummaryFile"
    fi

    # Add data to files with no current day in them
    for FILE in $LOCAL_DIR/$THIS_YEAR/*
    do
        if [ -z "$(grep -E "^$TODAY" $FILE)" ]; then
            echo "$TODAY	0	$DAYNAME" >> "$FILE"
        fi
    done
}


################################################################################
# Copy the HTML-file to remote server and remove temp-files
# Globals:
#   MoodleReportTemp
# From Settings-file:
#   RSYNC_USER, RSYNC_HOST, RSYNC_DIR
# Arguments:
#   None
# Outputs:
#   Nothing
################################################################################
rsync_and_cleanup() {
    # rsync the local directories
    rsync -avz -e ssh "$LOCAL_DIR/" "${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_DIR}/" &>/dev/null

    # Delete tempfiles:
    rm "$TableTempFile"
}


#
#   _____   _   _  ______       _____  ______     ______   _   _   _   _   _____   _____   _____   _____   _   _   _____
#  |  ___| | \ | | |  _  \     |  _  | |  ___|    |  ___| | | | | | \ | | /  __ \ |_   _| |_   _| |  _  | | \ | | /  ___|
#  | |__   |  \| | | | | |     | | | | | |_       | |_    | | | | |  \| | | /  \/   | |     | |   | | | | |  \| | \ `--.
#  |  __|  | . ` | | | | |     | | | | |  _|      |  _|   | | | | | . ` | | |       | |     | |   | | | | | . ` |  `--. \
#  | |___  | |\  | | |/ /      \ \_/ / | |        | |     | |_| | | |\  | | \__/\   | |    _| |_  \ \_/ / | |\  | /\__/ /
#  \____/  \_| \_/ |___/        \___/  \_|        \_|      \___/  \_| \_/  \____/   \_/    \___/   \___/  \_| \_/ \____/
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


check_directories
get_basic_moodle_data
get_sql_data
generate_html_table
assemble_web_page
dayturn_fixes
rsync_and_cleanup
