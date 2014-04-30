###############################################################################
#
#  Purpose
#    Automate the construction, update, and removal of statically dependent
#    docker images, including their associated containers, within the scope
#    of a local docker daemon.  A statically dependent docker image relies
#    on components (packages/features) provided by a base image during its
#    construction via a docker build command ([see FROM](http://docs.docker.io/reference/builder/#from)).
#    A dependent image is analogous to a derived class, in languages such
#    as C++, Java, ... which inherits from a particular base class. 
#
#  Reasoning
#    Although docker provides a Trusted Build system and GitHub integration
#    that conceptually provide this functionality, some may adopt this makefile
#    approach to:
#    > Maintain a level of privacy, as Trusted Builds currently operate on
#      docker's public index/repository.
#    > Avoid implementing a private registry and Trusted Build cluster, especially
#      for small projects.
#    > Potentially improve the responsiveness of the development cycle, as the
#      build process runs locally,  especially, in situations when the public
#      Trusted Build cluster performance slows due to congestion of build
#      requests or network connectivity issues.
#    > Verify the successful construction of statically dependent containers
#      before committing them to the public index/registry.
#    > Easily delete all the containers associated to a given image version.
#    > Delete all docker image versions for a given image name.
#
###############################################################################
SHELL = /bin/bash
MAKEFILE_VERSION:=v0.5.0
ifndef BUILD_ROOT
  BUILD_ROOT:=.
endif

ifndef DOCKER_BUILD_OPTS
  DOCKER_BUILD_OPTS:=-rm
endif

IMAGE_DIR:=$(BUILD_ROOT)/image

# Redirect make to search for files implementing Image GUID Lists in the
# Image Catalog  
vpath %.img $(IMAGE_DIR)

%.img: %/*
ifdef idscope
	$(error Did you mean to run 'Remove' instead of a build?)
endif
ifdef complist
	$(error Did you mean to run 'Remove' instead of a build?)
endif
ifdef restrict
	$(error Did you mean to run 'Remove' instead of a build?)
endif
	docker build $(DOCKER_BUILD_OPTS) -t "$(basename $@)" "$(BUILD_ROOT)/$(basename $@)"
	mkdir -p "$(IMAGE_DIR)"
	"$(BUILD_ROOT)/scripts/ImageMaintenance.sh" Add "$(IMAGE_DIR)/$@" "$(basename $@)"
	
all: allAfterInclude

# Customize this makefile by placing all rules in a file named "Component"
# within the same directory as the makefile.
include Component

allAfterInclude: $(COMPONENT_LST)

help:
	"$(BUILD_ROOT)/scripts/MakefileHelp.sh" $(MAKEFILE_VERSION) 
Remove:
ifndef complist
	$(error Please specify complist='<ComponentName>.img' or 'All')
endif
ifneq ($(idscope),Current)
ifneq ($(idscope),All)
ifneq ($(idscope),AllExceptCurrent)
	$(error Please specify idscope='Current' or 'All')
endif
endif
endif
ifdef restrict
ifneq ($(restrict),OnlyContainers)
	$(error Please specify restrict=OnlyContainers or remove it.)
endif
endif
ifeq ($(complist),All)
	for i in $(COMPONENT_LST); do if [ -f "$(IMAGE_DIR)/$$i" ]; then "$(BUILD_ROOT)/scripts/ImageMaintenance.sh" Remove$(restrict) $(idscope) "$(IMAGE_DIR)/$$i"; fi done
else
	for i in $(complist);      do if [ -f "$(IMAGE_DIR)/$$i" ]; then "$(BUILD_ROOT)/scripts/ImageMaintenance.sh" Remove$(restrict) $(idscope) "$(IMAGE_DIR)/$$i"; fi done
endif



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
