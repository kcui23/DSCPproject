#!/bin/bash

base_url="http://aleph.gutenberg.org"
n=$SLURM_ARRAY_TASK_ID
start= echo "10 * ($n - 1) + 10001"
end= echo "10 * $n + 10000"

download_file() {
    dir1=$(printf "%d" $(($1/10000)))
    dir2=$(printf "%d" $(($1%10000/1000)))
    dir3=$(printf "%d" $(($1%1000/100)))
    dir4=$(printf "%d" $(($1%100/10)))

    for suffix in "" "-0" "-8"; do
        url="${base_url}/${dir1}/${dir2}/${dir3}/${dir4}/${1}/${1}${suffix}.txt"
        wget --spider $url

        if [ $? -eq 0 ]; then
            wget -P data $url
	    break
        fi
    done
}
for i in $(seq $start $end);do
    download_file $i
done
