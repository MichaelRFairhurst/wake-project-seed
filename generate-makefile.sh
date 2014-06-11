#!/bin/bash
deps=( )
mocks=( )
while IFS='' read LINE
do
  if [ "${LINE:0:5}" == "every" ]
  then
    break
  fi
  if [ -z "$LINE" ]
  then
    continue
  fi
  if [ "${LINE:0:1}" == "#" ]
  then
    continue
  fi

  CLASSNAME=$(echo $LINE | sed 's/^import \(.*\);$/\1/')
  LASTFOUR=$(echo $CLASSNAME | tail -c 5)

  if [ "$LASTFOUR" == "Mock" ]
  then
	mocks[${#mocks[@]}]="$2/$CLASSNAME.table.md5"
  fi

  deps[${#deps[@]}]="$2/$CLASSNAME.table.md5"

done < $1

echo bin/wakeobj/$( basename $1 | sed 's/\.wk/.o/'): $1 ${deps[@]}
echo bin/waketable/$( basename $1 | sed 's/\.wk/.table/'): $1 ${deps[@]}
echo MOCKS := \$\(MOCKS\) ${mocks[@]}
