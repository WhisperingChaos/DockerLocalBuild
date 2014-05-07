#!/bin/bash
###############################################################################
#
#  Purpose:
#    Issue test abort message due to some failed assertion.
#
#  Input:
#    $1 - Line number within script that issued abort.
#    $2 - Abort message detail.
#
#  Return:
#    Terminate this script with a return code of 1.
#
################################################################################
function Abort () {
  echo "Abort: Line#: $1 : $2" >&2;
  echo "Abort: Test failure encountered">&2;
  exit 1;
}
###############################################################################
#
#  Purpose:
#    Create one or more containers from the current version of the specified
#    image name.
#
#  Input:
#    $1 - LINENO
#    $2 - docker image name.
#    $3 - Number of containers to create.
#    $4 - Next Temporary file index to record container GUID.
#    $5 - KR - Keep running.
#
#  Return:
#    0 - Successfully created all containers.
#    Otherwise Abort.
#
###############################################################################
function ContainerCreate () {
  local RunOptions= 
  if [ "$5" == "KR" ]; then RunOptions='-d -i'; fi
  local ixFile
  for ((ixFile=$4; $ixFile < ($3+$4); ixFile++ )); do
    docker run $RunOptions --cidfile="${TestfilePrefix}$ixFile" $2 > /dev/nul
  done
  ContainerExistAssert $LINENO $4 $3
  return 0;
}
###############################################################################
#
#  Purpose:
#    Test the existance of a container.
#
#  Input:
#    $1 - Container Id
#
#  Return:
#    0 - Container exists.
#    1 - Otherwise.
#
################################################################################
function ContainerExist () {
  local searchGUID=${1:0:12};
  local dockerGUID=`docker ps -a | grep ^$searchGUID`;
  dockerGUID=${dockerGUID:0:12}
  if [ "$dockerGUID" == "$searchGUID" ]; then return 0; fi
  return 1;
}
###############################################################################
#
#  Purpose:
#    Ensure that given range of containers exist.
#
#  Input:
#    $1 - LINENO
#    $2 - Number of containers to check.
#    $3 - Start of range.
#
#  Return:
#    0 - Assertion true.
#    Otherwise Abort.
#
###############################################################################
function ContainerExistAssert (){
 local ixFile
 for ((ixFile=$3; $ixFile < ($3+$2); ixFile++ )); do 
    cat "${TestfilePrefix}$ixFile" | xargs -I GUID bash -c 'ContainerExist GUID'
    if [ $? -ne 0 ]; then Abort $1 "Containter missing when it should exist.  See ${TestfilePrefix}$ixFile"; fi
  done
  return 0;
}
###############################################################################
#
#  Purpose:
#    Ensure that given range of containers have been deleted.
#
#  Input:
#    $1 - LINENO
#    $2 - Number of containers to check.
#    $3 - Start of range.
#
#  Return:
#    0 - Assertion true.
#    Otherwise Abort.
#
###############################################################################
function ContainerDeleteAssert (){
  local ixFile
  for ((ixFile=$3 ; $ixFile < ($3+$2) ; ixFile++ )); do 
    cat "${TestfilePrefix}$ixFile" | xargs -I GUID bash -c 'ContainerExist GUID'
    if [ $? -eq 0 ]; then Abort $1 "Containter exists when it should have been deleted.  See ${TestfilePrefix}$ixFile"; fi
  done
  return 0;
}
###############################################################################
#
#  Purpose:
#    Ensure provided image GUID has been removed from the local docker repository.
#
#  Input:
#    $1 - LINENO
#    $2 - docker image GUID.
#
#  Return:
#    0 - Assertion true.
#    Otherwise Abort.
#
###############################################################################
function DockerReprositoryImageDeleteAssert (){
  docker inspect -format="{{.id}}" "$2" >/dev/nul 2>/dev/nul
  if [ $? -eq 0 ]; then Abort $1 "Docker image exists but should have been deleted: $2."; fi
  return 0;
}
###############################################################################
#
#  Purpose:
#    Ensure provided image GUID exists in local docker repository.
#
#  Input:
#    $1 - LINENO
#    $2 - docker image GUID.
#
#  Return:
#    0 - Assertion true.
#    Otherwise Abort.
#
###############################################################################
function DockerReprositoryImageExistsAssert (){
  docker inspect -format="{{.id}}" "$2" >/dev/nul 2>/dev/nul
  if [ $? -ne 0 ]; then Abort $1 "Docker image should exist but doesn't: $2."; fi
  return 0;
}
###############################################################################
#
#  Purpose:
#    Obtain the most recent GUID for given image name output it to
#    sysout.
#
#  Input:
#    $1 - LINENO
#    $2 - docker image name.
#
#  Return:
#    0 - Successful
#    sysout - reflects the GUID.
#    Otherwise Abort.
#
###############################################################################
function DockerReprositoryImageAssign (){
  local ImageGUID=`docker inspect -format="{{.id}}" "$2" 2>/dev/nul`;
  if [ $? -ne 0 ]; then Abort $LINENO "Docker image name: $2 doesn't exist."; fi
  if [ "$ImageGUID" == "" ]; then Abort $LINENO "Docker image GUID for name: $2 not provided."; fi
  echo "$ImageGUID";
  return 0;
}
###############################################################################
#
#  Purpose:
#    Change the content of a Dockerfile resource called ChangeVersion.
#    Assumes that ChangeVersion is a file that's included in the resulting
#    image.
#
#  Input:
#    $1 - docker image name.
#
###############################################################################
function ImageChangeVersion (){
  echo "$RANDOM" > "./$1/ChangeVersion";
}	
###############################################################################
#
#  Purpose:
#    Create a specific image with some number of containers ensuring
#    that both the image(s) and container(s) are created.
#
#  Input:
#    $1 - LINENO
#    $2 - docker image name.
#    $3 - Total number of image GUI1Ds expected in Image GUID List for component.
#    $4 - Number of containers to create.
#    $5 - Next Temporary file index to record container GUID.
#
#  Return:
#    0 - Successfully created image and/or desired container instances.
#    Otherwise Abort.
#
###############################################################################
function ImageContainerCreate (){
  make ${2}.img > /dev/nul 2> /dev/nul
  if [ $? -ne 0 ]; then Abort $1 "Build of: $2 failed"; fi
  ImageGUIDListAssert $1 "$2" $3
  ContainerCreate $LINENO "$2" $4 $5
  return 0;
}
###############################################################################
#
#  Purpose:
#    Remove containers and/or images via make.
#
#  Input:
#    $1 - LINENO
#    $2-$5 - Various "make Remove" arguments.
#
#  Return:
#    0 - make Remove operation successful.
#    Otherwise Abort.
#
###############################################################################
function ImageContainerRemove (){
  make Remove $2 $3 $4 $5 > /dev/nul 2> /dev/nul
  if [ $? -ne 0 ]; then Abort $1 "Remove failed: parameters: $2 $3 $4 $5"; fi
  return 0
}
###############################################################################
#
#  Purpose:
#    Report on containers and/or images via make.
#
#  Input:
#    $1 - LINENO
#    $2-$5 - Various "make Show" arguments.
#
#  Return:
#    0 - make Show operation successful.
#    Otherwise Abort.
#
###############################################################################
function ImageContainerShow (){
  make Show $2 $3 $4 $5
  if [ $? -ne 0 ]; then Abort $1 "Show failed: parameters: $2 $3 $4 $5"; fi
  return 0
}
###############################################################################
#
#  Purpose:
#    Check Image GUID List to ensure it has proper number of GUIDs.
#
#  Input:
#    $1 - LINENO	
#    $2 - docker image name.
#    $3 - Expected number of GUIDs.
#
#  Return:
#    0 - GUID List updated correctly.
#    Otherwise Abort.
#
###############################################################################
ImageGUIDListAssert (){
  if [ $3 -lt 1 ]; then 
    if [ -e "./image/${2}.img" ]; then Abort $1 "Image GUID List for: ./image/${2}.img shouldn't exist."; fi
    return 0;
  fi
  if ! [ -e "./image/${2}.img" ]; then Abort $1 "Image GUID List for: ./image/${2}.img should exist."; fi
  local GUIDcnt=`wc -l "./image/${2}.img"| awk '{print $1;}'`
  if [ $GUIDcnt -ne $3 ]; then Abort $1 "Image GUID List for: ./image/${2}.img contains $GUIDcnt but $3 was expected."; fi
  return 0;
}
##############################################################################
#
#  Purpose:
#    Check local docker repository for an image with the provided name.
#
#  Input:
#    $1 - docker image name.
#
#  Return:
#    0 - Image exists.
#    1 - Nonexistent image.
#
##############################################################################
function ImageNameExist () {
  docker inspect "$1" > /dev/nul 2>/dev/nul;
  if [ $? -ne 0 ]; then return 1; fi
 return 0;
}
###############################################################################
#
#  Purpose:
#    Run report with provided options and cache its output for later scanning.
#
#  Assumption:
#    Checking the most recent ReporRun execution.
#    The shell variable 'reportCache' will be used to contain in memory cache.
#
#  Input:
#    $1 - LINENO
#    $2 - Expected Report line total.
#
#  Return:
#    0 - Assertion true.
#    Otherwise Abort
#
###############################################################################
function ReportLineCntAssert () {
  if [ "$2" == "" ]; then Abort $1 "Please specify expected line count."; fi
  if [ ${#reportCache[@]} -ne $2 ]; then Abort $1 "Line count of: '${#reportCache[@]}' different from expected: '$2'"; fi
  return 0
}
###############################################################################
#
#  Purpose:
#    Run report with provided options and cache its output for later scanning.
#
#  Assumption:
#    Provided arguments do not contain embedded whitespace.
#    The shell variable 'reportCache' will be used to contain in memory cache
#    and its contents are destroyed and recreated every time this function
#    is called.
#
#  Input:
#    $1 - LINENO
#    $2 - List of N tokens to pass to Show command.
#
#  Return:
#    0 - Assertion true.
#    Otherwise Abort
#
###############################################################################
function ReportRun () {
 unset reportCache
 SYSOUTcacheRecord 'reportCache' "ImageContainerShow $1 ${*:2}"
 if [ $? -ne 0 ]; then Abort $1 "Problem with Show. Parameters report with: '${@:2}'"; fi
}
###############################################################################
#
#  Purpose:
#    Scan provided stream for list of tokens. Tokens are compared on word boundaries
#    using grep.
#
#  Assumption:
#    Recorded SYSOUT stream to 'reportCache' shell variable.
#    Provided arguments do not contain whitespace.
#
#  Input:
#    $1 - LINENO
#    $2 - Scan operation:
#         'I' - Include
#         'E' - Exclude
#    $3 - List of N tokens to check.
#    SYSIN - Stream of tokens to search.
#
#  Return:
#    0 - Assertion true.
#    Otherwise Abort
#    SYSOUT - When about one or more tokens that violated scan operation.
#             Otherwise, nothing. 
#
###############################################################################
function ReportScanTokenAssert (){
  local operName
  local operMess
  if   [ "$2" == 'I' ]; then
    operName='Include';
    operMess='not found'
  elif [ "$2" == 'E' ]; then
    operName='Exclude'
    operMess='found'
 else
    Abort $1 "Invalid scan operation specified: '$2'"
  fi 
  local -i tokenCnt
  tokenCnt=$(( $#-2 ))
  if [ $tokenCnt -lt 1 ]; then Abort $1 "Must provide at least one search token!"; fi
  SYSOUTcachePlayback 'reportCache' |  StreamScan "$2" ${@:3}
  if [ $? -ne 0 ]; then Abort $1 "$operName tokens $operMess."; fi
}
###############################################################################
#
#  Purpose:
#    Scan provided report for list of tokens and ensure given token
#    is completely excluded from the report. Tokens are compared on word boundaries
#    using grep.
#
#  Assumption:
#    Provided arguments do not contain whitespace.
#
#  Input:
#    $1 - LINENO
#    $2 - List of N tokens to check for excusion.  Tokens may include
#         limited set of regular expressons
#    SYSIN - Stream of tokens to search.
#
#  Return:
#    0 - Assertion true.
#    Otherwise Abort
#    SYSOUT - When about one or more tokens that violated scan operation.
#             Otherwise, nothing. 
#
###############################################################################
function ReportScanTokenExcludeAssert (){
  ReportScanTokenAssert "$1" 'E' ${@:2}
  return 0;
}
###############################################################################
#
#  Purpose:
#    Scan provided report for list of tokens and ensure given token
#    exists somewhere in report. Tokens are compared on word boundaries
#    using grep.
#
#  Assumption:
#    Provided arguments do not contain whitespace.
#
#  Input:
#    $1 - LINENO
#    $2 - List of N tokens to check for existance.  Tokens may include
#         limited set of regular expressons
#    SYSIN - Stream of tokens to search.
#
#  Return:
#    0 - Assertion true.
#    Otherwise Abort
#    SYSOUT - When about one or more tokens that violated scan operation.
#             Otherwise, nothing. 
#
###############################################################################
function ReportScanTokenIncludeAssert (){
  ReportScanTokenAssert "$1" 'I' ${@:2}
  return 0;
}
###############################################################################
#
#  Purpose:
#    Scan provided stream for list of tokens.  An inclusive scan tests
#    that all provided tokens are mentioned somewhere in the stream.  While
#    an exclusive scan examines the stream to ensure that none of the tokens
#    appear in it.
#
#  Input:
#    $1 - Include/Exclude operator:
#           I - All specified tokens must appear.
#           E - All specified tokens must be absent
#    $2 - list of N tokens to check for existance.
#    SYSIN - Stream to inspect.
#
#  Return:
#    0 - When Exclude: no provided tokens exist in stream.
#        When Include: all tokens exist in stream.
#    1 - Violation detected
#    SYSOUT - When violation occurs, variable name assigned problem token value.
#
###############################################################################
function StreamScan () {
  local -a aTokenFnd
  local line
  local violation
  violation=true
  while read line; do
    local token
    local -i tokenFndIx=0
    for token in ${@:2}
    do
      if [ "${aTokenFnd[tokenFndIx]}" != 'X' ]; then
        echo "$line" | grep -w "$token" > /dev/nul
        if [ $? -eq 0 ]; then
          aTokenFnd[tokenFndIx]='X'
        else
          aTokenFnd[tokenFndIx]='A'
        fi
      fi
      let ++tokenFndIx
    done
    local -i iter
    local -i tokenFndCnt=0
    local -i tokenFndNotCnt=0
    for (( iter=0; $iter < $tokenFndIx; iter++ )); do
      if [ "${aTokenFnd[$iter]}" == 'X' ]; then let ++tokenFndCnt; continue; fi
      let ++tokenFndNotCnt;
    done
    if [ "$1" == 'I' ]; then
      if [ $tokenFndCnt -eq $tokenFndIx ]; then
        violation=false
        break
      fi
      violation=true
    elif [ "$1" == 'E' ]; then
      if [ $tokenFndCnt -ne 0 ]; then
        violation=true
      else
        violation=false
      fi
      continue
    else
      Abort $LINENO "Scan operator: '$1' invalid"
    fi
  done
  if [ "$violation" = true ]; then
    TokensCausingViolation "$1" 'aTokenFnd' ${@:2}
  fi
  if [ "$violation" = false ]; then return 0; fi
  return 1
}
###############################################################################
#
#  Purpose:
#    Truncate GUID to conform to GUIDs that appear on Docker reports.
#
#  Input:
#    $1 - A GUID of 12 or more charaters.
#
#  Return:
#    SYSOUT - A GUID of exactly 12 characters.
#
###############################################################################
function ReportGUIDformat () {
  echo "${1:0:12}"
}
###############################################################################
#
#  Purpose:
#    Output one or more tokens to SYSOUT representing ones that violated
#    the scan operator's constraint.
#
#  Input:
#    $1 - Include/Exclude operator:
#           I - All specified tokens must appear.
#           E - All specified tokens must be absent
#    $2 - name of array recording the existance/absence of a given token
#    $3 - list of N tokens provided to the scan operaton.
#    SYSIN - Stream to inspect.
#
#  Return:
#    SYSOUT - Each variable responsible for the violation of scan operator.
#
###############################################################################
function TokensCausingViolation () {
  local searchOper
  if   [ "$1" == 'I' ]; then
    searchOper='!='
  elif [ "$1" == 'E' ]; then
    searchOper='=='
  else
    echo "Abort: $LINENO Scan operator: '$1' invalid">&2 ; exit 1
  fi
  local arrayDeref
  arrayDeref=`echo \$\{#$2[\@]\}`
  local -i arraySize
  eval arraySize=$arrayDeref
  local -i iter
  for (( iter=0; iter < $arraySize; iter++ )); do
    local arrayCell
    arrayDeref=`echo \$\{\$2\[$iter\]\}`
    eval arrayCell=$arrayDeref
    if [ "$arrayCell" $searchOper 'X' ]; then
      local -i paramPos
      let paramPos=3+iter
      echo "${!paramPos}"
    fi
  done
  return 0;
}
###############################################################################
#
#  Purpose:
#    Playback an in memory cache of a SYSOUT.  A bash array implements the cache.
#
#  Input:
#    $1 - Array name to contain cache.
#
#  Output:
#    SYSOUT - Reflects output generated by echoing each array element.
#
###############################################################################
function SYSOUTcachePlayback () {
  local -i lineCnt
  local -i iter
  local arrayDeref
  arrayDeref=`echo \$\{#$1[\@]\}`
  eval lineCnt=$arrayDeref
  for (( iter=0; iter < lineCnt; iter++ )); do
    arrayDeref=`echo \$\{$1[\$iter\]\}`
    eval echo "$arrayDeref"
  done
}
###############################################################################
#
#  Purpose:
#    Create an in memory cache of a SYSOUT.  A bash array implements the cache.
#
#  Assumption:
#    This function must execute within the same shell instance that declared
#    the provided array, otherwise, it cannot update this same reference 
#    with the output of SYSOUT.
#
#  Input:
#    $1 - Array name to contain cache.
#    $2 - The name of a function/command sequence generating output to SYSOUT
#
###############################################################################
function SYSOUTcacheRecord () {
  declare -i iter
  local line
  local arrayDeref
  iter=0
  while read line; do
    arrayDeref=`echo $1\[$iter\]=\'$line\'`
    eval $arrayDeref
    iter+=1;
  done < <($2)
  return 0;	
}
##############################################################################
#
#  Purpose:
#    Remove a range of temporary test files.
#
#  Input:
#    $1 - "All" to remove every file.
#
#  Return:
#    0 - Removed at least one file.
#    Othewise Abort because the request failed.
#
##############################################################################
function TestFileDelete (){
  if [ "$1" == "All" ]; then
    rm ${TestfilePrefix}*;
    if [ $? -ne 0 ]; then Abort $LINENO "Request to delete temporary test files failed."; fi
    return 0;
  fi
  Abort $LINENO "Delete range not written yet."
}
###############################################################################
#
#  Purpose:
#    Setup & verify test environment.
#
###############################################################################
# Make the function ContainerExist directly available to child processes.
export -f ContainerExist
# All files created by runing the test will be assigned this prefix.  This
# prefix acts as a namespace and facilitates the cleanup of the environment
# once all the tests have run successfully
TestfilePrefix=MakefileTest_
if ! [ -e makefile ]; then Abort $LINENO "Test requires "makefile" and this script: $0 be colocated in the same directory"; fi
#  See previous test has failed leaving temporary files behind.
ls ${TestfilePrefix}* > /dev/null  2>/dev/null
if [ $? -eq 0 ]; then Abort $LINENO "Temporary Test files with prefix of: $TestfilePrefix already exist."; fi
#  See previous test has already created the image.
ImageNameExist sshserver
if [ $? -eq 0 ]; then Abort $LINENO "A docker image with name of: sshserver already exists."; fi
ImageNameExist mysql
if [ $? -eq 0 ]; then Abort $LINENO "A docker image with name of: mysql already exists."; fi
###############################################################################
#
#  Test 1:
#    Create a Component and one container. 
#
###############################################################################
echo "Test 1: Create image of: sshserver and one container."
ImageContainerCreate $LINENO "sshserver" 1 1 1
sshserverID_1=`DockerReprositoryImageAssign $LINENO "sshserver"`
ReportRun $LINENO type=ps idscope=All complist=All dockerOpts=-a
ReportScanTokenIncludeAssert $LINENO 'CONTAINER' 'IMAGE' 'sshserver:latest'
ReportLineCntAssert $LINENO 2
ReportRun $LINENO type=images idscope=All complist=All
ReportScanTokenIncludeAssert $LINENO 'REPOSITORY' 'VIRTUAL' `ReportGUIDformat "$sshserverID_1"`
echo "Test 1: Success."
###############################################################################
#
#  Test 2:
#    Remove the newly created container.  There should only be one.
#
#  Depends on:
#    Test 1
#
###############################################################################
echo "Test 2: Remove the container created from: sshserver."
ImageContainerRemove $LINENO restrict=OnlyContainers idscope=Current complist=sshserver.img
ContainerDeleteAssert $LINENO 1 1;
TestFileDelete All
ImageGUIDListAssert $LINENO "sshserver" 1 
ReportRun $LINENO type=ps idscope=All complist=All dockerOpts=-a
ReportScanTokenIncludeAssert $LINENO 'CONTAINER' 'IMAGE'
ReportScanTokenExcludeAssert $LINENO 'sshserver:latest'
ReportLineCntAssert $LINENO 1
ReportRun $LINENO type=images idscope=Current complist=sshserver.img
ReportScanTokenIncludeAssert $LINENO 'REPOSITORY' 'VIRTUAL' `ReportGUIDformat "$sshserverID_1"`
ReportLineCntAssert $LINENO 2
echo "Test 2: Success"
###############################################################################
#
#  Test 3:
#    Remove the image.  Since there is only one image version, its 
#    Image GUID List should be deleted from the Image Catalog.
#
#  Depends on:
#    Test 2
#
###############################################################################
echo "Test 3: Remove the only image version of sshserver."
DockerReprositoryImageExistsAssert $LINENO "$sshserverID_1"
ImageContainerRemove $LINENO idscope=Current complist=sshserver.img
ImageGUIDListAssert $LINENO "sshserver" 0
DockerReprositoryImageDeleteAssert $LINENO "$sshserverID_1"
ReportRun $LINENO type=ps idscope=All complist=All dockerOpts=-a
ReportLineCntAssert $LINENO 0
echo "Test 3: Success."
###############################################################################
#
#  Test 4:
#    Create two versions of the same image and two containers for each version. 
#
#  Depends on:
#    Test 3 or an empty Image Catalog
#
###############################################################################
echo "Test 4: Create two versions of: sshserver and two containers for each version"
ImageContainerCreate $LINENO "sshserver" 1 2 1
sshserverID_1=`DockerReprositoryImageAssign $LINENO "sshserver"`
ImageChangeVersion "sshserver"
ImageContainerCreate $LINENO "sshserver" 2 2 3
sshserverID_2=`DockerReprositoryImageAssign $LINENO "sshserver"`
ReportRun $LINENO type=ps idscope=All complist=All dockerOpts=-a
ReportScanTokenIncludeAssert $LINENO 'CONTAINER' 'IMAGE' 'sshserver:latest'
ReportLineCntAssert $LINENO 5
ReportRun $LINENO type=ps idscope=AllExceptCurrent complist=All dockerOpts=-a
ReportScanTokenIncludeAssert $LINENO 'CONTAINER' 'IMAGE'
ReportScanTokenExcludeAssert $LINENO 'sshserver:latest'
ReportLineCntAssert $LINENO 3
ReportRun $LINENO type=images idscope=All complist=All
ReportScanTokenIncludeAssert $LINENO 'REPOSITORY' 'VIRTUAL' `ReportGUIDformat "$sshserverID_1"` `ReportGUIDformat "$sshserverID_2"`
ReportLineCntAssert $LINENO 3
ReportRun $LINENO type=images idscope=Current complist=All
ReportScanTokenIncludeAssert $LINENO 'REPOSITORY' 'VIRTUAL' `ReportGUIDformat "$sshserverID_2"`
ReportScanTokenExcludeAssert $LINENO `ReportGUIDformat "$sshserverID_1"`
ReportLineCntAssert $LINENO 2
echo "Test 4: Success."
###############################################################################
#
#  Test 5:
#    Delete two containers for oldest version but keep both images and 
#    containers associated with most recent version.
#
#  Depends on:
#    Test 4
#
###############################################################################
echo "Test 5: Delete the two containers associated to the oldest image versions of: sshserver."
ImageContainerRemove $LINENO restrict=OnlyContainers idscope=AllExceptCurrent complist=sshserver.img
if [ $? -ne 0 ]; then Abort $LINENO "Remove of image: sshserver failed"; fi
ContainerDeleteAssert $LINENO 2 1
DockerReprositoryImageExistsAssert $LINENO "$sshserverID_1"
DockerReprositoryImageExistsAssert $LINENO "$sshserverID_2"
ImageGUIDListAssert $LINENO "sshserver" 2
ContainerExistAssert $LINENO 2 3
echo "Test 5: Success."
###############################################################################
#
#  Test 6:
#    Delete oldest image but keep most recent image and its two containers.
#
#  Depends on:
#    Test 5
#
###############################################################################
echo "Test 6: Delete the oldest image versions of: sshserver but keep most recent image and its containers."
ImageContainerRemove $LINENO idscope=AllExceptCurrent complist=sshserver.img
ImageGUIDListAssert $LINENO "sshserver" 1
DockerReprositoryImageDeleteAssert $LINENO "$sshserverID_1"
DockerReprositoryImageExistsAssert $LINENO "$sshserverID_2"
ContainerExistAssert $LINENO 2 3
echo "Test 6: Success."
###############################################################################
#
#  Test 7:
#    Delete the current image version and its two containers.
#
#  Depends on:
#    Test 6
#
###############################################################################
echo "Test 7: Delete the current version of: sshserver and its containers."
ImageContainerRemove $LINENO idscope=Current complist=sshserver.img
DockerReprositoryImageDeleteAssert $LINENO "$sshserverID_2"
ImageGUIDListAssert $LINENO "sshserver" 0
ContainerDeleteAssert $LINENO 2 3
TestFileDelete All
echo "Test 7: Success."
###############################################################################
#
#  Test 8:
#    Create two versions of the same image and two containers for each version.
#    Then completely delete all image versions and all containers. 
#
#  Depends on:
#    An empty Image Catalog
#
###############################################################################
echo "Test 8: Create two versions of: sshserver and two containers for each version."
echo "Test 8: Then completely delete all image versions and associated containers."
ImageContainerCreate $LINENO "sshserver" 1 2 1
sshserverID_1=`DockerReprositoryImageAssign $LINENO "sshserver"`
ImageChangeVersion "sshserver"
ImageContainerCreate $LINENO "sshserver" 2 2 3
sshserverID_2=`DockerReprositoryImageAssign $LINENO "sshserver"`
ImageContainerRemove $LINENO idscope=All complist=sshserver.img
DockerReprositoryImageDeleteAssert $LINENO "$sshserverID_1"
DockerReprositoryImageDeleteAssert $LINENO "$sshserverID_2"
ImageGUIDListAssert $LINENO "sshserver" 0
ContainerDeleteAssert $LINENO 4 1
TestFileDelete All
echo "Test 8: Success."
###############################################################################
#
#  Test 9:
#    Create a derived image that causes its associated base image to build.
#    Then delete each image in turn. 
#
#  Depends on:
#    An empty Image Catalog
#
###############################################################################
echo "Test 9: Create derived image: mysql that relies on: sshserver."
echo "Test 9: Then delete each image in turn."
ImageContainerCreate $LINENO "mysql" 1 0 0
mysqlID_1=`DockerReprositoryImageAssign $LINENO "mysql"`
sshserverID_1=`DockerReprositoryImageAssign $LINENO "sshserver"`
ImageGUIDListAssert $LINENO "mysql" 1
ImageGUIDListAssert $LINENO "sshserver" 1
ReportRun $LINENO type=ps idscope=All complist=All dockerOpts=-a
ReportScanTokenIncludeAssert $LINENO 'CONTAINER' 'IMAGE'
ReportLineCntAssert $LINENO 1
ReportRun $LINENO type=images idscope=All complist=All
ReportScanTokenIncludeAssert $LINENO 'REPOSITORY' 'VIRTUAL' `ReportGUIDformat "$sshserverID_1"` `ReportGUIDformat "$mysqlID_1"`
ReportLineCntAssert $LINENO 3
ReportRun $LINENO type=images idscope=Current complist=mysql.img
ReportScanTokenIncludeAssert $LINENO 'REPOSITORY' 'VIRTUAL' `ReportGUIDformat "$mysqlID_1"`
ReportScanTokenExcludeAssert $LINENO `ReportGUIDformat "$sshserverID_1"`
ReportLineCntAssert $LINENO 2
make Remove idscope=All complist='mysql.img sshserver.img' >/dev/null 2>/dev/null
if [ $? -ne 0 ]; then Abort $LINENO "Remove failed: parameters: idscope=All complist='mysql.img sshserver.img'"; fi
DockerReprositoryImageDeleteAssert $LINENO "$mysqlID_1"
DockerReprositoryImageDeleteAssert $LINENO "$sshserverID_1"
ImageGUIDListAssert $LINENO "mysql" 0
ImageGUIDListAssert $LINENO "sshserver" 0
echo "Test 9: Success."
###############################################################################
#
#  Test 10:
#    Use default "build all" to generate  a derived image that causes its
#    associated base image to build.  Then delete each image in turn. 
#
#  Depends on:
#    An empty Image Catalog
#
###############################################################################
echo "Test 10: Execute default 'build all' request to construct sshserver and its derived mysql server."
echo "Test 10: Then Remove all images."
make >/dev/null 2>/dev/null
if [ $? -ne 0 ]; then Abort $LINENO "make all failed."; fi
mysqlID_1=`DockerReprositoryImageAssign $LINENO "mysql"`
sshserverID_1=`DockerReprositoryImageAssign $LINENO "sshserver"`
ImageGUIDListAssert $LINENO "mysql" 1
ImageGUIDListAssert $LINENO "sshserver" 1
ContainerCreate $LINENO mysql 2 1
ContainerCreate $LINENO sshserver 2 3
ImageContainerRemove $LINENO idscope=All complist=All
DockerReprositoryImageDeleteAssert $LINENO "$mysqlID_1"
DockerReprositoryImageDeleteAssert $LINENO "$sshserverID_1"
ImageGUIDListAssert $LINENO "mysql" 0
ImageGUIDListAssert $LINENO "sshserver" 0
ContainerDeleteAssert $LINENO 4 1
TestFileDelete All
echo "Test 10: Success."
###############################################################################
#
#  Test 11:
#    Create a single image and running container then delete both.
#
#  Depends on:
#    An empty Image Catalog
#
###############################################################################
echo "Test 11: Create a single image and running container then delete both."
ImageContainerCreate $LINENO sshserver 1 0 0 
sshserverID_1=`DockerReprositoryImageAssign $LINENO "sshserver"`
ContainerCreate $LINENO sshserver 1 1 KR
ImageGUIDListAssert $LINENO "sshserver" 1
ImageContainerRemove $LINENO idscope=All complist=sshserver.img
DockerReprositoryImageDeleteAssert $LINENO "$sshserverID_1"
ImageGUIDListAssert $LINENO "sshserver" 0
ContainerDeleteAssert $LINENO 1 1
TestFileDelete All
echo "Test 11: Success."
###############################################################################
#
#  Testing complete.  Clean up the environment.
#
###############################################################################
ls ${TestfilePrefix}* > /dev/null 2>/dev/null
if [ $? -eq 0 ]; then TestFileDelete All; fi
ImageContainerRemove $LINENO idscope=All complist=All
ImageGUIDListAssert $LINENO "mysql" 0
ImageGUIDListAssert $LINENO "sshserver" 0
echo "Testing Complete & Successful!"
exit 0;


