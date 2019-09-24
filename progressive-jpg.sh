#!/bin/bash

sourcedir="$1"
swpFolderPrefix="_swp"
destdir="$sourcedir$swpFolderPrefix"

if [ -z "$sourcedir" ]; then
    echo "$sourcedir not found"
    exit
fi

projectdir="$sourcedir/../"
sourcedirname=$(basename "$sourcedir")

if [ ! -d "$destdir" ]; then
    mkdir "$destdir"
fi

if [ -d "$destdir" ]; then
    lockfile="$projectdir$sourcedirname.lock"

    haslockfile=1
    yesterday=$(date -d "-1 day" +%s)
    if [[ ! -e $lockfile ]]; then
        haslockfile=0
        echo $yesterday > $lockfile
    fi

    lasttimestamp=$(cat $lockfile)
    if [[ -z "$lasttimestamp" ]]; then
        lasttimestamp=$yesterday
    fi

    minimumsize=0

    find "$sourcedir" -regex ".*\.\(jpg\|JPG\|JPEG\|jpeg\)" -print0 | while read -d $'\0' file; do
        if [[ "$file" != */.* ]]; then
            filetime=$(stat -c %Y "$file")
            if [ $haslockfile == 0 ] || [ $filetime -gt $lasttimestamp ]; then

                checkProgressive=$(identify -verbose "$file" | grep Interlace | xargs)
                if [ "$checkProgressive" != "Interlace: JPEG" ]; then
                    jpegoptim --quiet --dest=$destdir --size=100% --all-progressive "$file"
                    optimizedfile=$destdir/$(basename "$file")

                    if [ -f "$optimizedfile" ]; then
                        actualsize=$(du -b "$optimizedfile" | cut -f 1)
                        if [ $actualsize -gt $minimumsize ]; then
                            chown $(stat -c "%U:%G" "$file") "$optimizedfile"
                            chmod $(stat -c "%a" "$file") "$optimizedfile"
                            touch -t $(date +"%Y%m%d%H%M.%S" -r "$file") "$optimizedfile"
                            echo "SUCCESS: $file"

                            continue
                        else
                            rm $optimizedfile
                        fi
                    fi

                    jpegtran -progressive -outfile "$optimizedfile" "$file"

                    if [ -f "$optimizedfile" ]; then
                        actualsize=$(du -b "$optimizedfile" | cut -f 1)
                        if [ $actualsize -gt $minimumsize ]; then
                            chown $(stat -c "%U:%G" "$file") "$optimizedfile"
                            chmod $(stat -c "%a" "$file") "$optimizedfile"
                            touch -t $(date +"%Y%m%d%H%M.%S" -r "$file") "$optimizedfile"
                            echo "SUCCESS: $file"
                        else
                            echo "ERROR: $file"
                            rm $optimizedfile
                        fi
                    else
                        echo "ERROR: $file"
                    fi
                fi
            fi
        fi
    done

    if [ ! -z "$(ls -A $destdir)" ]; then
        mv $destdir/* $sourcedir
    fi
    rm -r $destdir
fi
