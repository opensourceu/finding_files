#!/bin/bash

# test_find_include_exclude.sh

################################################################################
# MIT License
#
# Copyright (c) 2024-2025 Zartaj Majeed
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
################################################################################

function usage {
  echo "Usage: test_find_include_exclude.sh [-c | -C | -p]"
  echo "Create test files and directories for find_include_exclude.sh"
  echo
  echo "-c: create test files and directories"
  echo "-C: colorize test filenames read from stdin"
  echo "-p: print test files and directories"
  echo "-h: help"
  echo
  echo "Examples:"
  echo "test_find_include_exclude.sh -c"
  echo "test_find_include_exclude.sh -p"
  echo "test_find_include_exclude.sh -C < <(find_include_exclude.sh -i "*.include*" -x "*.exclude*" testd)"
}

function doCreateTestDir {
  echo "Create test data in $testdir"
  mkdir -p $testdir

  if [[ -n $(ls -A $testdir) ]]; then
    echo >&2 "error: test directory $testdir is not empty, please delete and recreate"
    exit 1
  fi

  touch $testdir/file_1.txt
  touch $testdir/file_2.exclude.txt
  touch $testdir/file_3.include.txt
# create a file that matches include and exclude patterns
  touch $testdir/file_4.include.exclude.txt

  mkdir -p $testdir/dir_1
  touch $testdir/dir_1/file_5.txt
  touch $testdir/dir_1/file_6.include.txt
  touch $testdir/dir_1/file_7.exclude.txt

  mkdir -p $testdir/dir_1/dir_2.exclude
  touch $testdir/dir_1/dir_2.exclude/file_8.txt
  touch $testdir/dir_1/dir_2.exclude/file_9.include.txt

# create some empty directories
  mkdir -p $testdir/dir_3
  mkdir -p $testdir/dir_4.include
  mkdir -p $testdir/dir_5.exclude

  mkdir -p $testdir/dir_6.include
  touch $testdir/dir_6.include/file_10.txt
  touch $testdir/dir_6.include/file_11.exclude.txt
  touch $testdir/dir_6.include/file_12.include.txt

# write a byte to each file
  find $testdir -type f -empty -exec bash -c "echo '.' > {}" \;
}

function doPrintTestDir {
  if [[ ! -d $testdir || -z $(ls -A $testdir) ]]; then
    echo "Test directory $testdir is empty or doesn't exist"
    exit 0
  fi
  echo "Test directory tree $testdir"
# passthru ls colors
# include pattern bold green \e[1;32m
# exclude pattern bold red \e[1;31m
# include.exclude pattern bold yellow \e[1;32m
# \e[m is reset, \x1b is \e for sed
  ls -lAR --color=always $testdir |
  sed -E "
    /(dir|file)_[0-9]+\.include\.exclude.*/ { s//\x1b[m\x1b[1;33m&\x1b[m/; n }
    /(dir|file)_[0-9]+\.include.*/s//\x1b[m\x1b[1;32m&\x1b[m/
    /(dir|file)_[0-9]+\.exclude.*/s//\x1b[m\x1b[1;31m&\x1b[m/
  "
  echo

}

# colorize test filenames read on stdin
function doColorizeInput {
  sed -E "
    /(dir|file)_[0-9]+\.include\.exclude[^/]*/ { s//\x1b[m\x1b[1;33m&\x1b[m/g; n }
    /(dir|file)_[0-9]+\.include[^/]*/s//\x1b[m\x1b[1;32m&\x1b[m/g
    /(dir|file)_[0-9]+\.exclude[^/]*/s//\x1b[m\x1b[1;31m&\x1b[m/g
  "
}

testdir=testd

while getopts "cChp" opt; do
  case $opt in
    c)
      createTestDir=true
      ;;
    C)
      colorizeInput=true
      ;;
    p)
      printTestDir=true
      ;;
    h) usage; exit 0
      ;;
    *) usage; exit 1
  esac
done
shift $((OPTIND - 1))

: ${createTestDir:=false}
: ${printTestDir:=false}
: ${colorizeInput:=false}

if $colorizeInput; then
  doColorizeInput
  exit
fi

if $createTestDir; then
  doCreateTestDir
fi

doPrintTestDir

