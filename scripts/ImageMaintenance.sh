#!/bin/bash
INC_ImageInterface=$(dirname "${BASH_SOURCE[0]}");
source "$INC_ImageInterface/ImageInterface.sh";
###############################################################################
##
##  Purpose:
##    Add/Or update an Image GUID List to contain the Docker image GUID
##    of the newly constructed image.  The GUID for the most current Image
##    verision is always the last GUID in the file.
##
##  Input:
##    $1 - File path name to the Image GUID List.
##    $2 - Docker image name.
##
###############################################################################
function Add () {
  if [ "$1" = "" ]; then return 1; fi 
  if [ "$2" = "" ]; then return 1; fi
  local DockerImageKey=`docker inspect -format="{{.id}}" $2`;  
  while true; do
    if ! [ -e "$1" ]; then break; fi
    if ! [ -s "$1" ]; then break; fi
    local BindDir=$(dirname "$0");
    local CurrentImageKeyComp=`"$BindDir/ImageIDstream.sh" CompKey Current "$1"`;
    if [ $? -ne 0 ]; then return 1; fi
    local DockerImageKeyComp=`ImageIDPartialConstruct "$DockerImageKey"`;
    if [ $? -ne 0 ]; then return 1; fi
    ImageIDcomp "$CurrentImageKeyComp" "$DockerImageKeyComp" 
    if [ $? -eq 0 ]; then
       # update timestamp to quell subsequent build request
       touch "$1"
       return 0;
    fi
    #  image GUID is different :: the build actually changed the contents of the
    #  image, so save this new GUID.
    break;
  done
  echo "$DockerImageKey" >> "$1";
  if [ $? -ne 0 ]; then return 1; fi
  return 0;
}
###############################################################################
##
##  Purpose:
##    To physically remove either the most current or all Docker image versions
##    maintained by an Image GUID List.  Before removing an image, all the
##    containers that reference it are deleted which usually results in Docker
##    physically deleting the image instead of logically removing it.
##
##  Note:
##    It is certainly possible that the intended physical delete will "fail".
##    Although the routine may successfully complete, removing all
##    containers based on the image, there maybe other Docker images that
##    are derived from this one.  In this situation, Docker would logically
##    delete the image, then once all of its decendent images are deleted, Docker
##    physically elimates the image.
##
##  Input:
##    $1 - Remove operation type: 
##         "Current" - Remove current image GUID within a Image GUID List.
##         "All"     - Remove all image versions within a Image GUID List.
##         "AllExceptCurrent" - Remove all image versions within a Image GUID
##           List, except for the current GUID.
##    $2 - File path name to the Image GUID List.
##
###############################################################################
function Remove () {
  IdScopeAssert "$1"
  if [ "$2" = "" ]; then return 1; fi
  local BindDir=$(dirname "$0");
  "$BindDir/ImageIDstream.sh" "CompKey" "$1" "$2" | "$BindDir/ContainerMaintenance.sh" "Remove";
  if [ $? -ne 0 ]; then return 1; fi
  "$BindDir/ImageIDstream.sh" "$1Remove" "$2";
  if [ $? -ne 0 ]; then return 1; fi
  return 0;
}
###############################################################################
##
##  Purpose:
##    To physically delete all Docker containers associated to either
##    the most current or all GUIDs enumerated in the provided
##    Image GUID List.  However, all images are preserved.
##
##  Input:
##    $1 - Remove operation type: 
##         "Current" - Delete the Docker containers derived from the 
##                     most recent image GUID located in the specified
##                     Image GUID List.
##         "All"     - Delete all Docker containers derived from all
##                     image GUIDs maintained by the specified Image GUID List.
##         "AllExceptCurrent" - Delete all Docker containers derived from all
##                     image GUIDs, except for the current one,
##                     maintained by the specified Image GUID List.
##    $2 - File path name to Image GUID List.
##
################################################################################
function RemoveOnlyContainers () {
  IdScopeAssert "$1"
  if [ "$2" = "" ]; then return 1; fi
  local BindDir=$(dirname "$0");
  "$BindDir/ImageIDstream.sh" "CompKey" "$1" "$2" | "$BindDir/ContainerMaintenance.sh" "Remove";
  if [ $? -ne 0 ]; then return 1; fi
  return 0;
}
###############################################################################
##
##  Purpose:
##    Display container information based on the list of related GUIDS.
##
##  Input:
##    $1 - Scope of Show operation: 
##         "Current" - Show containers associated with current image 
##                     GUID of the provided Image GUID List.
##         "All"     - Show all containers associated to all GUIDs in the
##                     provided Image GUID List.
##         "AllExceptCurrent" - Show all containers associated to all GUIDS
##                     in the povided Image GUID List except for current one.
##    $2 - File path name to the Image GUID List.
##    $3 - File path to report state.
##    $4 - docker ps command optons.
##
###############################################################################
function Show () {
  IdScopeAssert "$1"
  if [ "$2" = "" ]; then return 1; fi
  local BindDir=$(dirname "$0");
  "$BindDir/ImageIDstream.sh" CompKey $1 "$2" | "$BindDir/ContainerMaintenance.sh" "Show" "$3" "$4";
  if [ $? -ne 0 ]; then return 1; fi
  return 0;
}
###############################################################################
##
##  Purpose:
##    Display docker image information for the given Image GUID List
##    and defined scope.
##
##  Input:
##    $1 - Scope of Show operation: 
##         "Current" - Show containers associated with current image 
##                     GUID of the provided Image GUID List.
##         "All"     - Show all containers associated to all GUIDs in the
##                     provided Image GUID List.
##         "AllExceptCurrent" - Show all containers associated to all GUIDS
##                     in the povided Image GUID List except for current one.
##    $2 - File path name to the Image GUID List.
##    $3 - File path to persistent report state.  Variables that must be
##         preserved beyond current call stack.  For example, whether to
##         emit report headings or not. 
##    $4 - docker image command optons.
##
###############################################################################
function Showimages () {
  IdScopeAssert "$1"
  export -f ImageIDPartialConstruct
  if [ "$2" = "" ]; then return 1; fi
  local BindDir=$(dirname "$0");
  local APIacceptsSingleGUID=`echo "$4"|grep '\-v\|\-t'`
  local ReportModifier=RPT
  if [ "$APIacceptsSingleGUID" != "" ]; then ReportModifier=$ReportModifier"APIsingle"; fi
  "$BindDir/ImageIDstream.sh" "$1" "$2" | xargs -I GUIDLong bash -c 'ImageIDPartialConstruct GUIDLong' | Showimages$ReportModifier "$3" "$4"
  return 0;
}
###############################################################################
##
##  Purpose:
##    Display docker image information for only the given Image GUIDs.  This
##    function handles docker image options that don't accept a specific
##    imgage GUID.
##
##  Input:
##    $1 - File path to persistent report state.  Variables that must be
##         preserved beyond current call stack.  For example, whether to
##         emit report headings or not. 
##    $2 - docker image command optons.
##
##  Output:
##    SYSOUT - Writes docker report in same docker format controlled by
##             report options.
##
###############################################################################
function ShowimagesRPT () {
  declare -A aImageGUID;
  declare -a KeyPrefix;
  KeyPrefix[0]='SK'
  KeyPrefix[1]='00'
  local ImageGUID;
  while read ImageGUID; do
    ImageGUID=`ImageIDobtain "$ImageGUID" 'KeyPrefix'`
    aImageGUID["$ImageGUID"]="$ImageGUID"
  done
  local ImageGUIDColm=`echo "$1"|grep '\-q'`
  if [ "$ImageGUIDColm" == "" ]; then
    ImageGUIDColm='$3';
  else
    ImageGUIDColm='$1';
  fi
  local ReportHeadingEmitted='N';
  if [ -e "$1" ]; then ReportHeadingEmitted='Y'; fi
  local ImageOutput;
  while read ImageLine; do
    local IMAGEoutput=`echo "$ImageLine" | awk '{print $1;}'`
    if [ "$IMAGEoutput" == "REPOSITORY" -a "$ReportHeadingEmitted" == "N" ]; then
      echo "$ImageLine";
      ReportHeadingEmitted='Y';
      continue;
    fi
    IMAGEoutput=`echo "$ImageLine" | awk "{print $ImageGUIDColm;}"`
    local KeyValue=${aImageGUID["$IMAGEoutput"]}
    if [ "$KeyValue" == "$IMAGEoutput" ]; then echo "$ImageLine"; continue; fi
  done < <(docker images $2)
  if [ "$ReportHeadingEmitted" == 'Y' -a ! -e "$1" ]; then echo 'ReportHeadingEmitted=Y' > "$1"; fi
 return 0;
}
###############################################################################
##
##  Purpose:
##    Display docker image information for only the given image GUIDs.
##    Since this docker report API permits specification of the image GUID,
##    directly provide it to the command as an argument.
##
##  Input:
##    $1 - File path to persistent report state.  Variables that must be
##         preserved beyond current call stack.  For example, whether to
##         emit report headings or not. 
##    $2 - docker image command optons.
##
##  Output:
##    SYSOUT - Docker report as formatted by docker report options.
##
###############################################################################
function ShowimagesRPTAPIsingle () {
  declare -a KeyPrefix;
  KeyPrefix[0]='LK'
  KeyPrefix[1]='SK'
  KeyPrefix[2]='00'
  local ImageGUID
  while read ImageGUID; do
    ImageGUID=`ImageIDobtain $ImageGUID 'KeyPrefix'`
    echo "imageGUIDsingleAPI: $ImageGUID"
    docker images $2 "$ImageGUID";
  done
}
###############################################################################
##
##  Purpose:
##    To verify the GUID scope trait.
##
##  Input:
##    $1 - Image GUID scope value.
##  
##  Output:
##    0 - scope is fine.
##    Termination of script with error message.
##
###############################################################################
function IdScopeAssert (){
  if [   "$1" = "Current" \
      -o "$1" = "All"     \
      -o "$1" = "AllExceptCurrent" ]; then return 0; fi
  echo "Abort: Invalid idscope specified: '$1'";
  exit 1;
}
###############################################################################
##
##  Purpose:
##    To provide "Add"s and "Remove"s to an Image GUID List maintained
##    within a text file.  The text file maintains a list of all Docker
##    GUIDs for a particular given image name.  This GUID List maintains an
##    ordering from oldest to most recent where the most recent GUID is the
##    last line of the file.
##
##  Input:
##    $1 - Operation Name: 
##         "Add"     - Insert docker image GUID into Image GUID List as
##                     the current image version for given name.
##         "Remove"  - Remove image version(s) for given name.
##         "RemoveOnlyContainers"  - Remove only the containers associated
##                     to the image version(s) for the given name.
##    When $1 == "Add":
##      $2 - Docker image name.
##      $3 - File path name Image GUID List.
##    When $1 == "Remove" or "RemoveOnlyContainers":
##      $2 - File path name Image GUID List.
##      $3 - File path name to the Image GUID List.
##    When $1 == "Showps"
##      $2 - Scope of Show operation. 
##      $3 - File path name to the Image GUID List.
##      $4 - File path to report state
##      $5 - docker ps command optons.
##    When $1 == "Showimages"
##      $2 - Operaton Name
##      $3 - File path name to Image GUID List.
##      $4 - File path to report state
##      $5 - docker images options.
##
###############################################################################
  case "$1" in
    Add)                  Add    "$2" "$3" ;;
    Remove)               Remove "$2" "$3" ;;
    RemoveOnlyContainers) RemoveOnlyContainers "$2" "$3" ;;
    Showps)               Show       "$2" "$3" "$4" "$5" ;;
    Showimages)           Showimages "$2" "$3" "$4" "$5" ;;
    *) exit 1             ;;
  esac
  if [ $? -ne 0 ]; then exit 1; fi

exit 0;
###############################################################################
# 
# The MIT License (MIT)
# Copyright (c) 2014 Richard Moyse License@Moyse.US
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
###############################################################################

