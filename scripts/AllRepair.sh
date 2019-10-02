# Script template taken from: https://gist.github.com/shakefu/2765260#file-example-sh
#set -e #exit on first error - not needed because of error handaling in script
#set -x #for debug: echo commands before execution

#set PYTHONPATH to z3 location
OLDPYTHONPATH=$PYTHONPATH
export PYTHONPATH="$OLDPYTHONPATH:/usr/lib/python2.7/dist-packages/z3"

# Option defaults
UNWIND=5
MUTATION=1
TRANSLATE=1
REPAIR=1
KEEP=0
TRANSLATIONOUT=0
REPAIROUT=0
BLOCK="basic"
INCREMENTAL="none"

# init arrays of code file and directory names 
FILES=()
DIRS=()
ALLFILES=()

# getopts string
# This string needs to be updated with the single character options (e.g. -f)
opts="ufmntsphr:"

# always clean before exit
clean(){
	# delete files created by script
	if [[ -f "creating_file" ]] && [[ $KEEP -ne 1 ]] && [[ $REPAIR -ne 0 ]]; then
		#echo "Last file created: $creating_file";
		rm "$creating_file"
	fi
	# restore PYTHONPATH
	export PYTHONPATH=$OLDPYTHONPATH
}
trap clean exit

# Gets the command name without path
cmd(){ echo `basename $0`; }

# Help command output
usage(){
echo "\
`cmd` [FileName...] [Option...]
-h, --help; Display this manual.
-u num, --unwind num; Set the unwinding bound to num (loops an function calls will be inlined num times). Default: 5.
-f func, --function func; Consider func as the entry point of the program (sets initial arguments of func non-deterministicly).
-m num, --mutation num; Set mutation level to num (num must be either 1 or 2). Default: 1.
-n func_list, --no-mut func_list; Do not mutate any code from functions in func_list. Argument func_list should be a list of function names, separated by commas. 
-t k, --timeout k; Sets a timeout of k seconds.
-s k, --size-limit k; Limits the repair size to k (only programs with at most k mutations at once will be inspected).
-p k, --program-limit k; Limits the number of inspected programs to k.
-r k, --repair-limit k; Stop after k possible repairs are found.
--group-files; Treat all c files as part of the same project and repair them all together (without this flag each c file is compiled, translated, and repaired individually).
--only-translate; Stop after translation phase, wihtout doing repair. When this option is set, the result is a <file>.gsmt2 file for each <file>.c in the input.
--only-repair; Start from repair, without translating first. When this option is set, a file named <file>.gsmt2 is expected to exist for every <file>.c in the input.
--keep-translation; Do not earse the intermediate gsmt2 files generated by the translation unit.
--translation-out; Save the output of the translation phase to a file (seperately for each input file).
--repair-out; Save the output of the repair phase to a file (seperately for each input file).  
--incremental method; Use 'method' for SMT incremental solving. 'method' should be either 'none' (non-incremental), 'pushpop' (push and pop soft constraints) or 'assumptions' (use assumptions to guard soft constraints). Default: none.  
Translation options (from CBMC):
--bounds-check; enable array bounds checks
--pointer-check; enable pointer checks
--memory-leak-check; enable memory leak checks
--div-by-zero-check; enable division by zero checks
--signed-overflow-check; enable signed arithmetic over- and underflow checks
--unsigned-overflow-check; enable arithmetic over- and underflow checks
--pointer-overflow-check; enable pointer arithmetic over- and underflow checks
--conversion-check; check whether values can be represented after type cast
--undefined-shift-check; check shift greater than bit-width
--float-overflow-check; check floating-point for +/-Inf
--nan-check; check floating-point for NaN
--no-built-in-assertions; ignore assertions in built-in library
--no-assertions; ignore user assertions
--no-assumptions; ignore user assumptions
--error-label label; check that label is unreachable
" | column -t -s ";"
}

# Invalid option error message
error(){
    echo "`cmd`: invalid option -- '$1'";
    echo "Try '`cmd` -h' for more information.";
    exit 1;
}

# File not found error message
file_error(){
    echo "File '$1' not found";
    exit 1;
}

# function to run CBMC
cbmc(){
	out_name=`echo "$1" | tr "/" "_"`
	out_name_no_extension="${out_name%.*}"

	echo "AllRepair: TRANSLATING ..."
	creating_file="$out_name_no_extension.gsmt2"
	if [[ $TRANSLATIONOUT -eq 1 ]]; then
		if [[ ! -d translation_out ]]; then
			mkdir translation_out
		fi
		../src/cbmc/cbmc "$@" --z3 --no-unwinding-assertions --no-propagation ${FUNCTION+"--function"} $FUNCTION ${UNWIND+"--unwind"} $UNWIND ${MUTATION+"--mutations"} $MUTATION ${NOMUT+"--no-mut"} $NOMUT ${ERRORLABEL+"--error-label"} $ERRORLABEL $ARRAYBOUND $POINTER $MEMORY $DIVBYZERO $SIGNEDOVERFLOW $UNSIGNEDOVERFLOW $POINTEROVERFLOW $CONVERSION $UNDEFINEDSHIFT $FLOATOVERFLOW $NAN $NOBUILTINASSERTIONS $NOASSERTIONS $NOASSUMPTIONS --outfile "$out_name_no_extension.gsmt2" &> "translation_out/$out_name_no_extension.tout"
	else
		../src/cbmc/cbmc "$@" --z3 --no-unwinding-assertions --no-propagation ${FUNCTION+"--function"} $FUNCTION ${UNWIND+"--unwind"} $UNWIND ${MUTATION+"--mutations"} $MUTATION ${NOMUT+"--no-mut"} $NOMUT ${ERRORLABEL+"--error-label"} $ERRORLABEL $ARRAYBOUND $POINTER $MEMORY $DIVBYZERO $SIGNEDOVERFLOW $UNSIGNEDOVERFLOW $POINTEROVERFLOW $CONVERSION $UNDEFINEDSHIFT $FLOATOVERFLOW $NAN $NOBUILTINASSERTIONS $NOASSERTIONS $NOASSUMPTIONS --outfile "$out_name_no_extension.gsmt2"	
	fi
	return $?
}

# function to run MARCO
marco(){
	out_name=`echo "$1" | tr "/" "_"`
	out_name_no_extension="${out_name%.*}"

	echo "AllRepair: SEARCHING FOR REPAIR ..."
	if [[ $REPAIROUT -eq 1 ]]; then
		if [[ ! -d repair_out ]]; then
			mkdir repair_out
		fi
		../python/batmarco.py "${out_name_no_extension}.gsmt2" ${TIMEOUT+"-T"} $TIMEOUT ${REPAIRLIMIT+"-n"} $REPAIRLIMIT ${SIZELIMIT+"-k"} $SIZELIMIT ${PROGRAMLIMIT+"-l"} $PROGRAMLIMIT ${INCREMENTAL+"--incremental"} $INCREMENTAL ${BLOCK+"--blockrepair"} $BLOCK --smt -v -s -a --smus &> "repair_out/${out_name_no_extension}.rout"
	else
		../python/batmarco.py "${out_name_no_extension}.gsmt2" ${TIMEOUT+"-T"} $TIMEOUT ${REPAIRLIMIT+"-n"} $REPAIRLIMIT ${SIZELIMIT+"-k"} $SIZELIMIT ${PROGRAMLIMIT+"-l"} $PROGRAMLIMIT ${INCREMENTAL+"--incremental"} $INCREMENTAL ${BLOCK+"--blockrepair"} $BLOCK --smt -v -s -a --smus
	fi
	return $?
}

# function for running allrepair after all preprocessing
allrepair(){
	echo ""
	echo "		Repairing file $@"
	echo ""
	if [[ $TRANSLATE -eq 1 ]]; then
		start_time=$(date +%s%3N)
		cbmc "$@"
		cbmc_res=$?
		end_time=$(date +%s%3N)
		translation_time=$(( $end_time - $start_time ))
		# Calculate time diff in ms (bash doesn't do float arithmetic):
		echo "AllRepair: Translation duration: $(($translation_time/1000)).$(($translation_time%1000))" 
		if [[ $cbmc_res -ne 10 ]]; then
			echo "AllRepair: ERROR DURING TRANSLATION"
		else
			echo "AllRepair: TRANSLATION PROCESS TERMINATED SUCCESSFULLY"		
		fi	
	fi
	if [[ $REPAIR -eq 1 ]] && ([[ $cbmc_res -eq 10 ]] || [[ $TRANSLATE -ne 1 ]]); then
		marco "$@"
		marco_res=$?
		echo "res = $marco_res"
		if [[ $marco_res -eq 0 ]]; then
			echo "AllRepair: SEARCH SPACE COVERED SUCCESSFULLY"
		elif [[ $marco_res -eq 2 ]]; then
			echo "AllRepair: TIMEOUT"
		elif [[ $marco_res -eq 3 ]]; then
			echo "AllRepair: REQUESTED NUMBER OF REPAIRS FOUND"
		elif [[ $marco_res -eq 4 ]]; then
			echo "AllRepair: MAX NUMBER OF MUTATED PROGRAMS INSPECTED"
		elif [[ $marco_res -eq 5 ]]; then
			echo "AllRepair: MAX MUTATION SIZE REACHED"
		elif [[ $marco_res -eq 6 ]]; then
			echo "AllRepair: EXTERNALLY TERMINATED"
		elif [[ $marco_res -eq 7 ]]; then
			echo "AllRepair: INTERRUPTED"
		elif [[ $marco_res -eq 8 ]]; then
			echo "AllRepair: ORIGINAL PROGRAM IS CORRECT"
		else		
			echo "AllRepair: ERROR DURING REPAIR"
		fi
	fi
	out_name=`echo $file | tr "/" "_"`
	out_name_no_extension="${out_name%.*}"
	if  [[ $KEEP -ne 1 ]] && [[ $REPAIR -eq 1 ]] && [[ $TRANSLATE -eq 1 ]] && [[ -f "${out_name_no_extension}.gsmt2" ]]; then
		rm "${out_name_no_extension}.gsmt2"
	fi
	echo " ____________________________________________________________________________________"
}

# There's two passes here. The first pass handles the long options and
# any short option that is already in canonical form. The second pass
# uses `getopt` to canonicalize any remaining short options and handle
# them
for pass in 1 2; do
    while [ -n "$1" ]; do
        case $1 in
            --) shift; break;;
            -*) case $1 in
					-h|--help)     		usage; exit 0;;
					-u|--unwind)     	UNWIND=$2; shift;;
            		-f|--function)   	FUNCTION=$2; shift;;
            		-m|--mutation)   	MUTATION=$2; shift;;
        			-n|--no-mut)        NOMUT=$2; shift;;
            		-t|--timeout)      	TIMEOUT=$2; shift;;
            		-s|--size-limit)    SIZELIMIT=$2; shift;;
            		-p|--program-limit) PROGRAMLIMIT=$2; shift;;
            		-r|--repair-limit) 	REPAIRLIMIT=$2; shift;;
					--only-translate)	REPAIR=0;;
					--only-repair)		TRANSLATE=0;;
					--keep-translation) KEEP=1;;
					--translation-out)	TRANSLATIONOUT=1;;
					--repair-out)		REPAIROUT=1;;
					--block-incorrect)		BLOCK=$2; shift;;
					--incremental)		INCREMENTAL=$2; shift;;
					--error-label)		ERRORLABEL=$2; shift;;
					--group-files)		GROUPFILES=1;;
					--bounds-check)		ARRAYBOUND="--bounds-check";;
					--pointer-check)	POINTER="--pointer-check";;
					--memory-leak-check)	MEMORY="--memory-leak-check";;
					--div-by-zero-check)	DIVBYZERO="--div-by-zero-check";;
					--signed-overflow-check)	SIGNEDOVERFLOW="--signed-overflow-check";;
					--unsigned-overflow-check)	UNSIGNEDOVERFLOW="--unsigned-overflow-check";;
					--pointer-overflow-check)	POINTEROVERFLOW="--pointer-overflow-check";;
					--conversion-check)		CONVERSION="--conversion-check";;
					--undefined-shift-check)	UNDEFINEDSHIFT="--undefined-shift-check";;
					--float-overflow-check)		FLOATOVERFLOW="--float-overflow-check";;
					--nan-check)		NAN="--nan-check";;
					--no-built-in-assertions)	NOBUILTINASSERTIONS="--no-built-in-assertions";;
					--no-assertions)		NOASSERTIONS="--no-assertions";;
					--no-assumptions)		NOASSUMPTIONS="--no-assumptions";;
            		--*)	error $1;;
       				-*)	if [ $pass -eq 1 ]; then ARGS="$ARGS $1";
                               else error $1; fi;;
        		esac;;
	    	*.c) if [[ -f $1 ]]; then FILES+=("${1}"); else file_error $1; fi;;
            *)  if [[ -d $1 ]]; then DIRS+=("$1");
				else
                  if [[ $pass -eq 1 ]]; then ARGS="$ARGS $1";
                  else error $1; fi;
				fi;;
		esac
        shift
    done
    if [[ $pass -eq 1 ]]; then ARGS=`getopt $opts $ARGS`
        if [[ $? != 0 ]]; then echo "Try '`cmd` -h' for more information."; exit 2; fi; set -- $ARGS
    fi
done


#check parameter integrity
if [[ ${#FILES[@]} == 0 ]] && [[ ${#DIRS[@]} == 0 ]]; then
	echo "You must specify at least one input file (<file>.c) or directory"
	exit 1
fi
if [[ $BLOCK == "" ]]; then
	echo "Argument --block-incorrect should be followed by one of the following methods: basic, slicing or generalization."
	exit 1
fi
if [[ $BLOCK != "basic" ]] && [[ $BLOCK != "slicing" ]] && [[ $BLOCK != "generalization" ]]; then
	echo "Wrong method for --block-incorrect ($BLOCK). Method can be either basic, slicing or generalization."
	exit 1
fi
if [[ $INCREMENTAL == "" ]]; then
	echo "Argument --incremental should be followed by one of the following methods: none, pushpop or assumptions."
	exit 1
fi
if [[ $INCREMENTAL != "none" ]] && [[ $INCREMENTAL != "pushpop" ]] && [[ $INCREMENTAL != "assumptions" ]]; then
	echo "Wrong method for --incremental ($INCREMENTAL). Method can be either none, pushpop or assumptions."
	exit 1
fi
if (( $MUTATION != 1 )) && (( $MUTATION != 2 )); then
	echo "Invalid mutation level ($MUTATION). Mutation level can be either 1 or 2."
	exit 1
fi


# Handle positional arguments
if [ -n "$*" ]; then
    echo "`cmd`: Extra arguments -- $*"
	echo "Arguments should be either a C file, a directory or a valid option."
    echo "Try '`cmd` -h' for more information."
    exit 1
fi


# Print settings
echo "AllRepair: SETTINGS: "
if [[ ! -z "$UNWIND" ]]; then
	echo "Unwinding bound=$UNWIND "
fi
if [[ ! -z "$MUTATION" ]]; then
	echo "Mutation level=$MUTATION "
fi
if [[ ! -z "$TIMEOUT" ]]; then
	echo "Timeout=$TIMEOUT "
fi
if [[ ! -z "$SIZELIMIT" ]]; then
	echo "Max repair size=$SIZELIMIT "
fi
if [[ ! -z "$PROGRAMLIMIT" ]]; then
	echo "Max programs to check=$PROGRAMLIMIT "
fi
if [[ ! -z "$REPAIRLIMIT" ]]; then
	echo "Max repairs to find=$REPAIRLIMIT "
fi
if [[ ! -z "$FUNCTION" ]]; then
	echo "Function to repair=$FUNCTION "
fi
if [[ ! -z "$ERRORLABEL" ]]; then
	echo "--error-label $ERRORLABEL "
fi
if [[ ! -z "$ARRAYBOUND" ]]; then
	echo "Array out of bounds check: on "
fi
if [[ ! -z "$POINTER" ]]; then
	echo "Pointer check: on "
fi
if [[ ! -z "$MEMORY" ]]; then
	echo "Memory leak check: on "
fi
if [[ ! -z "$DIVBYZERO" ]]; then
	echo "Div by 0 check: on "
fi
if [[ ! -z "$SIGNEDOVERFLOW" ]]; then
	echo "--signed-overflow-check "
fi
if [[ ! -z "$UNSIGNEDOVERFLOW" ]]; then
	echo "--unsigned-overflow-check "
fi
if [[ ! -z "$POINTEROVERFLOW" ]]; then
	echo "--pointer-overflow-check "
fi
if [[ ! -z "$CONVERSION" ]]; then
	echo "--conversion-check "
fi
if [[ ! -z "$UNDEFINEDSHIFT" ]]; then
	echo "--undefined-shift-check "
fi
if [[ ! -z "$FLOATOVERFLOW" ]]; then
	echo "--float-overflow-check "
fi
if [[ ! -z "$NAN" ]]; then
	echo "--nan-check "
fi
if [[ ! -z "$NOBUILTINASSERTIONS" ]]; then
	echo "--no-built-in-assertions "
fi
if [[ ! -z "$NOASSERTIONS" ]]; then
	echo "--no-assertions "
fi
if [[ ! -z "$NOASSUMPTIONS" ]]; then
	echo "--no-assumptions "
fi
if [[ ! -z "$NOMUT" ]]; then
	echo "Functions to avoid mutating=$NOMUT "
fi
if [[ ! -z "$INCREMENTAL" ]]; then
	echo "SMT incremental method=$INCREMENTAL "
fi
if [[ ! -z "$BLOCK" ]]; then
	echo "Blocking method=$BLOCK "
fi
if [[ ! -z "$GROUPFILES" ]]; then
	echo "Using multiple files mode "
fi
# Other settings:
# echo "BLOCK=$BLOCK"
# echo "FILES=$FILES"
# echo "DIRS=$DIRS"


# get individual filenames from FILES and DIRS
# recursively search for c files in dirs and add to ALLFILES
DIRSLEN=${#DIRS[@]}
for (( i=0; i<$DIRSLEN; i++ )); do 
	# find c files in dir (including sub-directories) and save 'find' results to array
	# https://stackoverflow.com/questions/23356779/how-can-i-store-the-find-command-results-as-an-array-in-bash
	count=0
	while IFS=  read -r -d $'\0'; do
		ALLFILES+=("$REPLY")
		(( count+=1 ))
	done < <(find "${DIRS[$i]}" -name '*.c' -print0)
	if (( count==0 )); then
		echo "WARNING: no c files found in ${DIRS[$i]}"
	else
		echo "$count c files found in ${DIRS[$i]}"
	fi
done
# also add individual files to ALLFILES
FILESLEN=${#FILES[@]}
for (( i=0; i<$FILESLEN; i++ )); do 
	ALLFILES+=("${FILES[$i]}")
done
# if no c files were found - exit
ALLFILESLEN=${#ALLFILES[@]}
if (( $ALLFILESLEN==0 )); then
	echo "No c files found in input. Exiting."
	exit 1
fi


#Procces files
if [[ ! -z "$GROUPFILES" ]]; then
	allrepair "${ALLFILES[@]}"
else
	for file in "${ALLFILES[@]}" ; do
		allrepair "$file"
	done
fi

