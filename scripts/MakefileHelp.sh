#!/bin/bash
###############################################################################
##
##  Purpose:
##    Display the help text for the makefile command line options.
##
##  Input:
##    $1 - makefile Version.
##
###############################################################################
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
cat <<MAKEFILEHELP_SH

makefile version: $1
Construct or remove docker images and/or associated containers within local docker daemon.

Usage: make                     : Builds all images in order of dependencies.
   or: make COMPONENTNAME.img   : Builds specific image
   or: make Remove [OPTION]...  : Removes one or more images and/or associated containers.

OPTION:

  idscope=(All/Current/AllExceptCurrent)
            All - Process every GUID enumerated in the Image GUID List.
            Current - Process only the most recent GUID from the Image GUID List.
            AllExceptCurrent - Process every GUID in Image GUID List other than Current.

  restrict=(OnlyContainers)
            Alters the default behavior of the Remove command.
            The default behavior removes both an image and its associated container(s).
            OnlyContainers - Remove only the containers associated to an image (keep the image).

  complist=(All/'<ComponentName1>.img[ <ComponentName2>.img ...]')
            Defines a list of Components to be processed by the Remove operation.
            Encapsulate the list, if more than one Component, in single or double quotes.
            Use a space to separate list elements.
  
Example Remove Commands:

  Remove All Component Versions for All Components
      Deletes all images, their versions, and all associated containers
      even if the containers are running at the time of this request:

      > make Remove idscope=All complist=All

  Remove just the Current Component Version for All Components
      Deletes the most recently built image for every Component and all associated
      containers, even if the containers are running at the time of this request:

      > make Remove idscope=Current complist=All

  Remove All the containers for Current Component Version of sshserver.img
      Deletes every container associated to the most recently built Component named "sshserver".

      > make Remove restrict=OnlyContainers idscope=Current complist=sshserver.img

  Remove All containers and All Components except for the Current ones.
      Deletes every container and every image version except for the most recent version.

      > make Remove idscope=AllExceptCurrent complist=All

MAKEFILEHELP_SH
