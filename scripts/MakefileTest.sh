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
#    $1 - docker image name.
#    $2 - Number of containers to create.
#    $3 - Next Temporary file index to record container GUID.
#    $4 - KR - Keep running.
#
#  Return:
#    0 - Successfully created all containers.
#    Otherwise Abort.
#
###############################################################################
function ContainerCreate () {
  local RunOptions= 
  if [ "$4" == "KR" ]; then RunOptions='-d -i'; fi
  for ((ixFile=$3; $ixFile < ($2+$3); ixFile++ )); do
    docker run $RunOptions --cidfile="${TestfilePrefix}$ixFile" $1 > /dev/nul
    cat "${TestfilePrefix}$ixFile" | xargs -I GUID bash -c 'ContainerExist GUID'
    if [ $? -ne 0 ]; then Abort $LINENO "Missing container."; fi
  done
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
#    $1 - Number of containers to check.
#    $2 - Start of range.
#
#  Return:
#    0 - Assertion true.
#    Otherwise Abort.
#
###############################################################################
function ContainerExistAssert (){
 for ((ixFile=$2 ; $ixFile < ($2+$1) ; ixFile++ )); do 
    cat "${TestfilePrefix}$ixFile" | xargs -I GUID bash -c 'ContainerExist GUID'
    if [ $? -ne 0 ]; then Abort $LINENO "Containter missing when it should exist.  See ${TestfilePrefix}$ixFile"; fi
  done
  return 0;
}
###############################################################################
#
#  Purpose:
#    Ensure that given range of containers have been deleted.
#
#  Input:
#    $1 - Number of containers to check.
#    $2 - Start of range.
#
#  Return:
#    0 - Assertion true.
#    Otherwise Abort.
#
###############################################################################
function ContainerDeleteAssert (){
  for ((ixFile=$2 ; $ixFile < ($2+$1) ; ixFile++ )); do 
    cat "${TestfilePrefix}$ixFile" | xargs -I GUID bash -c 'ContainerExist GUID'
    if [ $? -eq 0 ]; then Abort $LINENO "Containter exists when it should have been deleted.  See ${TestfilePrefix}$ixFile"; fi
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
#    $1 - docker image name.
#    $2 - Total number of image GUI1Ds expected in Image GUID List for component.
#    $3 - Number of containers to create.
#    $4 - Next Temporary file index to record container GUID.
#
#  Return:
#    0 - Successfully created image and/or desired container instances.
#    Otherwise Abort.
#
###############################################################################
function ImageContainerCreate (){
  make ${1}.img > /dev/nul 2> /dev/nul
  if [ $? -ne 0 ]; then Abort $LINENO "Build of: $1 failed"; fi
  ImageGUIDListAssert "$1" $2
  ContainerCreate "$1" $3 $4
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
#    Check Image GUID List to ensure it has proper number of GUIDs.
#
#  Input:
#    $1 - docker image name.
#    $2 - Expected number of GUIDs.
#
#  Return:
#    0 - GUID List updated correctly.
#    Otherwise Abort.
#
###############################################################################
ImageGUIDListAssert (){
  if [ $2 -lt 1 ]; then 
    if [ -e "./image/${1}.img" ]; then Abort $LINENO "Image GUID List for: ./image/${1}.img shouldn't exist."; fi
    return 0;
  fi
  if ! [ -e "./image/${1}.img" ]; then Abort $LINENO "Image GUID List for: ./image/${1}.img should exist."; fi
  local GUIDcnt=`wc -l "./image/${1}.img"| awk '{print $1;}'`
  if [ $GUIDcnt -ne $2 ]; then Abort $LINENO "Image GUID List for: ./image/${1}.img contains $GUIDcnt but $2 was expected."; fi
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
ImageContainerCreate "sshserver" 1 1 1
sshserverID_1=`DockerReprositoryImageAssign $LINENO "sshserver"`
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
ContainerDeleteAssert 1 1;
TestFileDelete All
ImageGUIDListAssert "sshserver" 1 
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
ImageGUIDListAssert "sshserver" 0 
DockerReprositoryImageDeleteAssert $LINENO "$sshserverID_1"
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
ImageContainerCreate "sshserver" 1 2 1
sshserverID_1=`DockerReprositoryImageAssign $LINENO "sshserver"`
ImageChangeVersion "sshserver"
ImageContainerCreate "sshserver" 2 2 3
sshserverID_2=`DockerReprositoryImageAssign $LINENO "sshserver"`
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
ContainerDeleteAssert 2 1
DockerReprositoryImageExistsAssert $LINENO "$sshserverID_1"
DockerReprositoryImageExistsAssert $LINENO "$sshserverID_2"
ImageGUIDListAssert "sshserver" 2
ContainerExistAssert 2 3
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
ImageGUIDListAssert "sshserver" 1
DockerReprositoryImageDeleteAssert $LINENO "$sshserverID_1"
DockerReprositoryImageExistsAssert $LINENO "$sshserverID_2"
ContainerExistAssert 2 3
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
ImageGUIDListAssert "sshserver" 0
ContainerDeleteAssert 2 3
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
ImageContainerCreate "sshserver" 1 2 1
sshserverID_1=`DockerReprositoryImageAssign $LINENO "sshserver"`
ImageChangeVersion "sshserver"
ImageContainerCreate "sshserver" 2 2 3
sshserverID_2=`DockerReprositoryImageAssign $LINENO "sshserver"`
ImageContainerRemove $LINENO idscope=All complist=sshserver.img
DockerReprositoryImageDeleteAssert $LINENO "$sshserverID_1"
DockerReprositoryImageDeleteAssert $LINENO "$sshserverID_2"
ImageGUIDListAssert "sshserver" 0
ContainerDeleteAssert 4 1
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
ImageContainerCreate "mysql" 1 0 0
mysqlID_1=`DockerReprositoryImageAssign $LINENO "mysql"`
sshserverID_1=`DockerReprositoryImageAssign $LINENO "sshserver"`
ImageGUIDListAssert "mysql" 1
ImageGUIDListAssert "sshserver" 1
make Remove idscope=All complist='mysql.img sshserver.img' >/dev/null 2>/dev/null
if [ $? -ne 0 ]; then Abort $LINENO "Remove failed: parameters: idscope=All complist='mysql.img sshserver.img'"; fi
DockerReprositoryImageDeleteAssert $LINENO "$mysqlID_1"
DockerReprositoryImageDeleteAssert $LINENO "$sshserverID_1"
ImageGUIDListAssert "mysql" 0
ImageGUIDListAssert "sshserver" 0
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
ImageGUIDListAssert "mysql" 1
ImageGUIDListAssert "sshserver" 1
ContainerCreate mysql 2 1
ContainerCreate sshserver 2 3
ImageContainerRemove $LINENO idscope=All complist=All
DockerReprositoryImageDeleteAssert $LINENO "$mysqlID_1"
DockerReprositoryImageDeleteAssert $LINENO "$sshserverID_1"
ImageGUIDListAssert "mysql" 0
ImageGUIDListAssert "sshserver" 0
ContainerDeleteAssert 4 1
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
ImageContainerCreate sshserver 1 0 0 
sshserverID_1=`DockerReprositoryImageAssign $LINENO "sshserver"`
ContainerCreate sshserver 1 1 KR
ImageGUIDListAssert "sshserver" 1
ImageContainerRemove $LINENO idscope=All complist=sshserver.img
DockerReprositoryImageDeleteAssert $LINENO "$sshserverID_1"
ImageGUIDListAssert "sshserver" 0
ContainerDeleteAssert 1 1
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
ImageGUIDListAssert "mysql" 0
ImageGUIDListAssert "sshserver" 0
echo "Testing Complete & Successful!"
exit 0;


