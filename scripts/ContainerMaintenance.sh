#!/bin/bash
INC_ImageInterface=$(dirname "${BASH_SOURCE[0]}");
source "$INC_ImageInterface/ImageInterface.sh";
###############################################################################
##
##  Purpose:
##    Delete the container identified by the provided GUID.  If the delete
##    fails, attempt to stop the container and then delete it.
##
##  Input:
##    $1    - image GUID.
##    SYSIN - a stream of container GUIDs associated to the provided image GUID,
##
##  Output:
##    SYSOUT - Message indicating success.
##    SYSERR - Message indicating problem attempting to display image GUID
##
###############################################################################
function Remove () {
  local ImageID=`ImageIDdisplay "$1"`;
  if [ $? -ne 0 ]; then echo "Problem generating image ID to display for : $1" >&2; fi
  while true; do
    read ContainerGUID
    if [ "$ContainerGUID" == "" ]; then break; fi
    docker rm "$ContainerGUID" > /dev/null
    if [ $? -ne 0 ]; then
      docker stop "$ContainerGUID" > /dev/null
      if [ $? -ne 0 ]; then return 1; fi
      docker rm "$ContainerGUID"   > /dev/null
      if [ $? -ne 0 ]; then return 1; fi
    fi
    echo "Success: Removed container: '$ContainerGUID' associated to image: '$ImageID'";
  done
  return 0;
}
###############################################################################
##
##  Purpose:
##    Show the containers that are derived from the provided image GUID
##    using "docker ps" command which can be augmented by its own options
##    provided to this function.
##
##  Input:
##    $1 - image GUID.
##    $2 - File path to persistent report state.  Variables that must be
##         preserved beyond current call stack.  For example, whether to
##         emit report headings or not.
##    $3 - Docker ps reporting options.
##  Output:
##    SYSOUT - docker ps header and detail entries that correspond to 
##             conatiners associated to the provided image GUID
##
###############################################################################
function Show () {
  declare -A aContainerGUID;
  while true; do
    local ContainerGUID 
    read ContainerGUID
    if [ "$ContainerGUID" == "" ]; then break; fi
    aContainerGUID["$ContainerGUID"]="$ContainerGUID"
  done
  local ReportHeadingEmitted='N';
  if [ -e "$2" ]; then ReportHeadingEmitted='Y'; fi
  local PSline;
  while read PSline; do
    local PSoutput=`echo "$PSline" | awk '{print $1;}'`
    if [ "$PSoutput" == "CONTAINER" -a "$ReportHeadingEmitted" == 'N' ]; then
      echo "$PSline"
      ReportHeadingEmitted='Y'
      continue
    fi
    local KeyValue=${aContainerGUID["$PSoutput"]}
    if [ "$KeyValue" == "$PSoutput" ]; then echo "$PSline"; continue; fi
  done < <(docker ps $3)
  if [ "$ReportHeadingEmitted" == 'Y' -a ! -e "$2" ]; then echo 'ReportHeadingEmitted=Y' > "$2"; fi
  return 0;
}
###############################################################################
##
##  Purpose:
##    Given a Docker Image GUID, output the set of all the container GUIDs
##    derived from it.
##
##  Input:
##    s1 - GUID of Image whose containers will be removed.
##
##  Output:
##    SYSOUT - 12 byte container GUID.
##    SYSERR - When docker ps command fails, generate a message suggesting
##             running with elevated privileges.
##
###############################################################################
function ContainerIDinter () {
  docker ps -a > /dev/null;
  if [ $? -ne 0 ]; then echo "Error: Try 'sudo' <command> ...">&2; return 1; fi
  for i in $( docker ps -a | awk '{print $1 "|" $2;}' | grep -v '^CONTAINER|ID$'); do
    local ContainerID=${i:0:12};
    local ImageID=${i:13};
    ImageID=`ImageIDPartialConstruct $ImageID`;
    if [ $? -ne 0 ]; then return 1; fi
    ImageIDcomp "$1" "$ImageID"
    if [ $? -ne 0 ]; then continue; fi
    echo "$ContainerID"
  done
  return 0;
} 
###############################################################################
##
##  Purpose:
##    Iterate through the stream of Image GUIDs piped to this program and 
##    then iterate over each Image's GUIDs of derived containers.
##
##  Input:
##    $1 - Command to execute.
##    $2 - File path to persistent report state.  Variables that must be
##         preserved beyond current call stack.  For example, whether to
##         emit report headings or not.
##    $3 - Docker ps reporting options.
##    SYSIN - Image GUIDs.
##
###############################################################################
  if [   "$1" != "Remove"    \
      -a "$1" != "Show" ]; then exit 1; fi
  while read ImageID; do
    ContainerIDinter $ImageID | $1 "$ImageID" "$2" "$3";
    if [ $? -ne 0 ]; then exit 1; fi
  done
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
