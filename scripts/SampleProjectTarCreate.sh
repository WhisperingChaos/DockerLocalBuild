#!/bin/bash
###############################################################################
#
#  Purpose:
#    Issue test abort message due to some failed assertion.
#
#  Input:
#    $1 - line number within script that issued abort
#    $2 - abort message detail
#
#  Return:
#    Exit this base script with a return code of 1.
#
################################################################################
function Abort () {
  echo "Abort: Line#: $1 : $2" >&2;
  echo "Abort: Terminated script execution.">&2;
  exit 1;
}
###############################################################################
#
#  Purpose:
#    Transfer files from source directory to target, replacing overlapping
#    files that exist in the target.
#
#  Input:
#    $1 - source directory
#    $2 - target directory
#    sysin - piped list of file names.
#
#  Return:
#    0 - Successfully transfered
#    Otherwise Abort
#
################################################################################
function FilesTransfer () {
  while true; do
    read FileNm
    if   [ $? -ne 0        ]; then break; fi
    if   [ -e "$2/$FileNm" ]; then rm -rf "$2/$FileNm" > /dev/null; fi
    if ! [ -e "$1/$FileNm" ]; then Abort $LINENO "Source file missing: $1/$FileNm check transfer file list integrity."; fi
    cp -r "$1/$FileNm" "$2/" > /dev/nul;
    if [ $? -ne 0 ]; then Abort $LINENO "Copy process failed for: $1/$FileNm check permissions?"; fi
  done
  return 0;
}
###############################################################################
#
#  Purpose:
#    Remove obsolete files.  Files that are no longer relevant should be 
#    removed from the provided directory.
#
#  Input:
#    $1 - target directory
#    sysin - piped list of file names.
#
#  Return:
#    0 - Successfully removed obsolete files.
#    Otherwise Abort
#
################################################################################
function FilesObsolete () {
  # create associative array of File names that should exist
  declare -A FileListValid;
  while true; do
    read FileNm
    if [ $? -ne 0 ]; then break; fi
    FileListValid["$FileNm"]="$FileNm";
  done
  # iterate through all files to ensure each one belongs.  If not, then remove.
  for FileNm in $1/* 
  do
    FileNm=$(basename "$FileNm")
    local FileNmValid=${FileListValid["$FileNm"]}
    if [ "$FileNmValid" == "$FileNm" ]; then continue; fi
    rm -rf "$1/$FileNm" > /dev/nul;
    if [ $? -ne 0 ]; then Abort $LINENO "Remove of obsolete file failed: $1/$FileNm check permissions?"; fi
  done
  return 0;
}
###############################################################################
#
#  Purpose:
#    Provide a manifest of files that belong in the Root Resource Directory
#    of the sample project.
#
#  Output:
#    sysout - spew list of files to sysout using cat
#
################################################################################
function ManifestSpew () {
  cat <<MANIFESTSPEW
README_SAMPLE.md
Component
sshserver
mysql
MakefileTest.sh
MANIFESTSPEW
FilesFromDockerLocalBuild;
}
###############################################################################
#
#  Purpose:
#    Provide a list of files that belong in the Root Resource Directory
#    of the sample project that originate from the DockerLocalBuild repository.
#
#  Output:
#    sysout - spew list of files to sysout using cat
#
################################################################################
function FilesFromDockerLocalBuild () {
  cat <<MANIFESTSPEW
scripts
makefile
README.md
MANIFESTSPEW
}

Archive=sample.tar.gz
CurrtDir=$(dirname "$0");
ParntDir=$(dirname "$CurrtDir");
if ! [ -e "$ParntDir/$Archive" ]; then Abort "Archive file missing: $ParntDir/$Archive"; fi
if   [ -e "$ParntDir/sample"   ]; then Abort "Archive directory $ParntDir/sample exists. Perhaps, previous generation failed?"; fi
# extract esisting archive to "sample" directory.  Need the static resources
# within existing archive to create new one.
tar xfz $Archive -C "$ParntDir" > /dev/nul
# Copy file from the DockerLocalBuild directory to the Root Resource Directory of the sample project.
FilesFromDockerLocalBuild | FilesTransfer "$ParntDir" "$ParntDir/sample";
# special case: move $ParntDir/scripts/MakefileTest.sh to $ParntDir/MakefileTest.sh
mv -f $ParntDir/sample/scripts/MakefileTest.sh  $ParntDir/sample/MakefileTest.sh
if [ $? -ne 0 ]; then Abort $LINENO "Moving:$ParntDir/sample/scripts/MakefileTest.sh to $ParntDir/sample failed check permissions?"; fi
# Remove any obsolete sample project files.
ManifestSpew | FilesObsolete "$ParntDir/sample";
# create new tar version
tar czf $Archive "sample"
if [ $? -ne 0   ]; then Abort "Problem encountered while creating $Archive"; fi
rm -rf "$ParntDir/sample" > /dev/nul
if [ $? -ne 0   ]; then Abort "Problem encountered while cleaning up $ParntDir/sample"; fi
echo "Successfully updated archive: $Archive."
exit 0;

