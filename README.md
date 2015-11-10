Gunzip
======

Copyright 2015 Laurens Holst

Project information
-------------------

Extracts files compressed with the gzip (.gz) format.

Original author: Laurens Holst <laurens.nospam@grauw.nl>
Original site: <https://bitbucket.org/grauw/gunzip>
License: Simplified BSD License

Heavily modified by me (Wouter Vermaelen).


System Requirements
-------------------

  * MSX, MSX2, MSX2+ or MSX turboR
  * 16K video RAM
  * 64K main RAM
  * MSX-DOS 2


Usage instructions
------------------

Run gunzip from MSX-DOS 2, specifying the gzipped file on the command line.

Usage:

    gunzip [options] <archive.gz> <outputfile>

Options:

  * `/q` Quiet mode, suppress messages.

    Suppresses the output of informational and warning messages.
    Error messages, however, are always output.

If no output file is specified, the archive will be tested.


Development information
-----------------------

Gunzip is free and open source software. If you want to contribute to the
project you are very welcome to. Please contact me at any one of the places
mentioned in the project information section.

You are also free to re-use code for your own projects, provided you abide by
the license terms.

Building the project with some of your own modifications is really easy on all
modern desktop platforms. On Mac OS X and Linux, simply invoke `make` to build
the binary and symbol files into the `bin` directory:

    make

Windows users can open the `Makefile` and build by pasting the line in the `all`
target into the Windows command prompt.

To launch the build in openMSX after building, put a copy of `MSXDOS2.SYS` and
`COMMAND2.COM` and some GZ files to test with in the `bin` directory, and then
invoke the `make run` command.

Note that the [glass](https://bitbucket.org/grauw/glass) assembler which is
embedded in the project requires [Java 7](http://java.com/getjava). To check
your Java version, invoke the `java -version` command.

With very minor changes (replace '&' with 'AND' in expressions) the source code
also compiles with with compass and probably most gen80 compatible assemblers.
