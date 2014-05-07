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
#  Additional information can be found in the README.md file.
#
###############################################################################
SHELL = /bin/bash
MAKEFILE_VERSION:=v0.6.0

# Define the Root Resource Directory that contains all the various
# objects required by this makefile build system.  
ifndef BUILD_ROOT
  BUILD_ROOT:=.
endif

# Define the directory to implement the Image Catalog where the 
# Image GUID List for each component resides.
IMAGE_DIR:=$(BUILD_ROOT)/image
 ifndef TMPDIR
  TMPDIR:=/tmp
endif

# A temporary file to remember reporting state across multiple Components.
LOCAL_BUILD_HEADING_STATE:=$(shell mktemp)

# Redirect make to search for files implementing Image GUID Lists in the
# Image Catalog  
vpath %.img $(IMAGE_DIR)

# Define default build behavior to remove intermediate containers if build
# should succeed 
%.img: dockerOpts ?=-rm
%.img: %/*
ifdef idscope
	$(error Did you mean to run 'Remove/Show' instead of a build?)
endif
ifdef complist
	$(error Did you mean to run 'Remove/Show' instead of a build?)
endif
ifdef restrict
	$(error Did you mean to run 'Remove' instead of a build?)
endif
ifdef type
	$(error Did you mean to run 'Show type=' instead of a Build?)
endif
	docker build $(dockerOpts) -t "$(basename $@)" "$(BUILD_ROOT)/$(basename $@)"
	mkdir -p "$(IMAGE_DIR)"
	"$(BUILD_ROOT)/scripts/ImageMaintenance.sh" Add "$(IMAGE_DIR)/$@" "$(basename $@)"
	
all: allAfterInclude

# Customize this makefile by placing all rules in a file named "Component"
# within the same directory as the makefile.
include Component

allAfterInclude: $(COMPONENT_LST)
.PHONY: help
help:
	"$(BUILD_ROOT)/scripts/MakefileHelp.sh" $(MAKEFILE_VERSION)
.PHONY: Remove
.PHONY: CommonParamsAssert
.PHONY: RestrictAssert
.PHONY: DoIt
.PHONY: TypeAssert
.PHONY: TypeNoAssert
Remove: CommonParamsAssert RestrictAssert TypeNoAssert Remove.DoIt

Show:   CommonParamsAssert RestrictNoAssert TypeAssert Show.DoIt

CommonParamsAssert:
ifndef complist
	$(error Please specify complist='<ComponentName>.img' or 'All')
endif
ifneq ($(idscope),Current)
ifneq ($(idscope),All)
ifneq ($(idscope),AllExceptCurrent)
	$(error Please specify idscope='Current', 'All', or 'AllExceptCurrent')
endif
endif
endif

RestrictAssert:
ifdef restrict
ifneq ($(restrict),OnlyContainers)
	$(error Please specify restrict=OnlyContainers or remove it.)
endif
endif

RestrictNoAssert:
ifdef restrict
	$(error Did you mean to run 'Remove' instead of a Show?)
endif

TypeAssert:
ifneq ($(type),images)
ifneq ($(type),ps)
	$(error Please specify type='images' or 'ps')
endif
endif

TypeNoAssert:
ifdef type
	$(error Did you mean to run 'Show type=' instead of a Remove?)
endif

Remove.DoIt Show.DoIt:
ifeq ($(complist),All)
	@if [ -e "$(LOCAL_BUILD_HEADING_STATE)" ]; then rm -f "$(LOCAL_BUILD_HEADING_STATE)"; fi
	@for i in $(COMPONENT_LST); do if [ -f "$(IMAGE_DIR)/$$i" ]; then "$(BUILD_ROOT)/scripts/ImageMaintenance.sh" $(basename $@)$(restrict)$(type) $(idscope) "$(IMAGE_DIR)/$$i" "$(LOCAL_BUILD_HEADING_STATE)" "$(dockerOpts)" ; fi done
	@if [ -e "$(LOCAL_BUILD_HEADING_STATE)" ]; then rm -f "$(LOCAL_BUILD_HEADING_STATE)"; fi
else
	@if [ -e "$(LOCAL_BUILD_HEADING_STATE)" ]; then rm -f "$(LOCAL_BUILD_HEADING_STATE)"; fi
	@for i in $(complist);      do if [ -f "$(IMAGE_DIR)/$$i" ]; then "$(BUILD_ROOT)/scripts/ImageMaintenance.sh" $(basename $@)$(restrict)$(type) $(idscope) "$(IMAGE_DIR)/$$i" "$(LOCAL_BUILD_HEADING_STATE)" "$(dockerOpts)" ; fi done
	@if [ -e "$(LOCAL_BUILD_HEADING_STATE)" ]; then rm -f "$(LOCAL_BUILD_HEADING_STATE)"; fi
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
