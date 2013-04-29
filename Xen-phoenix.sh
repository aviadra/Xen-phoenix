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
	[[ "$2" = "Started" ]] && MSG="$MSG \\nThe Chevrons that will be used are: $CHEVRONs."
	[[ "$2" =~ .*Exception.* ]] && MSG="$MSG \\nThe VM list was obtained using \"$LIST_METHOD\".\\n" && if [[ $LIST_METHOD = "FILE" ]]; then MSG="$MSG \n\n The list was $FILELIST"; else MSG="$MSG \n\n The TAG was $TAG" ;fi
	[[ $DEBUG = "0" || $DEBUG =~ .*EmailENABLed.* ]] && [[ -e $SendEmail_location ]] && $SendEmail_location -f "$EMAIL_FROM" -t "$EMAIL_TO" -u "Xen_restore - $EMAIL_SUB" -s "$EMAIL_SMART_HOST" -q -m "$MSG"
} 
xen_xe_func()
{
	case $2 in

		typer)
			xen_xe_func "$1" "uuid_2_name"
			[[ $DEBUG = "ALL" || $DEBUG =~ .*typer.* ]] && logger_xen "The typer func has been invoked for \"$VM_NAME_FROM_UUID\" with UUID of: \"$1\"."
			VM_TYPE="$( $xencmd vm-param-get uuid=$1 param-name=PV-bootloader 2> /dev/null )"
			[[ $DEBUG = "ALL" || $DEBUG =~ .*typer.* ]] && logger_xen "typer: $VM_TYPE"
			;;
		keeper)
			xen_xe_func "$1" "uuid_2_name"
			[[ $DEBUG = "ALL" || $DEBUG =~ .*keeper.* ]] && logger_xen "The keeper func has been invoked for \"$VM_NAME_FROM_UUID\" with UUID of: \"$1\"."
			Phoenix_keeper="$( $xencmd vm-param-get uuid=$1 param-name=other-config param-key=XenCenter.CustomFields.Phoenix_keeper 2> /dev/null )"
			[[ $DEBUG = "ALL" || $DEBUG =~ .*keeper.* ]] && logger_xen "Phoenix_keeper: $Phoenix_keeper"
			;;
		delete)
			xen_xe_func "$1" "uuid_2_name"
			xen_xe_func "$1" "shutdown"
			VMVDIs="$( $xencmd vm-disk-list uuid=$1 vdi-params=uuid vbd-params=other | grep uuid | awk '{print $5}' )"
			for VDIUUID in $VMVDIs; do 
				[[ $DEBUG = "ALL" || $DEBUG =~ .*delete.* ]] && logger_xen "A VDIUUID for VM \"$VM_NAME_FROM_UUID\" with was: \"$VDIUUID\"."
				$xencmd vdi-destroy uuid=$VDIUUID
			done
			$xencmd vm-destroy uuid=$1
			[[ $DEBUG = "ALL" || $DEBUG =~ .*delete.* ]] && logger_xen "Deleted VM \"$VM_NAME_FROM_UUID\" with uuid of \"$1\"."
			;;
		guest_tools_last_seen)
			xen_xe_func "$1" "uuid_2_name"
			GLS="$( $xencmd vm-param-get uuid=$1 param-name=guest-metrics-last-updated )"
			[[ $DEBUG = "ALL" || $DEBUG =~ .*guest_tools_last_seen.* ]] && logger_xen "guest_tools_last_seen(GLS) for \"$VM_NAME_FROM_UUID\" with uuid of \"$1\" has been set to \"$GLS\"."
			;;
		list_all_VMs_UUIDs)
			VMs_on_server=""
			VMs_on_server_raw="$( $xencmd vm-list params=uuid | awk '{print $5}' )"
			for VM_UUID_raw in $VMs_on_server_raw; do
				if [[ "$( $xencmd vm-param-get uuid=$VM_UUID_raw param-name=is-control-domain )" = "false" ]]; then
					VMs_on_server="$VMs_on_server $VM_UUID_raw"
					[[ $DEBUG = "ALL" || $DEBUG =~ .*list_all_VMs_UUIDs.* ]] && logger_xen "Regular VM $VM_UUID_raw added to general list"
				else
					[[ $DEBUG = "ALL" || $DEBUG =~ .*list_all_VMs_UUIDs.* ]] && logger_xen "this is a control domain, so will not add it to general VMs list."
				fi
			done
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
						logger_xen "FAILED twice to start \"$1\"" "expose"
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
					logger_xen "Something went wrong when shutting down the VM \"$VM_NAME_FROM_UUID\" with UUID of: \"$1\". Waiting for 30 seconds and trying again."
					sleep 30
					xen_xe_func "$1" "state"
					if [[ $POWERSTATE != "halted" ]] ; then
						[[ $DEBUG = "ALL" || $DEBUG =~ .*shutdown.* ]] && logger_xen "About to: \"$xencmd vm-shutdown uuid=$1\"."
						$xencmd vm-shutdown uuid="$1"
						if [[ "$?" -eq 0 ]] ;then
							logger_xen "Successfully shutdown VM \"$VM_NAME_FROM_UUID\" on second attempt."
						else
							if [[ $POWERSTATE != "halted" ]] ; then
								[[ $DEBUG = "ALL" || $DEBUG =~ .*shutdown.* ]] && logger_xen "About to: \"$xencmd vm-shutdown uuid=$1\"."
								logger_xen "Was still unable to normally shutdown VM \"$VM_NAME_FROM_UUID\". Will now attempt to use force."
								$xencmd vm-shutdown uuid="$1" force=true
								if [[ "$?" -eq 0 ]] ;then
									logger_xen "Successfully shutdown VM \"$VM_NAME_FROM_UUID\" on third and forceful attempt."
								else
									logger_xen "Was still unable to shutdown VM \"$VM_NAME_FROM_UUID\". Even using \"the force\" didn't help :\." "expose"
									continue
								fi
							fi

						fi
					fi
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

#find files to work on
for CHEVRON in $@; do
	[[ "$CHEVRON" = "$1" ]] && continue
	CHEVRONs="$CHEVRONs \"$CHEVRON"\"
	VM_LIST_FROM_CHEVRONs="$VM_LIST_FROM_CHEVRONs $( find $BackupLocation -type f -name *$CHEVRON* )"
	#statements
done


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

#Prepare server by deleting existing content
if [[ $SERVER_PREP = "enabled" ]] ; then
	logger_xen "" # log formatting
	logger_xen "SERVER_PREP was enabled in settings file, so will now delete all VMs on server."
	xen_xe_func " " "list_all_VMs_UUIDs"
	logger_xen "" # log formatting
	logger_xen "" # log formatting
	for VM in $VMs_on_server ; do
		xen_xe_func "$VM" "uuid_2_name"
		xen_xe_func "$VM" "keeper"
		if [[ -z $Phoenix_keeper ]]; then
		xen_xe_func "$VM" "delete"
		else
		logger_xen "Found a \"keeper\" tag for VM \"$VM_NAME_FROM_UUID\" with uuid of \"$VM\". It was \"$Phoenix_keeper\""
		logger_xen "" # log formatting
		logger_xen "" # log formatting
	fi
	done
else
	logger_xen "" # log formatting
	logger_xen "" # log formatting
	logger_xen "The SERVER_PREP variable was not enabled, so mass VMs deletion was skipped."
	logger_xen "" # log formatting
	logger_xen "" # log formatting
fi

#The work.
for VM in $VM_LIST_FROM_CHEVRONs; do
	logger_xen "Working on \"$VM\"."
	xen_xe_func "$VM" "import"
	logger_xen "" # log formatting
	logger_xen "" # log formatting
done
 
#verifier
if [[ $VERIFIER = "enabled" ]] ; then
	logger_xen "VERIFIER was enabled in settings file, so will now check VMs for guest tools heartbeat."
	logger_xen "" # log formatting
	xen_xe_func " " "list_all_VMs_UUIDs"
	for VM in $VMs_on_server ; do
		xen_xe_func "$VM" "keeper"
		if [[ -n $Phoenix_keeper ]]; then
			logger_xen "This VM is a \"keeper\", so will not \"verify\" it."
			logger_xen "" # log formatting
			logger_xen "" # log formatting
			continue
		fi
		Vcounter=0
		current_sec="$( date -u +%S )"; current_sec=$( echo $current_sec|sed 's/^0*//' )

		#don't try to asses a heartbeat befor a minute change
		while [[ $current_sec -ge 50 ]]; do
				sleep 1
				current_sec="$( date -u +%S )"; current_sec=$( echo $current_sec|sed 's/^0*//' )
		done
		xen_xe_func "$VM" "guest_tools_last_seen"
		ORG_GLS=$GLS
		[[ $DEBUG = "ALL" || $DEBUG =~ .*verifier.* ]] && logger_xen "For VM $VM, pre-starting ORG_GLS is: $ORG_GLS"
			if [[ $DEBUG = "ALL" || $DEBUG =~ .*reboots_disabled.* ]]; then
				logger_xen "skipped actually shutting down to save time"
			else
				xen_xe_func "$VM" "shutdown"
				xen_xe_func "$VM" "start"
				sleep $WARM_UP_DELAY
				[[ $DEBUG = "0" ]] && sleep $WARM_UP_DELAY
			fi
		
		xen_xe_func "$VM" "typer"
		if [[ $VM_TYPE = "pygrub" ]]; then 			
			Retry_counter=25
		else
			Retry_counter=60
		fi
		[[ $DEBUG = "ALL" || $DEBUG =~ .*verifier.* ]] && logger_xen "Retry_counter was set to: $Retry_counter"
		while [[ $GLS = $ORG_GLS || $GLS = "<not in database>" ]]; do
			if [[ $Vcounter -ge $Retry_counter ]] ;then
				logger_xen "Vcounter was $Vcounter and Retry_counter was $Retry_counter. So stopped waiting for VM."
				break
			fi
			[[ $DEBUG = "ALL" || $DEBUG =~ .*verifier.* ]] && logger_xen "wating for GLS to change"
			sleep 5
			xen_xe_func "$VM" "guest_tools_last_seen"
			let Vcounter=Vcounter+1
			[[ $DEBUG = "ALL" || $DEBUG =~ .*verifier.* ]] && logger_xen "Vcounter is: $Vcounter"
		done
	[[ $DEBUG = "ALL" || $DEBUG =~ .*verifier.* ]] && logger_xen "new GLS is $GLS"
	if [[ "$GLS" =~ .*"$( date -u +%H:%M )"* && "$GLS" =~ .*"$( date -u +%Y%m%d )"* ]] ; then
		xen_xe_func "$VM" "uuid_2_name"
		[[ $DEBUG = "ALL" || $DEBUG =~ .*verifier.* ]] && logger_xen "The new GLS for \"$VM_NAME_FROM_UUID\" does rufly contain the current time ^_^. Current time was seen as: $( date -u +%H:%M ) & $( date -u +%Y%m%d )"
		logger_xen "Was able to get a heartbeat from \"$VM_NAME_FROM_UUID\" with uuid of \"$VM\". It was \"$GLS\""
	else
		[[ $DEBUG = "ALL" || $DEBUG =~ .*verifier.* ]] && logger_xen "The new GLS  for \"$VM_NAME_FROM_UUID\" does NOT contain the current time??" "expose"
		logger_xen "FAILED to obtain a heartbeat from \"$VM_NAME_FROM_UUID\" with uuid of \"$VM\". :\\"
	fi
	xen_xe_func "$VM" "shutdown"
	logger_xen "" # log formatting
	logger_xen "" # log formatting
	done
else
	logger_xen "The VERIFIER variable was not enabled, so the verification was skipped. \"\$VERIFIER\" was set to: $VERIFIER."
fi

#Yey Done
logger_xen "Restore script has finished its run and will now Email the report."
Email_func "$Email_VAR" "Report"
