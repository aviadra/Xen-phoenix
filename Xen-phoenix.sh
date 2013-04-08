#!/bin/bash
xencmd="/opt/xensource/bin/xe"

logger_xen()
{
if [[ "$2" = "expose" || $DEBUG != "0" && -n $DEBUG ]]; then 
	logger_cmd="logger -s -p local0.notice -t Xen-phoenix "
else
	logger_cmd="logger -p local0.notice -t Xen-phoenix "
fi

if [[ -n "$1" ]]; then
DATE="$( date +%D-%T )"
$logger_cmd "	  $1"  #useful for manual runs, but not for Cron ones.
Email_VAR="$Email_VAR $DATE:	  $1\\n"
[[ "$2" = "expose" ]] && Email_func "$1" "$3"
else
	$logger_cmd " "
	Email_VAR="$Email_VAR \n"
fi
}
Email_func()
{
	MSG="$1"
	[[ ! -x $SendEmail_location ]] && logger_xen "The SendEmail_location \"$SendEmail_location\", does NOT point to a perl executable." && continue
	[[ -z "$2" ]] && EMAIL_SUB="Exception" || EMAIL_SUB="$2"
	[[ "$2" = "Started" ]] && MSG="$MSG \\nThe VM list is set to be obtained using \"$LIST_METHOD\".\\nThe parameter that will be used is: \"$SECOND_PARAM\"." && [[ $LIST_METHOD = "TAGs" ]] && EMAIL_SUB="$EMAIL_SUB for $SECOND_PARAM"
	[[ "$2" =~ .*Exception.* ]] && MSG="$MSG \\nThe VM list was obtained using \"$LIST_METHOD\".\\n" && if [[ $LIST_METHOD = "FILE" ]]; then MSG="$MSG \n\n The list was $FILELIST"; else MSG="$MSG \n\n The TAG was $TAG" ;fi
	[[ $DEBUG = "0" || $DEBUG =~ .*EmailENABLed.* ]] && [[ -e $SendEmail_location ]] && $SendEmail_location -f "$EMAIL_FROM" -t "$EMAIL_TO" -u "Xen_backup - $EMAIL_SUB" -s "$EMAIL_SMART_HOST" -q -m "$MSG"
} 
xen_xe_func()
{
	case $2 in
		guest_tools_last_seen)
			xen_xe_func "$1" "uuid_2_name"
			GLS="$( $xencmd vm-param-get uuid=$1 param-name=guest-metrics-last-updated )"
			[[ $DEBUG = "ALL" || $DEBUG =~ .*guest_tools_last_seen.* ]] && logger_xen "guest_tools_last_seen for \"$VM_NAME_FROM_UUID\" with uuid of \"$1\" has been set to \"$GLS\"."
			;;
		list_all_VMs_UUIDs)
			VMs_on_server="$( $xencmd vm-list | grep uuid | awk '{print $5}' )"
			[[ $DEBUG = "ALL" || $DEBUG =~ .*list_all_VMs_UUIDs.* ]] && logger_xen "All VMs on server has been set to: $VMs_on_server"
			;;
		import)
			import_cmd="$xencmd vm-import filename=$1"
			if [[ $DEBUG = "0" || $DEBUG =~ .*ImportENABLed.* ]]; then
				$import_cmd > /dev/null
				if [[ "$?" -eq 0 ]]; then
					IMPORT="OK"
					logger_xen "Successfully imported \"$1\" :)"
					[[ $DEBUG = "ALL" || $DEBUG =~ .*ImportENABLed.* ]] && logger_xen "Will now wait for 5s, to let things time to settle."
					sleep 5
				else
					IMPORT="FAILED"
					logger_xen "Failed to import :\ \"$1\"" "expose"
				fi
			else
				logger_xen "import CMD was: \"$import_cmd\""
				IMPORT="OK"
				logger_xen "Debug is turned on, skipped actually importing to save time."
			fi
			;;
		name_2_uuid)
			VM_UUID="$( $xencmd vm-list name-label=$1 | grep uuid | awk '{ print $5 }' )"
			[[ $DEBUG = "ALL" || $DEBUG =~ .*name_2_uuid.* ]] && logger_xen "VM_UUID for \"$1\" has been set to \"$VM_UUID\"."
			;;
		uuid_2_name)
			VM_NAME_FROM_UUID="$( $xencmd vm-list uuid=$1 | grep name | awk '{for (i = 4; i <= NF; i++) {printf("%s ", $i);} }' )"
			[[ $DEBUG = "ALL" || $DEBUG =~ .*uuid_2_name.* ]] && logger_xen "VM_NAME_FROM_UUID has been set to \"$VM_NAME_FROM_UUID\" for \"$1\"."
			;;
		state)
			POWERSTATE="$( $xencmd vm-param-get param-name=power-state uuid=$1 )"
			[[ $DEBUG = "ALL" || $DEBUG =~ .*state.* ]] && logger_xen "POWERSTATE for \"$VM_NAME_FROM_UUID\" with UUID of: \"$1\" has been set to \"$POWERSTATE\"."
			;;
		org_state)
			[[ $DEBUG = "ALL" || $DEBUG =~ .*org_state.* ]] && logger_xen "Org sate invoked for \"$VM_NAME_FROM_UUID\" with UUID of: \"$1\"."
			xen_xe_func "$1" "state"
			ORG_STATE=$POWERSTATE
			[[ $DEBUG = "ALL" || $DEBUG =~ .*org_state.* ]] && logger_xen "ORG_STATE for \"$VM_NAME_FROM_UUID\" with UUID of: \"$1\" as been set to \"$ORG_STATE\"."
			;;
		export)	
			xen_xe_func "$1" "uuid_2_name"
			if [[ $ENABLE_COMPRESSION = "yes" ]]; then
					export_cmd="$xencmd vm-export compress=true uuid=$1 filename=\"${BackupLocation}/${VM_NAME_FROM_UUID}-${1}.xva\""
				else
					export_cmd="$xencmd vm-export uuid=$1 filename=$BACKUP_FILE_AND_LOCAL_LONG"
			fi
			if [[ $DEBUG = "0" || $DEBUG =~ .*ExportENABLed.* ]]; then
				$export_cmd > /dev/null
				if [[ "$?" -eq 0 ]]; then
					EXPORT="OK"
					logger_xen "Successfully exported \"$VM_NAME_FROM_UUID\" with UUID of: \"$1\" :)"
					[[ $DEBUG = "ALL" || $DEBUG =~ .*Export_func.* ]] && logger_xen "Will now wait for 5s, to let \"$1\" time to cool-down."
					sleep 5
				else
					EXPORT="FAILED"
					logger_xen "Failed to export :\ \"$VM_NAME_FROM_UUID\" with UUID of: \"$1\"" "expose"
					#Email_func "Failed to export $1" "Exception!!"
					#continue
				fi
			else
				logger_xen "Export CMD was: \"$export_cmd\""
				EXPORT="OK"
				logger_xen "Debug is turned on, skipped actually exporting to save time."
			fi
			;;
		vm_properties)
			[[ $DEBUG = "ALL" || $DEBUG =~ .*vm_properties.* ]] && logger_xen "Vm_properties for \"$1\" has been invoked."
				xen_xe_func "$1" "vm-existance"
				VM_UUID="$1"
				xen_xe_func "$VM_UUID" "uuid_2_name"
				xen_xe_func "$VM_UUID" "deps_state_custom"
			;;
		vm-existance)
			if [[ -z "$( $xencmd vm-list uuid=$1 )" && -z "$( $xencmd vm-list name-label=$1 )" ]]; then
				logger_xen "The VM \"$1\" is in the backup list, but does not exist?" "expose"
				continue
			fi
			;;
		start)
			[[ $DEBUG = "ALL" || $DEBUG =~ .*start.* ]] && logger_xen "StartVM func invoked."
			VM_TO_START="$1"
			xen_xe_func "$1" "uuid_2_name"
			[[ "$3" = "child" ]] && VM_TO_START="$( $xencmd vm-list name-label=$1 | grep uuid | awk '{ print $5 }' )"
			[[ $DEBUG = "ALL" || $DEBUG =~ .*start.* ]] && logger_xen "VM_TO_START was set to: \"$VM_TO_START\". (Its name is: \"$VM_NAME_FROM_UUID\")"
			$xencmd vm-start uuid="$VM_TO_START"
			if [[ "$?" -eq 0 ]] ; then
				logger_xen "Successfully started \"$VM_NAME_FROM_UUID\" with uuid \"$1\""
			else
				logger_xen "FAILED to start \"$1\""
				logger_xen "Waiting for 10s and retrying to start VM \"$1\""
				sleep 10
				$xencmd vm-start uuid="$1"
				if [[ "$?" -eq 0 ]] ;then
					logger_xen "Retry to start VM \"$1\" was successful"
				else
					logger_xen "FAILED again to start \"$1\". Will sleep for $WARM_UP_DELAY seconds and try a third and final time"
					sleep $WARM_UP_DELAY
					$xencmd vm-start uuid="$1"
					if [[ "$?" -eq 0 ]] ;then
						logger_xen "Retry to start VM \"$1\" was successful"
					else
						logger_xen "FAILED twice to start \"$1\"" "Exception!!" "expose"
						#Email_func "FAILED twice to start $1" "Exception!!"
						continue
					fi
					 
				fi
			fi
			;;
		shutdown)
			xen_xe_func "$1" "state"
			if [[ $POWERSTATE != "halted" ]] ; then
				[[ $DEBUG = "ALL" || $DEBUG =~ .*shutdown.* ]] && logger_xen "About to: \"$xencmd vm-shutdown uuid=$1\"."
				$xencmd vm-shutdown uuid="$1"
				if [[ "$?" -eq 0 ]] ;then
					logger_xen "Successfully shutdown VM \"$VM_NAME_FROM_UUID\" \"$1\"."
					[[ $DEBUG = "ALL" || $DEBUG =~ .*shutdown.* ]] && logger_xen "Will now wait for 5s, to let \"$VM_NAME_FROM_UUID\" with UUID of: \"$1\" time to cool-down"
					sleep 5
				else
					logger_xen "Something went wrong when shutting down the VM \"$VM_NAME_FROM_UUID\" with UUID of: \"$1\"" "expose"
					continue
				fi
			fi
			xen_xe_func "$1" "state"
			;;
		deps_state_custom)
			DEP_STATE="null"
			CHILDREN_LIST="null"
			PARENT="null"
			[[ $DEBUG = "ALL" || $DEBUG =~ .*deps_state_custom.* ]] && logger_xen "The deps_state_custom func has been invoked for \"$VM_NAME_FROM_UUID\" with UUID of: \"$1\"."
			CHILDREN_LIST="$( $xencmd vm-param-get uuid=$VM_UUID param-name=other-config param-key=XenCenter.CustomFields.Children 2> /dev/null )"
			if [[ "$?" -eq 0 ]] ; then
				logger_xen "VM has children. They are: $CHILDREN_LIST."
				for CHILD_NAME in $CHILDREN_LIST; do
					xen_xe_func "$CHILD_NAME" "name_2_uuid"
					CHILDREN_LIST_UUID="$CHILDREN_LIST_UUID $VM_UUID"
					[[ $DEBUG = "ALL" || $DEBUG =~ .*deps_state_custom.* ]] && logger_xen "The current CHILDREN_LIST_UUID is: \"$CHILDREN_LIST_UUID\"."
				done
				DEP_STATE="dep_parent"
			else
				[[ $DEBUG = "ALL" || $DEBUG =~ .*deps_state_custom.* ]] && logger_xen "No Children were found for \"$VM_NAME_FROM_UUID\" with UUID of: \"$1\". looking for a PARENT."
				PARENT="$( $xencmd vm-param-get uuid=$VM_UUID param-name=other-config param-key=XenCenter.CustomFields.Parent 2> /dev/null )"
				if [[ "$?" -eq 0 ]] ; then
					[[ $DEBUG = "ALL" || $DEBUG =~ .*deps_state_custom.* ]] && logger_xen "VM has a Parent. It is: \"$PARENT\"."
					DEP_STATE="dep_child"
				else
					[[ $DEBUG = "ALL" || $DEBUG =~ .*deps_state_custom.* ]] && logger_xen "No Parent was found for \"$VM_NAME_FROM_UUID\"."
				fi
			fi
			[[ $DEBUG = "ALL" || $DEBUG =~ .*deps_state_custom.* ]] && logger_xen "DEP_STATE has been set to: \"$DEP_STATE\". the current CHILDREN_LIST is: \"$CHILDREN_LIST\" and the PARENT is: \"$PARENT\"."
			;;

		space_for_backup_check)
			[[ $DEBUG = "ALL" || $DEBUG =~ .*space_for_backup_check.* ]] && logger_xen "Func space_for_backup_check has been invoked."
			DISKS_SIZE=0
			for DISK in $( $xencmd vm-disk-list uuid=$1 | grep virtual-size | awk '{print $4}' ); do 
				[[ $DEBUG = "ALL" || $DEBUG =~ .*space_for_backup_check.* ]] && logger_xen "Disk with the size of \"$DISK\", was found for VM \"$VM_NAME_FROM_UUID\" with UUID of: \"$1\"."
				DISKS_SIZE=$(( $DISKS_SIZE + $DISK ))
			done
			logger_xen "Total disks size is: \"$DISKS_SIZE\" for \"$VM_NAME_FROM_UUID\"."
			FREE_SPACE="$( df $BackupLocation | grep $BackupLocation | awk '{print $3}' )"
			if [[ -n $FREE_SPACE ]] ; then 
				[[ $DEBUG = "ALL" || $DEBUG =~ .*space_for_backup_check.* ]] && logger_xen "FREE_SPACE="$( df $BackupLocation | grep $BackupLocation | awk '{print $3}' )""
				[[ $DEBUG = "ALL" || $DEBUG =~ .*space_for_backup_check.* ]] && logger_xen "BackupLocation is: $BackupLocation"
				FREE_SPACE_IN_BYTES=$(( $FREE_SPACE * 1024 ))
				if [[ $(( $FREE_SPACE_IN_BYTES - $DISKS_SIZE * 2 )) -le "1000000000" ]]; then
					logger_xen "Disqualified VM \"$VM_NAME_FROM_UUID\" form export, because the VM aggregate disk size is $(( $DISKS_SIZE / 1000000000 ))G and had we continued with this export, less than 10G would be left on the backup location." "expose" "Exception - Disqualification"
					logger_xen "" # log formatting
					logger_xen "" # log formatting
					continue
				else
					[[ $DEBUG = "ALL" || $DEBUG =~ .*space_for_backup_check.* ]] && logger_xen "There was enough space for the backup :)"
					#logger_xen "" # log formatting
				fi
			else
				[[ $CHECK_FREE_SPACE = "yes" ]] && CHECK_FREE_SPACE="no" && logger_xen "" && logger_xen "Assessment of the FREE_SPACE parameter failed for backup location \"$BackupLocation\". You may disable this check in the settings file.\\nNote: This is a known issue when the backup location is a subdirectory in the mounted share." "expose" && logger_xen ""
			fi
		;;
		 
		*) logger_xen "Incorrect use of xe func"
	esac
}

backup_func()
{
	logger_xen "Backup func has been invoked for \"$1\"."
	VM_TO_BACKUP="$1"
	xen_xe_func "$VM_TO_BACKUP" "uuid_2_name"
	xen_xe_func "$VM_TO_BACKUP" "space_for_backup_check"
	xen_xe_func "$VM_TO_BACKUP" "org_state"
	BACKUP_FILE_AND_LOCAL_LONG="${BackupLocation}/${VM_NAME_FROM_UUID}- ${1}.xva"
	BACKUP_FILE_AND_LOCAL_LONG="${BACKUP_FILE_AND_LOCAL_LONG// /_}"
	[[ -e "$BACKUP_FILE_AND_LOCAL_LONG" ]] && mv "$BACKUP_FILE_AND_LOCAL_LONG" "$BACKUP_FILE_AND_LOCAL_LONG.org" && logger_xen "Moved old backup to temp location."
	[[ $POWERSTATE = "running" ]] && xen_xe_func "$1" "shutdown"
	logger_xen "Now exporting \"$VM_TO_BACKUP\"."
	xen_xe_func "$VM_TO_BACKUP" "export"
	if [[ $ORG_STATE = "running" && "$2" != "child" ]];then 
		logger_xen "Now starting up $1, because ORG_STATE was $ORG_STATE"
		xen_xe_func "$1" "start"
		logger_xen "Giving $WARM_UP_DELAY seconds so that $1 finishes warming up"
		sleep $WARM_UP_DELAY
	fi
	[[ $2 = "child" ]] && logger_xen "This VM \"$VM_NAME_FROM_UUID\" is a CHILD, will not start it until PARENT is done."
	[[ $EXPORT = "OK" && -e $BACKUP_FILE_AND_LOCAL_LONG.org ]] && rm "$BACKUP_FILE_AND_LOCAL_LONG.org" -f && logger_xen "Deleted old backup for \"$VM_NAME_FROM_UUID\" with UUID of: \"$1\" as new one is OK."
}
##################ENGINE#############################################
logger_xen "Welcome to the Xen-phoenix restore script."
logger_xen "" # log formatting

if [[ -z "$@" ]]; then
	logger_xen "You must pass first argument settings file and second argument restore CHEVRONs." "expose"
	exit 2
fi

SETTINGS_FILE="$1"
[[ ! -e $SETTINGS_FILE ]] && logger_xen "Settings file, $SETTINGS_FILE not found" && exit 2
if [[ -n $( head -1 $SETTINGS_FILE | grep "settings file for the Xen-phoenix" ) ]]; then 
	source $SETTINGS_FILE && logger_xen "Settings file header found in \"$SETTINGS_FILE\", so it was sourced."
	[[ $DEBUG != "0" ]] && logger_xen "The DEBUG paramter is enabled and the following flags are used: \"$DEBUG\""
else
	logger_xen "The appropriate header, was NOT found in the designated settings file. The so called settings file $SETTINGS_FILE was NOT sourced and Xen-phoenix will now exit." "expose"
	echo "The appropriate header, was NOT found in the designated settings file. The so called settings file $SETTINGS_FILE was NOT sourced and Xen-phoenix will now exit."
	exit 2
fi
if [[ -n "$2" ]] ;then 
	logger_xen "" # log formatting
	SECOND_PARAM="$2"
	symbol=$SECOND_PARAM
else
	logger_xen "Second argument cannot be empty!" "expose"
	exit 2
fi

Email_func "$Email_VAR" "Started"

if [[ $DEBUG = "0" ]]; then WARM_UP_DELAY=60; else WARM_UP_DELAY=5 ; fi

###Target location preflight checks
#massaging BackupLocation, so that it doesn't have trailing slashes
BackupLocation=${BackupLocation%/}; [[ $DEBUG = "ALL" || $DEBUG =~ .*backuplocation.* ]] && logger_xen "BackupLocation trailing slash have been removed."
#warmup backup location
dd if=/dev/zero of=$BackupLocation/testfile.blob bs=1M count=1 &> /dev/null
touch $BackupLocation/testfile.blob &> /dev/null
rm -f $BackupLocation/testfile.blob &> /dev/null
#end of warmup
touch $BackupLocation/testfile.blob &> /dev/null
if [[ "$?" -eq 0 ]] ; then
	[[ $DEBUG = "ALL" || $DEBUG =~ .*backuplocation.* ]] && logger_xen "Trying to create a simple file was successful."
	rm -f $BackupLocation/testfile.blob &> /dev/null
			if [[ "$?" -eq 0 ]] ; then
				[[ $DEBUG = "ALL" || $DEBUG =~ .*backuplocation.* ]] && logger_xen "Was able to delete test file."
			else
				logger_xen "Was not able to delete test file??" "expose" "Backup location - Abort!"
			fi
else
	logger_xen "Was unable to create even the simplest form of a file to the backup location \"$BackupLocation\", so restore run has been aborted." "expose" "Restore location - Abort!"
	exit 2
fi

#find files to work on
for CHEVRON in $@; do
	[[ "$CHEVRON" = "$1" ]] && continue
	VM_LIST_FROM_CHEVRONs="$VM_LIST_FROM_CHEVRONs $( find $BackupLocation -type f -name *$CHEVRON* )"
	#statements
done
#echo $VM_LIST_FROM_CHEVRONs


#The work.
for VM in $VM_LIST_FROM_CHEVRONs; do
	logger_xen "Working on \"$VM\"."
	xen_xe_func "$VM" "import"
	logger_xen "" # log formatting
	logger_xen "" # log formatting
done
 
#verifier
xen_xe_func " " "list_all_VMs_UUIDs"

for VM in $VMs_on_server ; do
	Vcounter=0
	while [[ $( date -u +%S ) -ge 50 ]]; do
			sleep 1
	done
	xen_xe_func "$VM" "guest_tools_last_seen"
	ORG_GLS=$GLS
	[[ $DEBUG = "ALL" || $DEBUG =~ .*verifier.* ]] && logger_xen "pre-starting ORG_GLS was: $ORG_GLS"
	xen_xe_func "$VM" "state"
	if [[ $POWERSTATE = "running" ]]; then
		xen_xe_func "$VM" "shutdown"
		xen_xe_func "$VM" "start"
	else
		xen_xe_func "$VM" "start"
	fi
	while [[ "$GLS" = "$ORG_GLS" || "$GLS" = "<not in database>" && $Vcounter -le 25 ]]; do
		[[ $DEBUG = "ALL" || $DEBUG =~ .*verifier.* ]] && logger_xen "wating for GLS to change"
		sleep 3
		xen_xe_func "$VM" "guest_tools_last_seen"
		let Vcounter=Vcounter+1
		[[ $DEBUG = "ALL" || $DEBUG =~ .*verifier.* ]] && logger_xen "Vcounter is: $Vcounter"
		logger_xen "" # log formatting
	done
[[ $DEBUG = "ALL" || $DEBUG =~ .*verifier.* ]] && logger_xen "new GLS is $GLS"
if [[ "$GLS" =~ .*"$( date -u +%H:%M )"* ]] ; then
	xen_xe_func "$VM" "uuid_2_name"
	[[ $DEBUG = "ALL" || $DEBUG =~ .*verifier.* ]] && logger_xen "The new GLS for \"$VM_NAME_FROM_UUID\" does rufly contain the current time ^_^"
else
	[[ $DEBUG = "ALL" || $DEBUG =~ .*verifier.* ]] && logger_xen "The new GLS  for \"$VM_NAME_FROM_UUID\" does NOT contain the current time??" "expose"
fi
xen_xe_func "$VM" "shutdown"
logger_xen "" # log formatting
logger_xen "" # log formatting
done

#Yey Done
logger_xen "Backup script has finished its run and will now Email the report."
if [[ $LIST_METHOD = "TAGs" ]]; then
	Email_func "$Email_VAR" "Report for $TAG"
else
	Email_func "$Email_VAR" "Report"
fi
