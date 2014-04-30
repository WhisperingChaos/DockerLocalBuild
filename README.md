## Manage/Automate Local Docker Image Builds & Containers 

##### Table of Contents  
[Purpose](#purpose)  
[Reasoning](#reasoning)  
[Concepts](#concepts)  
[What's Provided](#whats-provided)  
[Installing](#installing)  
[How to Add Components to the makefile](#how-to-add-components-to-the-makefile)  
[How to Run make](#how-to-run-make)  
[Sample makefile](#sample-makefile)  
[Test Script](#test-script)  
[License](#license)  

### Purpose

Automate the construction, update, and removal of statically dependent docker images, including their associated containers, within the scope of a local docker daemon.  A statically dependent docker image relies on components (packages/features) provided by a base image during its construction via a docker build command ([see FROM](http://docs.docker.io/reference/builder/#from)).  A dependent image is analogous to a derived class, in languages such as C++, Java, ... which inherits from a particular base class. 

### Reasoning

Although docker provides a Trusted Build system and GitHub integration that conceptually provide this functionality, some may adopt this makefile approach to:
+ Maintain a level of privacy, as Trusted Builds currently operate on docker's public index/repository.
+ Avoid implementing a private registry and Trusted Build cluster, especially for small projects.
+ Potentially improve the responsiveness of the development cycle, as the build process runs locally,  especially, in situations when the public Trusted Build cluster performance slows due to congestion of build requests or network connectivity issues.
+ Verify the successful construction of statically dependent containers before committing them to the public index/registry.
+ Easily delete all the containers associated to a given image version.
+ Delete all docker image versions for a given image name.

### Concepts

+ **Component**:  An object that defines a docker image build context.  It is implemented as a directory whose name reflects the image's name in the local repository.  This directory contains the Dockerfile needed to build a specific docker image and any resources referenced by this Dockerfile included in the resulting image.
+ **Image GUID List**:  An object that maintains a list of docker image GUIDs generated when building a specific Component.  The different GUIDs in this list represent various image versions generated due to alterations applied to resources, like a Dockerfile, that comprise a Component's (image's) build context.   A standard text file is used to implement each Image GUID List.  The text file is assigned the same name as the Component (image) name.  The image GUIDs in the file are ordered from the oldest, which appears as the first line in the text file to the most recent GUID that occupies its last line.
+ **Image Catalog**:  An object that encapsulates all Image GUID Lists.  It's implemented as a directory named "image". 
+ **Root Resource Directory**:  An object, implemented as a directory, that encapsulates all the aforementioned objects.  It also contains the makefile and bash script directory called "scripts".

### What's Provided

+ A GNU makefile with two custom rules for docker.  The "build" rule encodes a prerequisite wildcard pattern match which interprets all files specified in a given Component (directory), as a required dependency for that Component.  It also provides a recipe to execute the docker build command and then, if successful, will add the newly minted image's GUID to the appropriate Image GUID List.  The use of the wildcard pattern dynamically adapts the dependency list, therefore, unless an exception exists, the only dependencies that must be specified are Component (image) level ones, as adding to or updating files in a Component (directory) will automatically trigger the default recipe without altering the makefile.

  The other custom rule implements a "Remove" ("clean") request.  A remove operation, depending on its scope, deletes one or more local docker images and/or their associated containers (whether currently running or stopped) under the management of the local docker daemon.  After each successful image delete, the recipe continues by eliminating the image's GUID from the appropriate Image GUID List.
+ A small number of bash scripts that manage the GUIDs stored in the Image GUID List and when requested, delete containers created from these managed GUIDs.

### Installing

Assumes GNU "make" has already been installed.  This makefile was developed using GNU "make" Version 3.81 within an Ubuntu 12.04 environment.
+ Copy the provided "makefile" to either an existing or newly created Root Resource Directory.
+ Copy the "script" directory and its contents to the Root Resource Directory.
+ Copy the template "Component" file to the Root Resource Directory. 

### How to Add Components to the makefile

+ Create a Component (directory) within the Root Resource Directory.  A Component (directory) must contain at least a Dockerfile.
+ Edit or create a file called "Component" within Root Resource Directory (same directory as the makefile) and add a target, at the bottom of this file with either an empty prerequisite list, in situations where the target can be independently built without referring to other Components or one that reflects an immediate reference to another Component which becomes the statically included base for this one.  The target name must be identical to the Component name with an added suffix of ".img".

  Ex: Given Component name of: "sshserver" that is independent of other project Components, its makefile rule would be:

      sshserver.img    :

  Ex: Given Component name of: "mysql" that depends on the "sshserver" Component for secure administrative access, the "mysql" makefile rule would be:

      mysql.img    : sshserver.img

+ After inserting a new rule to manufacture a Component, the "COMPONENT_LST:=" macro near the top of the "Component" file must also be altered to reflect this name.  When adding a new entry to this list, insert the new target name before any other Component it relies on.  The make "remove" commands, to be explained below, consume this Component list and remove the docker images adhering to the list's order.  If the list is properly maintained and ordered, then a "Remove All" request will likely succeed.

  Ex: After adding the "sshserver.img" target above, the COMPONENT_LST macro should resemble:

      COMPONENT_LST:=sshserver.img

  Ex: Next, add the "mysql.img" target that relies on "sshserver.img":

      COMPONENT_LST:=mysql.img sshserver.img

  Note: "mysql.img" appears before "sshserver.img" in the list due to "mysql.img" static reliance on "sshserver.img".  Separate entries using a space character.

### How to Run make:
If you haven't already established your user account as a member of the docker group, perhaps you should, as it's simpler to type "make" rather than "sudo make" and any artifacts generated by the "sudo make" command, like the individual Image GUID List files, will only be viewable by your least privileged account, not writable/removable by it.  The group membership command looks something like this:
```
> sudo useradd -G docker <YourAccountName> .
```

All explanations below assume:
+ the Root Resource Directory is the current one,
+ the account invoking make is a member of the docker account group,
+ ">" represents the command line prompt.

#### Build All Components:
      > make
#### Build Specific Component:
      > make <ComponentName>.img
  Replace \<ComponentName\> with the name of a Component.

#### Remove options:
+ Remove:  Required to initiate physical deletion of containers and/or their progenitor images.
+ idscope=: Determines if either all GUIDs recorded in an Image GUID List or only a single GUID within this List, identifying the most recent Component version, will be processed by the Remove operation.
  + All - Process every GUID enumerated in the Image GUID List.
  + Current - Process only the most recent GUID from the Image GUID List.
  + AllExceptCurrent - Process every GUID in Image GUID List other than Current.
+ restrict=: Alters the default behavior of the Remove command.  The default behavior removes both an image and its associated container(s).  
  + OnlyContainers - Remove only the containers associated to an image while preserving the image.  
+ complist=: Defines a list of Components to be processed by the Remove operation.   
  + complist='\<ComponentName1\>.img[ \<ComponentName2\>.img ...]'   
    Replace \<ComponentNameN\> with one of the project's Component names. 
Encapsulate the list, if more than one Component, in single or double quotes.  Use a space to separate list elements.  
    ```
> make Remove idscope=All complist=sshserver.img
> make Remove idscope=All complist='mysql.img sshserver.img'
```
#### Example Remove Commands:

+ **Remove All Component Versions for All Components:**
  Deletes all images, their versions, and all associated containers even if the containers are running at the time of this request:  
  ```
> make Remove idscope=All complist=All
```
+ **Remove just the Current Component Version for All Components:**
  Deletes the most recently built image for every Component and all associated containers, even if the containers are running at the time of this request:  
  ```
> make Remove idscope=Current complist=All
```
+ **Remove All the containers for Current Component Version of sshserver.img:**
  Deletes every container associated to the most recently built Component named "sshserver".  
  ```
> make Remove restrict=OnlyContainers idscope=Current complist=sshserver.img
```
+ **Remove All containers and All Components except for the Current ones.**
  Deletes every container and every image version except for the most recent version.  
  ```
> make Remove idscope=AllExceptCurrent complist=All
```

#### Help

To display makefile help simply: 
  ```
> make help
```
### Sample makefile

A sample makefile project containing a makefile, the Component file and Component directories supplying simple Dockerfiles, implementing a project based on the sshserver and mysql Components used as examples above, exists in the archive called "sample.tar.gz".  
+ Extract its contents, preserving the directory structure, to some directory.
+ Start a command line console.
+ Make the "sample" directory current.
+ Run the Build using the directions [above](#how-to-run-make).  As an alternative, consider running the test script before 



### Test Script

The test script named: "MakefileTest.sh" exercisers a limited number of scenarios to better guarantee the proper operation of the makefile script.  "MakefileTest.sh" exists in the Root Resource Directory along with the "makefile" within the archive file containing the [Sample makefile](#sample-makefile).  Assuming the sample makefile has been downloaded, extracted, and account being employed to run the script is a member of the docker group:

+ Start a command line console.
+ Make the "sample" directory current.
+ Run the testscript:
  ```
> ./MakefileTest.sh
```

The test script finishes within a minute.  A final message of:"Testing Complete & Successful!" indicates the makefile script should run correctly within your environment.

### License

The MIT License (MIT)
Copyright (c) 2014 Richard Moyse License@Moyse.US

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
