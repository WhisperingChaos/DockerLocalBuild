#!/bin/bash
###############################################################################
##
##  Purpose:
##    So far, the Docker CLI tools perfer displaying image IDs in this 
##    order:
##      1. Text Key [TK]  - consists of a repository name/container name:Tag.
##      2. Short Key [SK] - the first 12 characters of the [LK]
##      3. Long Key [LK] - a 64 character GUID.
##    Since there is a definitive method to determine the key flavor by 
##    inspecting an ImageID's form, this routine will create a compariable ImageID
##    to be used by ImageIDcomp, when comparing ImageIDs.
##
##  Inputs:
##    $1 - an ImageID.
## 
##  Outputs:
##    When Successful:
##      A potentially composite output key whose form conforms to what's
##      required to perform a comparision by ImageIDcomp.  The key is
##      returned via stdout
##    When Failure: 
##      Null key to stdout and an error message to stderr
##      indicating that the passed in ImageID violates its expected form.
##
###############################################################################
function ImageIDPartialConstruct (){
  local PartialKey=$(echo "$1"|grep '[^:][^:]*:[^:][^:]*' | awk '{print "[TK]"$1;}')
  if [ "$PartialKey" != "" ]; then echo "$PartialKey"; return 0; fi
  local PartialKey=$(echo "$1"|grep -v '^[0-9a-fA-F][0-9a-fA-F]*$')
  if [ "$PartialKey" != "" ]; then 
    echo ""; 
    echo "Error: ImageID:'$1' doesn't conform." >&2;
    return 1;
  fi
  if [ ${#1} -eq 64 ]; then
    echo "[SK]${1:0:12}[LK]$1";
  else
    echo "[SK]${1:0:12}";
  fi
  return 0;
}
###############################################################################
##
##  Purpose:
##    Provide a comparision function to operate over the three
##    flavors of image GUIDs.  The three flavors are: Long Key [LK] - a 64 character
##    GUID, Short Key [SK] - the first 12 characters of the [LK], and a 
##    Text Key [TK] - consists of a repository name/container name:Tag.
##    The comparision operator requires that both operands have at least
##    one key flavor in common. Although the keys can appear in any order,
##    the comparator compares the three flavors in order of their
##    perceived frequency, where [TK]s are considered the most frequent and
##    [LK]s less.
##
##  Inputs:
##    $1 - Right hand side operand
##    $2 - Left hand side operand
## 
##  Outputs:
##    When Successful: keys match
##    When Failure: keys are different
##    When Logic Failure: keys are different and an error message to stderr 
##
###############################################################################
function ImageIDcomp () {
  declare -a PrefixNm;
  PrefixNm[0]='TK';
  PrefixNm[1]='SK';
  PrefixNm[2]='LK';
  local MissingCnt;
  let MissingCnt=0;
  for (( i=0; i < 3; i++ )); do
    local Operand1=$(echo "$1" | sed "s/.*\[${PrefixNm[$i]}\]\([^\[]*\).*/\1/")
    local Operand2=$(echo "$2" | sed "s/.*\[${PrefixNm[$i]}\]\([^\[]*\).*/\1/")
    if [ "$Operand1" = "" ] || [ "$Operand2" = "" ]; then
      let MissingCnt++;
    elif [ "$Operand1" = "$Operand2" ]; then
      return 0;
    fi
  done
  if [ $MissingCnt -eq 3 ]; then
    echo "Error: ImageIDcomp: Operands don't present common key flavor for comparison." >&2
  fi
  return 1;
}
###############################################################################
##
##  Purpose:
##    Given an image GUID composite key, extract the image GUID according the 
##    Docker ID preference of [TK], then [SK], then [LK].
##
##  Inputs:
##    $1 - Composite image GUID;
## 
##  Outputs:
##    When Successful:
##      One of the keys in Docker perfered order.
##    When Failure:
##      Null string.
##
###############################################################################
function ImageIDdisplay () {
  declare -a PrefixNm;
  PrefixNm[0]='TK';
  PrefixNm[1]='SK';
  PrefixNm[2]='LK';
  for (( i=0; i < 3; i++ )); do
    local KeyID=$(echo "$1" | grep "\[${PrefixNm[$i]}\]" | sed "s/.*\[${PrefixNm[$i]}\]\([^\[]*\).*/\1/");
    if [ "$KeyID" != "" ]; then
      echo "$KeyID";
      return 0;
    fi
  done
  echo "";
  return 1;
}
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
