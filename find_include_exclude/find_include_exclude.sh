#!/bin/bash

# find_include_exclude.sh

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
  echo "Usage: find_include_exclude.sh [-b behavior] [-i include_glob_pattern] [-x exclude_glob_pattern] [-X exclude_dir_glob_pattern] [-h] [path]"
  echo "Find files with names that match include patterns and don't match exclude patterns"
  echo
  echo "-b behavior: include and exclude similar to grep or rsync, default is grep behavior"
  echo "-i glob_pattern: include files and directories that match glob pattern"
  echo "-x glob_pattern: exclude files and directories that match glob pattern"
  echo "-X glob_pattern: exclude directories that match glob pattern, only valid for grep behavior"
  echo "-h: help"
  echo "path: starting point to find files"
  echo
  echo "Examples:"
  echo "find_include_exclude.sh -b grep -i \"*.include*\" -x \"*.exclude*\" -X \"dir*.exclude*\" ."
}

# emulate grep include/exclude behavior
# run find on generated expression to evaluate all include/exclude patterns
# pipe find output to awk that filters paths based on grep behavior
function behaveGrep {

# parentheses around comma expression prevent evaluation after excluded directory match
  eval find "$root" ${excludeDirClauses[*]} '\(' -printf "\"%p: \"" "${matchClauses[*]}" , -printf "\"\\n\""  '\)' |
  awk -v restrictToIncludes=$restrictToIncludes '
    {
      path = substr($1, 1, length($1) - 1)
      lastMatch = ""
    }

    # check results of all include/exclude matches
    # last match wins
    {
      for(i = 2; i <= NF; ++i) {
        negate = substr($i, 1, 1) == "-"? 1 : 0
        code = substr($i, 2, 1)
        if(negate == 0) {
          lastMatch = code
        }
      }

      if(lastMatch == "i" || restrictToIncludes == 0 && lastMatch != "x") {
        print path
      }
    }
  '
}

# emulate rsync include/exclude behavior
# run find on generated expression to evaluate all include/exclude patterns
# pipe find output to awk that filters paths based on rsync behavior
function behaveRsync {

  eval find "$root" ${excludeDirClauses[*]} '\(' -printf "\"%p:%d\"" , -type d -printf "\":d \"" -o -printf "\":f \"" "${matchClauses[*]}" , -printf "\"\\n\""  '\)' |
  awk '
    BEGIN {
      excludeDeeperThan = -1
    }

    {
      split($1, info, /:/)
      path = info[1]
      depth = info[2]
      isDirectory = info[3] == "d"
    }

    # skip all levels inside excluded directory
    # unset depth check if back at level of excluded directory or higher
    excludeDeeperThan >= 0 {
      if(depth > excludeDeeperThan) {
        next
      }
      excludeDeeperThan = -1
    }

    # check results of all include/exclude matches
    # first match wins
    {
      firstMatch = ""
      for(i = 2; i <= NF; ++i) {
        negate = substr($i, 1, 1) == "-"? 1 : 0
        code = substr($i, 2, 1)
        if(negate == 0) {
          firstMatch = code
          break
        }
      }

      if(firstMatch == "x" && isDirectory = 1) {
        excludeDeeperThan = depth
      }

      if(firstMatch == "i" || firstMatch != "x") {
        print path
      }
    }
  '
}

# include/exclude glob patterns
declare -a filterPatterns
# type of pattern, i is include pattern, x is exclude pattern
declare -a filterPatternCodes
# exclude directory patterns
declare -a excludeDirPatterns

# these arrays are only used in an informational message
declare -a includeNamePatterns
declare -a excludeNamePatterns

while getopts "b:hi:tx:X:" opt; do
  case $opt in
    b)
      behavior=$OPTARG
      ;;
    i)
      filterPatterns+=("$OPTARG")
      filterPatternCodes+=(i)
      includeNamePatterns+=("$OPTARG")
      ;;
    x)
      filterPatterns+=("$OPTARG")
      filterPatternCodes+=(x)
      excludeNamePatterns+=("$OPTARG")
      ;;
    X)
      excludeDirPatterns+=("$OPTARG")
      ;;
    h) usage; exit 0
      ;;
    *) usage; exit 1
  esac
done
shift $((OPTIND - 1))

: ${restrictToIncludes:=0}
: ${behavior:=grep}

if [[ ! $behavior =~ grep|rsync ]]; then
  echo >&2 "error: unknown behavior $behavior choice for -b option"
  exit 1
fi

if ((${#excludeDirPatterns[*]} > 0)) && [[ $behavior != grep ]]; then
  echo >&2 "error: -X option is not valid for $behavior behavior"
  exit 1
fi

root=$1

echo "Find files in root \"$root\", behavior $behavior, include patterns \"${includeNamePatterns[*]}\", exclude patterns \"${excludeNamePatterns[*]}\", exclude directory patterns \"${excludeDirPatterns[*]}\""

# generate clauses for find expression that match filenames
declare -a matchClauses

for ((i = 0; i < ${#filterPatterns[*]}; ++i)); do
  code=${filterPatternCodes[i]}
  pat=${filterPatterns[i]}
  matchClauses+=(" , " -name "\"$pat\"" -printf "\" +$code\"" -o -printf "\" -$code\"")
done

if [[ $behavior == rsync ]]; then
  behaveRsync
  exit
fi

if ((${#filterPatternCodes[*]} > 0)) && [[ ${filterPatternCodes[0]} == i ]]; then
  restrictToIncludes=1
fi

# generate clauses for find expression that match directory names
declare -a excludeDirClauses

for ((i = 0; i < ${#excludeDirPatterns[*]}; ++i)); do
  pat=${excludeDirPatterns[i]}
  excludeDirClauses+=(-type d -name "\"$pat\"" -prune -o)
done

behaveGrep
