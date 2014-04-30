#!/bin/bash
INC_ImageInterface=$(dirname "${BASH_SOURCE[0]}");
source "$INC_ImageInterface/ImageInterface.sh";
###############################################################################
##
##  Purpose:
##    Delete the container identified by the provided GUID.  If the delete
##    fails attempt to stop the container and then delete it.
##
##  Input:
##    $1 - GUID of container to remove.
##
###############################################################################
function ContainerRemove () {
  docker rm $1  2> /dev/null
  if [ $? -eq 0 ]; then return 0; fi
  docker stop $1 > /dev/null
  if [ $? -ne 0 ]; then return 1; fi
  docker rm $1   > /dev/null
  if [ $? -ne 0 ]; then return 1; fi
  return 0;
}
###############################################################################
##
##  Purpose:
##    Read zero or more Docker Image IDs streamed from stdin.
##
##  Input:
##    stdin - GUID of container to remove.
##    $1    - Name of environment variable to receive Image GUID.
##
###############################################################################
function ImageIDGet () {
  local ImageId;
  read -t 3 ImageId;
  if [ $? -ne 0 ];  then 
    eval $1=; 
  else
    eval $1=$ImageId;
  fi
  return 0;
}
###############################################################################
##
##  Purpose:
##    Given a Docker Image GUID, iterate over all the containers derived from 
##    it obtaining their container GUIDS and delete them.
##
##  Input:
##    s1 - GUID of Image whose containers will be removed.
##
###############################################################################
function ContainerIDinter () {
  docker ps -a > /dev/null;
  if [ $? -ne 0 ]; then echo "Error: Try 'sudo' <command> ..."; return 1; fi
  for i in $( docker ps -a | awk '{print $1 "|" $2;}' | grep -v '^CONTAINER|ID$'); do
    local ContainerID=${i:0:12};
    local ImageID=${i:13};
    ImageID=`ImageIDPartialConstruct $ImageID`;
    if [ $? -ne 0 ]; then return 1; fi
    ImageIDcomp "$1" "$ImageID"
    if [ $? -eq 0 ]; then
      ContainerRemove "$ContainerID";
      if [ $? -ne 0 ]; then return 1; fi
      local DockerID=`ImageIDdisplay "$1"`;
      echo "Success: Removed container: '$ContainerID' associated to image: '$DockerID'";
    fi
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
##    ImageID - Via ImageIDGet function.
##
###############################################################################
  while true; do
    ImageIDGet ImageID;
    if [ $? -ne 0 ];        then exit 1; fi
    if [ "$ImageID" = "" ]; then exit 0; fi
    ContainerIDinter $ImageID;
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
