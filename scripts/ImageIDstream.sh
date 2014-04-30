#!/bin/bash
INC_ImageInterface=$(dirname "${BASH_SOURCE[0]}");
source "$INC_ImageInterface/ImageInterface.sh";
###############################################################################
##
##  Purpose:
##    Generate & execute the bash associative array syntax to map at least the 
##    Short Key [SK] - the first 12 characters of the 64 Character Long Key [LK]
##    to an image's Text Key [TK] - consists of a repository name/container name:Tag.
##
##  Note:
##    Not all images are associated to a [TK].  In these cases, mapping syntax
##    isn't generated.
##
##  Inputs:
##    $1 - Contains the name of a bash variable declared as an associative array.
##    Indirect input - Routine executes Docker API to display all images,
##        expecting the first column to be an image repository name, second
##        column its tag, with the third column displaying its [SK].
## 
##  Outputs:
##    When Successful:
##      $1 - Contains what was already in the array and zero or more entries
##           added  by this routine. 
###############################################################################
function ImageIDToNameMapCreate (){
  for i in $( docker images | grep -v "^<none>" | awk "{print \"$1[\"\$3\"]=\"\$1\":\"\$2;}" | grep -v "=REPOSITORY:TAG" | grep -v "=ubuntu:"); do
   eval $i
  done
}
###############################################################################
##
##  Purpose:
##    Converts a given image key type into all of its equivalent key types.
##
##  Inputs:
##    $1 - The name of an associative array that maps [SK] to [TK].
##    Indirect - A stream of keys delivered via stdin.
## 
##  Outputs:
##    When Successful:
##      $1 - Streams a complete composite key as long as the Image Key refers
##           to an existing image file.  Otherwise, this key is dropped from
##           the stream.
###############################################################################
ConvertIDToCompKey() {
while true; do
  local ImageID;
  read ImageID;
  if [ $? -ne 0 ]       ; then return 0; fi
  if [ "$ImageID" = "" ]; then return 0; fi
  ImageID=`ImageIDFullConstruct $ImageID $1`;
  if [ "$ImageID" = "" ]; then return 0; fi
  echo "$ImageID";
done
return 0;
}
###############################################################################
##
##  Purpose:
##    Given one of the following image GUID flavors, generate the other ones:
##      1. Text Key  [TK] - consists of a repository name/image name:tag.
##      2. Short Key [SK] - the first 12 characters of the [LK]
##      3. Long Key  [LK] - a 64 character GUID.
##    Since there is a definitive format to Docker GUIDS and Docker APIs to
##    obtain the other key flavors, if they exist, build a composite key
##    that attempts to include all three key flavors.
##
##  Note:
##    The [TK] may not exist, because a docker image can either not be assigned
##    an image name or the tag assigned migrated to a more recent version of
##    this image.
##
##  Inputs:
##    $1 - an Image ID of any key flavor.
##    $2 - an associative array that maps a [SK] to [TK].
## 
###############################################################################
function ImageIDFullConstruct (){
  local CompKey=`ImageIDPartialConstruct $1`;
  if [ $? -ne 0 ]; then echo ""; return 1; fi
  if [ "${CompKey:0:4}" = "[TK]" ]; then
    local ImageLK=`docker inspect -format="{{.id}}" "$1"`;
    if [ "$ImageLK" = "" ]; then
      echo "";
      echo "Error: Could not locate image given key: \'$1\'" >&2;
      return 1;
    else
      ImageLK=`ImageIDPartialConstruct "$ImageLK"`;
      if [ $? -ne 0 ]; then echo ""; return 1; fi
      echo "$CompKey$ImageLK";
    fi
  elif [ ${#1} -eq 64 ]; then
    local  AssKey=${1:0:12};
    local ImageTK=$(eval echo \${$2["$AssKey"]});
    if [ "$ImageTK" != "" ]; then
      ImageTK=`ImageIDPartialConstruct "$ImageTK"`;
      if [ $? -ne 0 ]; then echo ""; return 1; fi
    fi
    CompKey=`ImageIDPartialConstruct $1`;
    if [ $? -ne 0 ]; then echo ""; return 1; fi
    echo "$ImageTK$CompKey";
  elif  [ ${#1} -eq 12 ]; then
    local ImageTK=$(eval echo \${$2["$1"]});
    if [ "$ImageTK" != "" ]; then
      ImageTK=`ImageIDPartialConstruct "$ImageTK"`;
      if [ $? -ne 0 ]; then echo ""; return 1; fi
    fi
    local ImageLK=`docker inspect -format="{{.id}}" "$1"`;
    if [ "$ImageLK" = "" ]; then echo ""; return 1; fi
    ImageLK=`ImageIDPartialConstruct $ImageLK`;
    if [ $? -ne 0 ]; then echo ""; return 1; fi
    echo "$ImageTK$ImageLK";
  fi
  return 0;
}
###############################################################################
##
##  Purpose:
##    Stream the specified set of image GUIDs.  Convert each image GUID in the set
##    to create a composite image GUID key that consists of a Text Key [TK],
##    short key [SK], and Long Key [LK], to permit comparisions when 
##    docker happens to employ one of these other keys instead
##    of the image GUID key flavor that was stored in the Image GUID List.
##
##  Inputs:
##    $1 - Specifies the image set:
##         Current - Only the GUID referencing the current image version.
##         All     - All image GUIDs.
##         AllExceptCurrent - All image GUIDs except the current one.
##    $2 - File path name to Image GUID List. 
##    Indirect input - An associative array that maps [SK] to [TK].
## 
###############################################################################
function CompKey () {
  declare -A ImageIdToName;
  ImageIDToNameMapCreate ImageIdToName;
  case "$1" in 
    Current)           ;;
    All)               ;;
    AllExceptCurrent)  ;;
    *) return 1        ;;
  esac

  $1 "$2" | ConvertIDToCompKey  ImageIdToName;
}
###############################################################################
##
##  Purpose:
##    Stream only the last Image ID from the provided file.  The last image
##    id is considered the most recent one.
##
##  Inputs:
##    $1 - File path name to Image GUID List.  
##
###############################################################################
function Current () {
  sed -n '$p' "$1";
}
###############################################################################
##
##  Purpose:
##    Remove only the current image version as known to the build system.
##    After removing the current Image GUID from a given Image GUID List,
##    determine if the List is empty.  If it is, delete it.
##
##  Inputs:
##    $1 - File path name to Image GUID List.  
## 
###############################################################################
function CurrentRemove () {
  Current "$1" | RemoveImage;
  if [ $? -ne 0 ]; then return 1; fi
  local FileNmPthTmp="/tmp/`date +%C%y_%m_%d_%H_%M_%S`_$RANDOM_$(basename '$1').tmp";
  if [ $? -ne 0 ]; then return 1; fi
  sed '$d' "$1" > "$FileNmPthTmp";
  if [ $? -ne 0 ]; then return 1; fi
  local CurrentContent=`Current "$FileNmPthTmp"`;
  if [ $? -ne 0 ]; then return 1; fi
  if [ "$CurrentContent" = "" ]; then                              
    rm "$1";
    if [ $? -ne 0 ]; then return 1; fi
    rm "$FileNmPthTmp";
  else
    mv "$FileNmPthTmp" "$1";
  fi
  if [ $? -ne 0 ]; then return 1; fi
  return 0;
}
###############################################################################
##
##  Purpose:
##    Stream every image GUID from the provided file in reverse order: from 
##    the bottom, most recent, to the top, least recent (oldest).
##
##  Inputs:
##    $1 - File path name to Image GUID List.
## 
###############################################################################
function All () {
  tac "$1";
}
###############################################################################
##
##  Purpose:
##    Delete all the Image ID's in the provided Image GUID List from
##    the docker local repository then remove the Image GUID List file.
##
##  Inputs:
##    $1 - File path name to Image ID catalog file.  
## 
###############################################################################
function AllRemove () {
  All "$1" | RemoveImage;
  if [ $? -ne 0 ]; then return 1; fi
  rm "$1";
}
###############################################################################
##
##  Purpose:
##    Stream every image GUID from the provided file in reverse order: from 
##    the bottom, most recent, to the top, least recent (oldest) except for
##    the most current image GUID
##
##  Inputs:
##    $1 - File path name to Image GUID List.
## 
###############################################################################
function AllExceptCurrent () {
  All "$1" | awk '{if(NR>1)print}';
}
###############################################################################
##
##  Purpose:
##    Remove all GUIDs from the Image GUID List, execpt for the current one.
##
##  Inputs:
##    $1 - File path name to Image GUID List.
## 
###############################################################################
function AllExceptCurrentRemove () {
  AllExceptCurrent "$1" | RemoveImage;
  local CurrentGUID=`Current "$1"`;
  echo "$CurrentGUID" > "$1";
}
###############################################################################
##
##  Purpose:
##    Delete the Image from Docker's local reporitory identified by the
##    the Image ID.
##
##  Inputs:
##    Indirect Input - read one or more Image IDs from stdin.  
## 
###############################################################################
function RemoveImage () {
  while true; do
    local ImageID;
    read ImageID;
    if [ $? -ne 0 ]       ; then return 0; fi
    if [ "$ImageID" = "" ]; then return 0; fi
    local DockerMess=$(docker rmi "$ImageID" 2>&1 ; echo PIPE_STATUS: $?);
    echo $DockerMess | grep "PIPE_STATUS: 0" > /dev/nul;
    if [ $? -ne 0 ]; then
      echo $DockerMess | grep "^Error: No such image:" > /dev/nul;
      if [ $? -ne 0 ]; then
        echo "Error: While removing Docker image: $DockerMess";
        return 1;
      fi
    fi
    echo "Success: Removed Docker image: $ImageID";
  done;
  return 0;
}
###############################################################################
##
##  Purpose:
##    Operates on an Image GUID List that contains 1 to n
##    Image IDs.  The operators enumberated below, by the case statement,
##    remove the image identified by the key, as well as their associated
##    containers, from the local docker image repository.  The image list 
##    maintained in the catalog file enumerates keys from least recent to
##    most recent image version, with the most recent Image ID, for a 
##    given image version, located at the bottom of the file.  If any operation
##    processes all the keys in the given catalog file, the file is deleted.
##    
##  Inputs:
##    $1 - Operation name.
##    When $1 == "CompKey":
##      $2 - The CompKey function to execute.  
##      $3 - File path name to Image GUID List.  
##    Otherwise:
##      $1 - The function name to execute.  
##      $2 - File path name to Image GUID List.  
## 
###############################################################################
  case "$1" in 
    Current)                  ;;
    CompKey)                  ;;
    CurrentRemove)            ;;
    All)                      ;;
    AllRemove)                ;;
    AllExceptCurrent)         ;;
    AllExceptCurrentRemove)   ;;
    *) exit 1                 ;;
  esac

  $1 $2 $3
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

