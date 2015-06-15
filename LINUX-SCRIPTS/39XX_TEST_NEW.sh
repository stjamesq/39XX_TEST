#!/bin/bash
### CHANGE LOG ###
# 02/21/2014 - Initial Release
# 02/28/2014 - Updated to check Date, also updated to perform a complete P-Blade test
# 03/12/2014 - Updated to also test 03.02.02.19 software - Released to Rev A
# 03/17/2014 - BUG FIX - Fix "3903 DC Power Supply Type" bug - would not detect DC supplies in 3903
# 03/18/2014 - BUG FIX - Fix "," values in error reporting (No commas should be in a .csv file)
# 03/26/2014 - Accept Rev 20 CPUs for all orders, but note that the system shipped with Rev 20 if found
# 06/23/2014 - Added check for OpenSSL version in 03.02.03.10
# 07/07/2014 - Updated to test 03.03.000.045 S/W version
# 10/14/2014 - Updated to test 03.04.000.023 S/W version
# 12/09/2014 - Updated to support new licensing options
# 12/26/2014 - Updated to test 03.04.001.011 S/W version
# 03/04/2015 - Updated to test additional licenses installed on 3901 systems (not supported up until now) up to 6 at a time
# 03/26/2015 - Updated to collect the board option - 0001 indicates non-digipot, 0005 indicates DIGIPOT
#				+ Also adding a board diagnostics test that will more thoroughly check board voltages on each blade
# 06/05/2015 - Updated to test 03.05.000.025 S/W version
### CHANGE LOG ###

SW_REV="1.2"
echo "
PFS39XX FINAL TEST - REV $SW_REV
"

cleanUP() {
### fix stty only for 03.02.00.30 software 	###
[[ "$SW_VER" == "03.02.00.30" ]] && cp -af /bin/BAK.stty /bin/stty

### at a minimum remove this script 		###
cd /opt/
rm -rf /opt/test/
#echo "WARNING: cleanUP script not active!"
}

loadDATA() {
### "GET" all values with expect scripts ###
getINFO=/opt/test/getINFO.exp
$getINFO > $INFO
case $TEST_TYPE in
"FULL SWITCH"|"DEBUG")
	getLIC=/opt/test/getLIC.exp
	$getLIC >> $INFO
	NAME_SWI="$(cat $INFO |grep -i "Auto Eth"|awk '{print $2}')"
	getDIAGS=/opt/test/getDIAGS.exp
	$getDIAGS "$NAME_SWI" > $DG_LOG
;;
*)
;;
esac

### PROCOMM loaded values ###
	DATA[3]="$1" ### Scanned Product ID KEY (collected by PROCOMM)
	DATA[6]="$2" ### Scanned Model (collected by PROCOMM)
	DATA[0]="$3" ### DATE (collected by PROCOMM)
	DATA[1]="$4" ### TIME (collected by PROCOMM)
	DATA[2]="$5" ### Tech ID (collected by PROCOMM)
	DATA[8]="$6" ### Sales Order # (collected by PROCOMM)
	DATA[7]="$7" ### Scanned Item # (collected by PROCOMM)
	DATA[5]="$8" ### Scanned MAC Address (collected by PROCOMM)
	DATA[4]="$9" ### Scanned Chassis Serial #
	
	SCN_PBLADE_NUM=${10} ### User will have to determine how many blades exist in chassis
	PBLADE_NUM=$(cat $INFO |grep vpi|grep -c P-BLADE)
	if [ $SCN_PBLADE_NUM -ne $PBLADE_NUM ];then
		[[ -n "${DATA[$DATAMAX]}" ]] && DATA[$DATAMAX]="${DATA[$DATAMAX]} & Could not detect [$SCN_PBLADE_NUM] in the system - could only detect [$PBLADE_NUM]" || DATA[$DATAMAX]="Could not detect [$SCN_PBLADE_NUM] P-BLADES in the system - could only detect [$PBLADE_NUM]"
	fi
	
### Shell Script loaded values ###
	
	UNAME_INDEX=9 ### UNAME_INDEX should be the LAST index available for the uname variable
	DATA[$UNAME_INDEX]="$(uname -r)" ### Real Kernel_Version - uname -r"
	
	### This will collect BLADE information to the BLADEINFO Array. This array is divided into 3 segments, 1 for each blade expected
	for (( SLOTNUM=0 ; SLOTNUM<$PBLADE_NUM ; SLOTNUM++ ))
	do
		BLADENUM=$(($SLOTNUM+1))
		PLUS_INDEX=$(($SLOTNUM * $INDEX_FACTOR))
		for (( INDY=0 ; INDY<$INDEX_FACTOR ; INDY++ ))
		do
			INDY1[$INDY]=$(($PLUS_INDEX+$INDY))
			INDY2[$INDY]=$(($PLUS_INDEX+$INDY+$(($UNAME_INDEX+1)))) 
		done
		
		BLADELOG=/opt/test/BLADEINFO$BLADENUM.log
		getSCRIPT=/opt/test/getBLADEINFO.exp
		$getSCRIPT $BLADENUM > $BLADELOG
		[[ "$SW_VER" == "03.02.00.30" ]] && SWGREP="OnPATH UCS" || SWGREP="Debug CLI"
		BLADEINFO[${INDY1[0]}]="$(cat $BLADELOG |grep "$SWGREP"|awk 'BEGIN {FS="Ver: "};{print $2}'|sed -e 's/\r//g')" # S/W VERSION #
		DATA[${INDY2[0]}]="${BLADEINFO[${INDY1[0]}]}"
		BLADEINFO[${INDY1[1]}]="$(cat $BLADELOG |grep Freescale|awk '{print $7" "$8" "$9}')" # Blade CPU type
		DATA[${INDY2[1]}]="${BLADEINFO[${INDY1[1]}]}"
		BLADEINFO[${INDY1[2]}]="$(cat $BLADELOG |grep -m 1 clock|awk '{print $3}'|awk 'BEGIN {FS="."};{print $1}')" # Blade CPU Speed
		DATA[${INDY2[2]}]="${BLADEINFO[${INDY1[2]}]}"
		BLADEINFO[${INDY1[3]}]="$(cat $BLADELOG |grep -m1 "Switch 0"|awk '{print $4" "$5}'|sed -e 's/\r//g')"	 	# Blade Alta Chip info
		DATA[${INDY2[3]}]="${BLADEINFO[${INDY1[3]}]}"
		BLADEINFO[${INDY1[4]}]="$(cat $BLADELOG |grep "mmcblk0:"|awk '{print $3}'|awk 'BEGIN {FS="."};{print $1}')"				### Blade SD Card Size
		DATA[${INDY2[4]}]="${BLADEINFO[${INDY1[4]}]}"
		BLADEINFO[${INDY1[5]}]="$(cat $INFO |grep -A30 "swdb 1.$BLADENUM"|grep vpi|awk '{print $2" "$3" "$4" "$5}'|awk 'BEGIN {FS="::"};{print $1}'|sed 's/:://g') $(cat $BLADELOG|grep Options|awk 'BEGIN {FS=";"};{print $2}'|awk '{print $1"="$2}')" 	### Blade UBoot Version and Option
		DATA[${INDY2[5]}]="${BLADEINFO[${INDY1[5]}]}"
		BLADEINFO[${INDY1[6]}]="$(cat $BLADELOG |grep -m1 "SN = "|awk '{print $3}'|sed -e 's/\r//g')" 	### Blade Serial Number
		DATA[${INDY2[6]}]="${BLADEINFO[${INDY1[6]}]}"
		BLADEINFO[${INDY1[7]}]="${PBLADE_MODEL[$SLOTNUM]}" 	### Blade Model Number
		DATA[${INDY2[7]}]="${BLADEINFO[${INDY1[7]}]}"
	done
	case $SW_VER in
	03.03.000.045|03.04.000.023|03.04.001.011|03.05.000.024)
		SO_FLAG=$(echo ${DATA[8]}|cut -b 1)
		if [[ -n "$(echo ${DATA[7]}|grep "\-DDK")" ]] || [[ $SO_FLAG -eq 2 ]] || [[ $SO_FLAG -eq 6 ]];then
			DATA[$(($DATAMAX-3))]="$(cat $INFO|grep -A2 P-Blade|grep Ethernet|sed 's/o L/oL/g'|awk '{print $2" "$3" AND "$4" "$5" AND "$6" "$7}'|sed 's/,//g')" #34
		else
			cd /HorizON/Server
			./MLFDecoder|grep "Packet Flow"|sed 's/Packet Flow://g'|sed 's/O L/OL/g' > /opt/test/LIC.log
			DATA[$(($DATAMAX-3))]="$(echo $(cat /opt/test/LIC.log)|awk '{print "1G [0/"$2"] AND 10G [0/"$4"] AND 40G [0/"$6"]"}')" #34
		fi
	;;
	*)
		DATA[$(($DATAMAX-3))]="$(cat $INFO|grep -A2 P-Blade|grep Ethernet|sed 's/o L/oL/g'|awk '{print $2" "$3" AND "$4" "$5" AND "$6" "$7}'|sed 's/,//g')" #34
	;;
	esac
	DATA[$(($DATAMAX-2))]="FINAL" ### there is only a Final Test currently
	DATA[$(($DATAMAX-1))]="PASS"  ### FAIL is filled in at end of script if Failures were detected. Leave here as a note
	# DATA[$DATAMAX]="Failure Reason. Can be populated with this script. Leave here as a note"
	#sleep 40 # This may be needed by the OLD method, but collecting all logs before resetting the blades seems to be a cleaner method
}

saveDATA() {
cat /dev/null > $LOG
for (( Y=0 ; Y<=$DATAMAX ; Y++ ));do
	
	[[ "${DATA[$Y]}" == "NULL" ]] && DATA[$Y]=""
	DATA[$Y]="$(echo "${DATA[$Y]}"|sed 's/\r//g')"
	#echo "Loading Data Point $Y" 	# DEBUG #
	#echo "${DATA[$Y]}"				# DEBUG #
	if [ $Y -ne $DATAMAX ];then
		echo -n "${DATA[$Y]}," >> $LOG
	else		
		echo "${DATA[$DATAMAX]}"|sed 's/\r//g' >> $LOG
	fi
	#read -p "Press Enter to continue" anykey # DEBUG #
	# DEBUG # cat $LOG;echo
	
done
}

scriptFAIL() {
DATA[$(($DATAMAX-1))]="FAIL"
saveDATA
}

### This sub proc resolves all tests - it either passes (0) or fails (1) and sends a predetermined message to the user
### The script must simply pass this sub proc 3 values - the "Pass" message, the "Fail" message, and the test results
resolveIT() {
case $3 in
0) #PASS#
	echo "$1"
;;
1) #FAIL#
	echo "$2"
	FAIL_STR="$(echo "$2"|sed 's/\r/ <CR> /g')"
	[[ -n "${DATA[$DATAMAX]}" ]] && DATA[$DATAMAX]="${DATA[$DATAMAX]} & $FAIL_STR" || DATA[$DATAMAX]="$FAIL_STR"
;;
2) #EXPECTED FAILURE#
	echo "$4"
	[[ -n "${DATA[$DATAMAX]}" ]] && DATA[$DATAMAX]="${DATA[$DATAMAX]} & $4" || DATA[$DATAMAX]="$4"
;;
esac
}

### This sub proc will test diagnostics for each switch case ###
### $1 = Switch Name - Need this to poll diagnostics
diagCHK() {
DIAG_FAIL=0
echo "
Checking Switch Diagnostics...
"
cd /opt/test
[[ -n "$(echo "${DATA[6]}"|cut -b 1-7|grep NAP)" ]] && EXPS="1200W_AC" || EXPS="1440W_DC"
case "$1" in
3901|3901R)
	[[ "$EXPS" == "1200W_AC" ]] && EXPS="AC" || EXPS="DC"
	EXP_RPM=15000
	### CHECKING FAN RPMS ###
	CMP_VAR2=$EXP_RPM
	for CTLR in 1 2 3
	do
		RPM_LINE="$(cat $DG_LOG|grep -A2 "controller $CTLR"|grep RPM|sed 's/\r//g')"
		for FAN in 1 2
		do
			[[ $FAN -eq 1 ]] && CMP_VAR1=$(echo "$RPM_LINE"|awk '{print $2}') || CMP_VAR1=$(echo "$RPM_LINE"|awk '{print $3}')
			FAIL_MSG="Fan $FAN on Controller $CTLR FAILED - [$CMP_VAR1 RPM] should be above [$CMP_VAR2 RPM]"
			PASS_MSG="Fan $FAN on Controller $CTLR PASSED - [$CMP_VAR1 RPM]"
			[[ $CMP_VAR1 -lt $CMP_VAR2 ]] && F_SWTCH=1 && DIAG_FAIL=$(($DIAG_FAIL+1)) || F_SWTCH=0
			resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH
		done
	done
	

	if [ "$1" == "3901R" ];then
		### Checking Board Voltages ###
		BOARD_Vs="$(cat $DG_LOG|grep "Board Voltages"|grep -v "GOOD")"
		CMP_VAR1="$BOARD_Vs"
		FAIL_MSG="PSUS: FAILED DIAGNOSTICS
$BOARD_Vs"
		PASS_MSG="PSUS: Board Voltages are GOOD"
		[[ -n "$CMP_VAR1" ]] && F_SWTCH=1 && DIAG_FAIL=$(($DIAG_FAIL+1)) || F_SWTCH=0
		resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH
		
		### CHECKING PSU STATUS (3901 Redundant)
		for PSU in 1 2
		do
			PSU_STATUS="$(cat $DG_LOG|grep "PSU $PSU FRU PRESENT"|grep -v GOOD)"
			CMP_VAR1="$PSU_STATUS"
			FAIL_MSG="PSU $PSU: FAILED - See Below
$PSU_STATUS"
			PASS_MSG="PSU $PSU: Status is GOOD"
			[[ -n "$CMP_VAR1" ]] && F_SWTCH=1 && DIAG_FAIL=$(($DIAG_FAIL+1)) || F_SWTCH=0
			resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH
			
			### Check the PSU TYPE ###
			PSU_TYPE="$(cat $DG_LOG|grep -A1 "PSU $PSU FRU PRESENT"|grep "PSU type"|grep -v "3901_REDUN_$EXPS")"
			CMP_VAR1="$PSU_TYPE"
			PASS_MSG="PSU $PSU: Type is $EXPS Redundant"
			[[ -n "$CMP_VAR1" ]] && F_SWTCH=1 && DIAG_FAIL=$(($DIAG_FAIL+1)) || F_SWTCH=0
			resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH
		done
	else
		### CHECKING PSU STATUS (Single PSU) ###
		PSU_STATUS="$(cat $DG_LOG|grep -A2 "PSU 1 FRU PRESENT"|grep -v GOOD)"
		CMP_VAR1="$PSU_STATUS"
		FAIL_MSG="PSU 1: FAILED - See Below
$PSU_STATUS"
		PASS_MSG="PSU 1: PASSED"
		[[ -n "$CMP_VAR1" ]] && F_SWTCH=1 && DIAG_FAIL=$(($DIAG_FAIL+1)) || F_SWTCH=0
		resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH
	fi
;;
3903)
	EXP_RPM=4500
	### Checking Fan RPMS ###
	CMP_VAR2=$EXP_RPM
	RPM_LINE="$(cat $DG_LOG|grep -A2 "controller 1"|grep RPM|sed 's/\r//g')"
	for FAN in 1 2
	do
		[[ $FAN -eq 1 ]] && CMP_VAR1=$(echo "$RPM_LINE"|awk '{print $2}'|sed 's/^.//') || CMP_VAR1=$(echo "$RPM_LINE"|awk '{print $3}'|sed 's/^.//')
		FAIL_MSG="Fan $FAN on Controller $CTLR FAILED - [$CMP_VAR1 RPM] should be above [$CMP_VAR2 RPM]"
		PASS_MSG="Fan $FAN on Controller $CTLR PASSED - [$CMP_VAR1 RPM]"
		[[ $CMP_VAR1 -lt $CMP_VAR2 ]] && F_SWTCH=1 && DIAG_FAIL=$(($DIAG_FAIL+1)) || F_SWTCH=0
		resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH
	done
	
	### CHECKING PSU STATUS and VOLTAGES (3903 Redundant) ###
	for PSU in 1 2
		do
			PSU_STATUS="$(cat $DG_LOG|grep "PSU $PSU FRU PRESENT"|grep -v GOOD)"
			CMP_VAR1="$PSU_STATUS"
			FAIL_MSG="PSU $PSU: FAILED - See Below
$PSU_STATUS"
			PASS_MSG="PSU $PSU: Status is GOOD"
			[[ -n "$CMP_VAR1" ]] && F_SWTCH=1 && DIAG_FAIL=$(($DIAG_FAIL+1)) || F_SWTCH=0
			resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH
			
			### Check the PSU TYPE ###
			PSU_TYPE="$(cat $DG_LOG|grep -A1 "PSU $PSU FRU PRESENT"|grep "PSU type"|grep -v "3903_$EXPS")"
			CMP_VAR1="$PSU_TYPE"
			PASS_MSG="PSU $PSU: Type is $EXPS Redundant"
			FAIL_MSG="PSU $PSU: FAILED - See Below
$PSU_TYPE"
			[[ -n "$CMP_VAR1" ]] && F_SWTCH=1 && DIAG_FAIL=$(($DIAG_FAIL+1)) || F_SWTCH=0
			resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH
			
			PSU_Vs="$(cat $DG_LOG|grep -A5 "PSU $PSU FRU PRESENT")"
			for VTYPE in "12V" "3_3V" "1_2VA" "1_2VB"
			do
				CMP_VAR1="echo $PSU_Vs|grep "PG_$VTYPE"|grep GOOD"
				PASS_MSG="PSU $PSU: Voltage Check Passed"
				FAIL_MSG="PSU $PSU: FAILED $VTYPE - See Below
$PSU_Vs"
				[[ -z "$CMP_VAR1" ]] && F_SWTCH=1 && DIAG_FAIL=$(($DIAG_FAIL+1)) || F_SWTCH=0
				resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH
			done
		done	
;;
esac

### CHECKING P-BLADE VOLTAGES (Any Amount of P-Blades) ###
	for (( BLA=1 ; BLA<=$PBLADE_NUM ; BLA++ ))
	do
		CMP_VAR1="$(echo $(cat DIAGS.log |grep -A28 "bla 1\.$BLA"|grep -v Version|grep -v Variant|grep V|grep -v GOOD|sed 's/\r/ -> /g'))"
		FAIL_MSG="P-Blade $BLA Voltage : $CMP_VAR1"
		PASS_MSG="P-Blade $BLA Voltage : Passed"
		[[ -n "$CMP_VAR1" ]] && F_SWTCH=1 && DIAG_FAIL=$(($DIAG_FAIL+1)) || F_SWTCH=0
		resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH
	done
	
	[[ $DIAG_FAIL -ne 0 ]] && echo "Diagnostics found $DIAG_FAIL Diagnostic Errors" && scriptFAIL
}

testDBG() {
if [ $1 -eq 1 ];then
	echo "
Failure Count So Far - $2
"
	read -p "Press <ENTER> to continue testing..."
fi
}

test39XX() {
### Set type of test flag ###
TYPEofTEST="$TEST_TYPE"

### Set the DBG flag ###
DBG_FLG=0
[[ -n "$1" ]] && DBG_FLG=1 && SW_VER="03.04.000.023" && TYPEofTEST="FULL SWITCH"

### Set the Sales Order flag - this will determine if the Switch is NEW or USED material ###
SO_FLAG=$(echo ${DATA[8]}|cut -b 1)
FAIL_FLAG=0

### Check MAC Address ###
REAL_MAC="$(/HorizON/SystemFiles/oweeprom 0 -p|grep "MAC address read"|awk '{print $5}'|sed 's/://g')"
CMP_VAR1="${DATA[5]}"
CMP_VAR2="$REAL_MAC"
FAIL_MSG="MAC Address scanned is incorrect - should be [$REAL_MAC]"
PASS_MSG="MAC Address Check Passed"
[[ -z "$(echo "$CMP_VAR1"|sed 's/-//g'|grep -i "$CMP_VAR2")" ]] && F_SWTCH=1 && FAIL_FLAG=$(($FAIL_FLAG+1)) || F_SWTCH=0
resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH

testDBG $DBG_FLG $FAIL_FLAG

### Check DATE ###
REAL_DATE="$(date +%m/%d/%Y)"
CMP_VAR1="$REAL_DATE"
CMP_VAR2="${DATA[0]}"
FAIL_MSG="Checking Date: FAILED - System Date [$CMP_VAR1] conflicts with [$CMP_VAR2] gathered from Test PC"
PASS_MSG="Checking Date: PASSED"
[[ "$(echo $CMP_VAR1|sed 's/0//g')" != "$(echo $CMP_VAR2|sed 's/0//g')" ]] && F_SWTCH=1 && FAIL_FLAG=$(($FAIL_FLAG+1)) || F_SWTCH=0
resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH

testDBG $DBG_FLG $FAIL_FLAG

ALT_UBOOT="UBoot 9 0234 ED"
case "$SW_VER" in
"03.02.00.30")
EXP_UBOOT="UBoot 6 0234 EC"
EXP_OPENSSL="Not Supported"
;;
"03.02.02.19"|"03.02.03.10")
EXP_UBOOT="UBoot 6 0234 ED"
EXP_OPENSSL="OpenSSL 1.0.1g 7 Apr 2014"
;;
"03.03.000.045")
EXP_UBOOT="UBoot 9 0234 ED"
EXP_OPENSSL="OpenSSL 1.0.1h 5 Jun 2014"
;;
"03.04.000.023")
EXP_UBOOT="UBoot 9 0234 ED"
EXP_OPENSSL="OpenSSL 1.0.1i 6 Aug 2014"
;;
"03.04.001.011")
EXP_UBOOT="UBoot 9 0234 ED"
EXP_OPENSSL="OpenSSL 1.0.1j 15 Oct 2014"
;;
"03.05.000.025")
EXP_UBOOT="UBoot 9 0234 ED"
EXP_OPENSSL="OpenSSL 1.0.1k-fips 8 Jan 2015"
;;
*)
	echo "SOFTWARE TYPE [$SW_VER] IS NOT SUPPORTED"
	exit 0
;;
esac

### Test P-Blade Specific Items ###
echo "
Testing P-Blade Specific Requirements
"
for (( SLOTNUM=0 ; SLOTNUM<$PBLADE_NUM ; SLOTNUM++ ));do
	BLADENUM=$(($SLOTNUM+1))
	PLUS_INDEX=$(($SLOTNUM * $INDEX_FACTOR))
	### Check if ONPATH.CONF file contains the "HORIZON=AUTO" line
	FAIL_MSG="P-Blade $BLADENUM: ONPATH.CONF file is not complete - FAILED"
	PASS_MSG="P-Blade $BLADENUM: ONPATH.CONF file is correct!"
	[[ -z "$(grep "HORIZON=AUTO" /opt/test/BLADEINFO$BLADENUM.log)" ]] && F_SWTCH=1 && FAIL_FLAG=$(($FAIL_FLAG+1)) || F_SWTCH=0
	resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH
	
	testDBG $DBG_FLG $FAIL_FLAG
	
	### Check P-Blade Serial
	CMP_VAR1="${PBLADE_SERIAL[$SLOTNUM]}"
	CMP_VAR2="${BLADEINFO[$(($PLUS_INDEX+6))]}"
	FAIL_MSG="P-Blade $BLADENUM: Serial Number Check FAILED - [ $CMP_VAR1 ] is scanned should be [ $CMP_VAR2 ]"
	PASS_MSG="P-Blade $BLADENUM: Serial Number Check Passed"
	[[ -z "$(echo "$CMP_VAR1"|grep -i "$CMP_VAR2")" ]] && F_SWTCH=1 && FAIL_FLAG=$(($FAIL_FLAG+1)) || F_SWTCH=0
	resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH
	
	testDBG $DBG_FLG $FAIL_FLAG
	
	### Check SW Version ###
	CMP_VAR1="${BLADEINFO[$(($PLUS_INDEX+0))]}"
	CMP_VAR2="$SW_VER"
	FAIL_MSG="P-Blade $BLADENUM: Software Check FAILED - [ $CMP_VAR1 ] is installed should be [ $CMP_VAR2 ]"
	PASS_MSG="P-Blade $BLADENUM: Software Check Passed"
	[[ -z "$(echo "$CMP_VAR1"|grep -i "$CMP_VAR2")" ]] && F_SWTCH=1 && FAIL_FLAG=$(($FAIL_FLAG+1)) || F_SWTCH=0
	resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH
	
	testDBG $DBG_FLG $FAIL_FLAG

	### Check FreeScale CPU (verify model or revision hasn't changed) and SPEED
	CMP_VAR1="${BLADEINFO[$(($PLUS_INDEX+1))]}"
	CMP_VAR2="(rev 30)"
	FAIL_MSG="P-Blade $BLADENUM: Freescale CPU Version Check FAILED - [$CMP_VAR1] should contain [$CMP_VAR2]"
	PASS_MSG="P-Blade $BLADENUM: Freescale CPU Version Check Passed"
	EXP_MSG="P-Blade $BLADENUM: Freescale CPU Version Check - Expected Error - Tracking CPU [$CMP_VAR1] for historical purposes"
	[[ -z "$(echo "$CMP_VAR1"|grep -i "$CMP_VAR2")" ]] && F_SWTCH=1 && FAIL_FLAG=$(($FAIL_FLAG+1)) || F_SWTCH=0
	case $SO_FLAG in
	1|2|3|4|6|7|8)
	[[ $F_SWTCH -eq 1 ]] && F_SWTCH=2 && FAIL_FLAG=$(($FAIL_FLAG-1))
	;;
	esac
	resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH "$EXP_MSG"
	
	testDBG $DBG_FLG $FAIL_FLAG
	
	CMP_VAR1="${BLADEINFO[$(($PLUS_INDEX+1))]}"
	CMP_VAR2="P4080E"
	FAIL_MSG="P-Blade $BLADENUM: Freescale CPU Model Check FAILED - [$CMP_VAR1] should contain [$CMP_VAR2]"
	PASS_MSG="P-Blade $BLADENUM: Freescale CPU Model Check Passed"
	[[ -z "$(echo "$CMP_VAR1"|grep "$CMP_VAR2")" ]] && F_SWTCH=1 && FAIL_FLAG=$(($FAIL_FLAG+1)) || F_SWTCH=0
	resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH
	
	testDBG $DBG_FLG $FAIL_FLAG
	
	CMP_VAR1=${BLADEINFO[$(($PLUS_INDEX+2))]}
	CMP_VAR2=1200
	CMP_VAR3=1500
	FAIL_MSG="P-Blade $BLADENUM: Freescale CPU Speed Check FAILED - should be either $CMP_VAR2 or $CMP_VAR3 MHz"
	PASS_MSG="P-Blade $BLADENUM: Freescale CPU Speed Check Passed"
	if [ $CMP_VAR1 -ne $CMP_VAR2 ];then
		if [ $CMP_VAR1 -ne $CMP_VAR3 ];then
			F_SWTCH=1
			FAIL_FLAG=$(($FAIL_FLAG+1))
		else
			F_SWTCH=0
		fi
	else
		F_SWTCH=0
	fi
	resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH
	
	testDBG $DBG_FLG $FAIL_FLAG
		
	### Check P-Blade Alta Model and Version
	CMP_VAR1="${BLADEINFO[$(($PLUS_INDEX+3))]}"
	CMP_VAR2="Version=B2"
	FAIL_MSG="P-Blade $BLADENUM: ALTA Version Check FAILED - [$CMP_VAR1] should contain [$CMP_VAR2]"
	PASS_MSG="P-Blade $BLADENUM: ALTA Version Check Passed"
	EXP_MSG="P-Blade $BLADENUM: ALTA Version Check - Expected Error - [$CMP_VAR1] is acceptable for EVALS ONLY"
	[[ -z "$(echo "$CMP_VAR1"|grep -i "$CMP_VAR2")" ]] && F_SWTCH=1 && FAIL_FLAG=$(($FAIL_FLAG+1)) || F_SWTCH=0
	case $SO_FLAG in
	2|6)
	[[ $F_SWTCH -eq 1 ]] && F_SWTCH=2 && FAIL_FLAG=$(($FAIL_FLAG-1))
	;;
	esac	
	resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH "$EXP_MSG"
	
	testDBG $DBG_FLG $FAIL_FLAG
	
	CMP_VAR1="${BLADEINFO[$(($PLUS_INDEX+3))]}"
	CMP_VAR2="Model=FM6364"
	FAIL_MSG="P-Blade $BLADENUM: ALTA Model Check FAILED - [$CMP_VAR1] should contain [$CMP_VAR2]"
	PASS_MSG="P-Blade $BLADENUM: ALTA Model Check Passed"
	[[ -z "$(echo "$CMP_VAR1"|grep -i "$CMP_VAR2")" ]] && F_SWTCH=1 && FAIL_FLAG=$(($FAIL_FLAG+1)) || F_SWTCH=0
	resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH
	
	testDBG $DBG_FLG $FAIL_FLAG
		
	### Check MicroSD Card Capacity
	MICROSD_CAP=32
	CMP_VAR1=${BLADEINFO[$(($PLUS_INDEX+4))]}
	CMP_VAR2=$MICROSD_CAP
	FAIL_MSG="P-Blade $BLADENUM: MicroSD card Incorrect capacity - [ ${DATA[12]} GB ] is installed should be [ $CMP_VAR2 GB ]"
	PASS_MSG="P-Blade $BLADENUM: MicroSD Capacity Check Passed"
	[[ $CMP_VAR1 -lt $CMP_VAR2 ]] && F_SWTCH=1 && FAIL_FLAG=$(($FAIL_FLAG+1)) || F_SWTCH=0
	resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH
	
	testDBG $DBG_FLG $FAIL_FLAG
		
	### Check UBoot Version
	CMP_VAR1="${BLADEINFO[$(($PLUS_INDEX+5))]}"
	CMP_VAR2="$EXP_UBOOT"
	CMP_VAR3="$ALT_UBOOT"
	FAIL_MSG="UBoot Version Check FAILED - [${BLADEINFO[$(($PLUS_INDEX+5))]}] expected to be [$EXP_UBOOT]"
	PASS_MSG="P-Blade $BLADENUM: UBoot Version Check Passed"
	[[ -z "$(echo "$CMP_VAR1"|grep "$CMP_VAR2")" ]] && [[ -z "$(echo "$CMP_VAR1"|grep "$CMP_VAR3")" ]] && F_SWTCH=1 && FAIL_FLAG=$(($FAIL_FLAG+1)) || F_SWTCH=0
	resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH
	
	testDBG $DBG_FLG $FAIL_FLAG
	
	### Check OpenSSL Version is correct ###
	CMP_VAR1="$(grep "$EXP_OPENSSL" /opt/test/BLADEINFO$BLADENUM.log|sed 's/SSL_VER=//g'|sed 's/\r//g')"
	CMP_VAR2="$EXP_OPENSSL"
	FAIL_MSG="P-Blade $BLADENUM: OpenSSL Version is INCORRECT - [$(openssl version)] should be [$CMP_VAR2]"
	PASS_MSG="P-Blade $BLADENUM: OpenSSL Version is Correct!"
	EXP_MSG="P-Blade $BLADENUM: OpenSSL Version is INCORRECT - EXPECTED w/ 3.2.0.30 S/W - REPLACEMENTS ONLY"
	[[ "$CMP_VAR1" != "$CMP_VAR2" ]] && F_SWTCH=1 && FAIL_FLAG=$(($FAIL_FLAG+1)) || F_SWTCH=0
	case $SO_FLAG in
	3|4)
	[[ "$SW_VER" == "03.02.00.30" ]] && [[ $F_SWTCH -eq 1 ]] && F_SWTCH=2 && FAIL_FLAG=$(($FAIL_FLAG-1))
	;;
	esac
	resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH "$EXP_MSG"
	
	testDBG $DBG_FLG $FAIL_FLAG
done

case "$TYPEofTEST" in
### ONLY System Level Tests ###
"FULL SWITCH")
echo "
Testing Full Switch Requirements
"
### Check Serial Number ###
REAL_SERIAL="$(cat $INFO|grep "Product Id"|awk '{print $3}'|sed 's/,//g')"
CMP_VAR1="${DATA[3]}"
CMP_VAR2="$REAL_SERIAL"
FAIL_MSG="Serial Number scanned is incorrect - Scanned is [$CMP_VAR1] should be [$CMP_VAR2]"
PASS_MSG="Serial Check Passed"
[[ -z "$(echo "$CMP_VAR1"|grep "$CMP_VAR2")" ]] && F_SWTCH=1 && FAIL_FLAG=$(($FAIL_FLAG+1)) || F_SWTCH=0
resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH

testDBG $DBG_FLG $FAIL_FLAG

## Check Switch Name, then Perform Diagnostics ###
NAME_SWI="$(cat $INFO |grep -i "Auto Eth"|awk '{print $2}')"
REAL_SWI="$(cat $INFO |grep -i "Auto Eth"|awk '{print $3}')"
CMP_VAR1="$NAME_SWI"
CMP_VAR2="$REAL_SWI"
FAIL_MSG="Switch Name is Incorrect - [$CMP_VAR1] should be [$CMP_VAR2]"
PASS_MSG="Switch Name is Correct"
[[ "$CMP_VAR1" != "$CMP_VAR2" ]] && F_SWTCH=1 && FAIL_FLAG=$(($FAIL_FLAG+1)) || F_SWTCH=0
resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH

diagCHK "$NAME_SWI"

testDBG $DBG_FLG $FAIL_FLAG

CMP_VAR1="msrv${REAL_MAC^^}.mlf"
FAIL_MSG="FAILED: License File was not found!"
PASS_MSG="License File Exists"
[[ ! -e /HorizON/Server/lic/$CMP_VAR1 ]] && F_SWTCH=1 && FAIL_FLAG=$(($FAIL_FLAG+1)) || F_SWTCH=0
resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH

testDBG $DBG_FLG $FAIL_FLAG

## Check License Options ###
REAL_LIC="${DATA[$(($DATAMAX-3))]}"
## Calculate # of licenses based on Switch and P-Blade model #s scanned in ###
LIC_1G=0
LIC_10G=0
LIC_40G=0
for (( LOOP=0 ; LOOP<$PBLADE_NUM ; LOOP++ ))
do
	for LIC_TYPE in 5120 5100 4100 3100 2120 2100 1100;do
		MODEL="${PBLADE_MODEL[$LOOP]}"
		if [ -n "$(echo "$MODEL"|grep "$LIC_TYPE")" ];then
			case $LIC_TYPE in
			5100|5120)	LIC_1G=$(($LIC_1G - 16))
					LIC_10G=$(($LIC_10G + 16))
			;;
			4100)	LIC_40G=$(($LIC_40G + 2))
			;;
			3100) 	LIC_10G=$(($LIC_10G + 44))
					LIC_40G=$(($LIC_40G + 4))
			;;
			2100|2120)	LIC_10G=$(($LIC_10G + 16))
			;;
			1100) 	LIC_1G=$(($LIC_1G + 48))
			;;
			esac
		fi
	done
done
if [[ -n "$(echo ${DATA[7]}|grep "\-DDK")" ]] || [[ $SO_FLAG -eq 2 ]] || [[ $SO_FLAG -eq 6 ]];then
	LIC_1G="NOLIMIT"
	LIC_10G="NOLIMIT"
	LIC_40G="NOLIMIT"
fi

### This will add addtional ports to the license check for any additional licenses scanned at the END of the user data entry ###
for (( LOOPD=1 ; LOOPD<7 ; LOOPD++ ))
do
	if [ -n "${ADD_LIC[$LOOPD]}" ];then
		for LIC_TYPE in 5120 5100 4100 3100 2120 2100 1100
		do
			if [ -n "$(echo "${ADD_LIC[LOOPD]}"|grep "$LIC_TYPE")" ];then
			case $LIC_TYPE in
			5100|5120)	LIC_1G=$(($LIC_1G - 16))
			LIC_10G=$(($LIC_10G + 16))
			;;
			4100)	LIC_40G=$(($LIC_40G + 2))
			;;
			3100) 	LIC_10G=$(($LIC_10G + 44))
					LIC_40G=$(($LIC_40G + 4))
			;;
			2100|2120)	LIC_10G=$(($LIC_10G + 16))
			;;
			1100) 	LIC_1G=$(($LIC_1G + 48))
			;;
			esac
			fi
		done
	fi
done

### 1G License Check ###
CMP_VAR1="$(echo $REAL_LIC|awk 'BEGIN {FS=" AND "};{print $1}'|awk '{print $2}'|awk 'BEGIN {FS="/"};{print $2}'|sed 's/]//g')"
CMP_VAR2="$LIC_1G"
FAIL_MSG="The amount of 1G Licenses is incorrect! Expected 1G [0/$LIC_1G] - Real Licenses -> [ ${DATA[$(($DATAMAX-3))]} ]"
PASS_MSG="[$CMP_VAR1] 1G Licenses Installed"
[[ "${CMP_VAR1^^}" != "${CMP_VAR2^^}" ]] && F_SWTCH=1 && FAIL_FLAG=$(($FAIL_FLAG+1)) || F_SWTCH=0
resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH

testDBG $DBG_FLG $FAIL_FLAG

### 10G License Check ###
CMP_VAR1="$(echo $REAL_LIC|awk 'BEGIN {FS=" AND "};{print $2}'|awk '{print $2}'|awk 'BEGIN {FS="/"};{print $2}'|sed 's/]//g')"
CMP_VAR2="$LIC_10G"
FAIL_MSG="The amount of 10G Licenses is incorrect! Expected 10G [0/$LIC_10G] - Real Licenses -> [ ${DATA[$(($DATAMAX-3))]} ]"
PASS_MSG="[$CMP_VAR1] 10G Licenses Installed"
[[ "${CMP_VAR1^^}" != "${CMP_VAR2^^}" ]] && F_SWTCH=1 && FAIL_FLAG=$(($FAIL_FLAG+1)) || F_SWTCH=0
resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH

testDBG $DBG_FLG $FAIL_FLAG

### 40G License Check ###
CMP_VAR1="$(echo $REAL_LIC|awk 'BEGIN {FS=" AND "};{print $3}'|awk '{print $2}'|awk 'BEGIN {FS="/"};{print $2}'|sed 's/]//g')"
CMP_VAR2="$LIC_40G"
FAIL_MSG="The amount of 40G Licenses is incorrect! Expected 40G [0/$LIC_40G] - Real Licenses -> [ ${DATA[$(($DATAMAX-3))]} ]"
PASS_MSG="[$CMP_VAR1] 40G Licenses Installed"
[[ "${CMP_VAR1^^}" != "${CMP_VAR2^^}" ]] && F_SWTCH=1 && FAIL_FLAG=$(($FAIL_FLAG+1)) || F_SWTCH=0
resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH

testDBG $DBG_FLG $FAIL_FLAG

### Check IP settings are set correctly ###
### IP ###
REAL_IP="$(cat $INFO|grep "Primary IP"|awk '{print $3}')"
CMP_VAR1="$REAL_IP"
CMP_VAR2="10.0.1.1"
FAIL_MSG="IP Check FAILED - [$CMP_VAR1] should be [$CMP_VAR2]"
PASS_MSG="IP Check Passed"
[[ "$CMP_VAR1" != "$CMP_VAR2" ]] && F_SWTCH=1 && FAIL_FLAG=$(($FAIL_FLAG+1)) || F_SWTCH=0
resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH

testDBG $DBG_FLG $FAIL_FLAG

### MASK ###
REAL_MASK="$(cat $INFO |grep "Primary IP"|awk '{print $5}')"
CMP_VAR1="$REAL_MASK"
CMP_VAR2="255.255.255.0"
FAIL_MSG="Subnet MASK Check FAILED - [$CMP_VAR1] should be [$CMP_VAR2]"
PASS_MSG="Subnet MASK Check Passed"
[[ "$CMP_VAR1" != "$CMP_VAR2" ]] && F_SWTCH=1 && FAIL_FLAG=$(($FAIL_FLAG+1)) || F_SWTCH=0
resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH

testDBG $DBG_FLG $FAIL_FLAG

### GATEWAY ###
REAL_GW="$(cat $INFO|grep "Primary IP"|awk '{print $7}'|sed -e 's/\r//g')"
CMP_VAR1="$REAL_GW"
CMP_VAR2="0.0.0.0"
FAIL_MSG="Gateway Check FAILED - [$CMP_VAR1] should be [$CMP_VAR2]"
PASS_MSG="Gateway Check Passed"
[[ "$CMP_VAR1" != "$CMP_VAR2" ]] && F_SWTCH=1 && FAIL_FLAG=$(($FAIL_FLAG+1)) || F_SWTCH=0
resolveIT "$PASS_MSG" "$FAIL_MSG" $F_SWTCH

testDBG $DBG_FLG $FAIL_FLAG
;;
*)
echo "Full System check has not been done"
;;
esac
echo "
Number of Failures - $FAIL_FLAG
"
[[ $FAIL_FLAG -ne 0 ]] && scriptFAIL
}

### Debug Mode will show the author all variables collected by this script
### for easy evaluation of commands. The author must specify the amount of P-Blades
DBG_MODE() {
echo "NOW ENTERING DEBUG MODE
"

YorN=""
read -p "Do you want to test variables? (y/N) " YorN

if [ "$YorN" == "y" ];then
	
	VAR_NAME=( "DATE" "TIME" "SCAN_TECHID" "PID" "SCAN_CHASSIS" "SCAN_MAC" "SCAN_MODEL" "SCAN_ITEM" "SCAN_SO" "UNAME" "BLADE1_SW" "BLADE1_CPU" "BLADE1_SPEED" "BLADE1_ALTA" "BLADE1_SDSZ" "BLADE1_UBOOT" "BLADE1_SERIAL" "BLADE1_MODEL" "BLADE2_SW" "BLADE2_CPU" "BLADE2_SPEED" "BLADE2_ALTA" "BLADE2_SDSZ" "BLADE2_UBOOT" "BLADE2_SERIAL" "BLADE2_MODEL" "BLADE3_SW" "BLADE3_CPU" "BLADE3_SPEED" "BLADE3_ALTA" "BLADE3_SDSZ" "BLADE3_UBOOT" "BLADE3_SERIAL" "BLADE3_MODEL" "LICENSE" "TESTTYPE" "PASSorFAIL" "FAIL_REASON" )

	read -p "How many P-Blades Expected? " DBG_PNUM
	read -p "What is the Model #? " DBG_MODEL

	echo "Now testing the alloted time to load all data points"
	time loadDATA "DBG_PID" "$DBG_MODEL" "DBG_DATE" "DBG_TIME" "DBG_TECHID" "DBG_SO" "DBG_ITEM" "DBG_MAC" "DBG_CHASSIS" $DBG_PNUM
	saveDATA
	DATA[$DATAMAX]="FAILED - Debug will always fail"
	scriptFAIL

	for (( DBG_IND=0 ; DBG_IND<=$DATAMAX ; DBG_IND++ ));do
		### Declare the Variable Name ###
		echo "--------------------------
	
Now Showing ${VAR_NAME[$DBG_IND]} Variable: "
		### Check for carriage returns in data ###
		CMP="$(echo "${DATA[$DBG_IND]}"|sed 's/\r//g')"
		[[ "${DATA[$DBG_IND]}" != "$CMP" ]] && echo "WARNING: This Variable has a carriage return"
		echo "${DATA[$DBG_IND]}"
		echo
		read -p "Press Enter to move onto the next variable" pressENTER
	done
	
	YorN=""
	read -p "Would you like to attempt to pass the test? (y/N) " YorN
	if [ "$YorN" == "y" ];then
		test39XX DEBUG
	fi
	
	YorN=""
	read -p "Would you like to see the final OUTPUT of all variables? (y/N) " YorN
	if [ "$YorN" == "y" ];then
		STRING="$(cat $LOG|sed 's/\r/ -> /g')"
		read -p "End of Variable check - Press Enter to see OUTPUT" pressENTER
		echo -n "data ->"
		echo "$STRING"
		echo "ENDDATA"
		echo "ENDDATA"
		echo "ENDDATA"
	fi
fi

read -p "Press <ENTER> to exit DEBUG MODE" anyKEY
exit
}

### set trap - will cause the error to be displayed ###
trap "echo Script has quit unexpectedly;exit" 1 2 3 15

### set data variables "globally" so they can be changed in sub processes ###
INDEX_FACTOR=8
DATAMAX=37
for (( X=0 ; X<=$DATAMAX ; X++ ));do
	DATA[$X]=""
	BLADEINFO[$X]=""
done
PBLADE_NUM=0

[[ -z "$(cat /HorizON/Server/ONPATH.CONF|grep "DEBUG=ON")" ]] && sed -i 's/DEBUG=OFF/DEBUG=ON/g' /HorizON/Server/ONPATH.CONF

LOG=/opt/test/data.log
DG_LOG=/opt/test/DIAGS.log
INFO=/opt/test/info.log

TEST_TYPE="$1" ### This will be "P-BLADE" or "FULL SWITCH" collected by PROCOMM script #
SW_VER="$2" ### Obtained via the 294 number entered in PROCOMM
shift 2

### If this is a Final Configuration, collect licensing information
if [ "$TEST_TYPE" == "FULL SWITCH" ];then
PBLADE_SERIAL[0]="${10}"
PBLADE_MODEL[0]="${11}"
PBLADE_SERIAL[1]="${12}"
PBLADE_MODEL[1]="${13}"
PBLADE_SERIAL[2]="${14}"
PBLADE_MODEL[2]="${15}"
elif [ "$TEST_TYPE" == "P-BLADE" ];then
	# Clear License File (IF ANY) #
	cd /HorizON/Server/lic/
	rm -rf ./*
	PBLADE_SERIAL[0]="${10}"
	PBLADE_MODEL[0]="${11}"
	# 
elif [ "$TEST_TYPE" == "DEBUG" ];then
	### ENTER DEBUG MODE ###
	PBLADE_SERIAL[0]="DBG1_SERIAL"
	read -p "What is the Model of PBLADE in slot 1? " PBLADE_MODEL[0]
	PBLADE_SERIAL[1]="DBG2_SERIAL"
	read -p "What is the Model of PBLADE in slot 2? " PBLADE_MODEL[1]
	PBLADE_SERIAL[2]="DBG3_SERIAL"
	read -p "What is the Model of PBLADE in slot 3? " PBLADE_MODEL[2]
	DBG_MODE
else
	echo "You chose an incorrect test type [$TEST_TYPE]"
	exit
fi

[[ -z "$SW_VER" ]] && echo "ERROR: Script does not recognize your software choice" && exit 0

### set variable to test for up to 6 additional licenses ###
[[ -n "${17}" ]] && ADD_LIC[1]="${17}" || ADD_LIC[1]=""
[[ -n "${18}" ]] && ADD_LIC[2]="${18}" || ADD_LIC[2]=""
[[ -n "${19}" ]] && ADD_LIC[3]="${19}" || ADD_LIC[3]=""
[[ -n "${20}" ]] && ADD_LIC[4]="${20}" || ADD_LIC[4]=""
[[ -n "${21}" ]] && ADD_LIC[5]="${21}" || ADD_LIC[5]=""
[[ -n "${22}" ]] && ADD_LIC[6]="${22}" || ADD_LIC[6]=""

ERR_NUM=0
while :
do
	read -p "Test Function : " FUNCTION
	case $FUNCTION in
		LOAD)
		loadDATA "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${16}"
		saveDATA
		;;
		TEST)
		test39XX
		;;
		COLLECT)
		STRING="$(cat $LOG|sed 's/\r/ -> /g')"
		read -p "Press <ENTER>" anyKEY
		echo -n "data ->"
		echo "$STRING"
		echo "ENDDATA"
		echo "ENDDATA"
		echo "ENDDATA"
		read -p "Press <ENTER>" anyKEY
		;;
		END)
		if [ "${DATA[$(($DATAMAX-1))]}" == "PASS" ];then
			echo "TEST PASSED!
${DATA[$DATAMAX]}"
			cleanUP
		else
			echo "TEST FAILED! See Below
${DATA[$DATAMAX]}"
		fi
		break
		;;
		*) 	echo "Incorrect Option"
		echo "Please choose: LOAD|TEST|COLLECT|END"
		;;
	esac
done
