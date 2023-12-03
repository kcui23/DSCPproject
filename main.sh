#!/bin/bash                                                                                             
if [ ! -d "packages" ]; then
    mkdir vocab
    mkdir total
    mv NRC-Lexicon.txt vocab
    tar -xzf R413.tar.gz
    tar -xzf packages.tar.gz
fi

export PATH=$PWD/R/bin:$PATH
export RHOME=$PWD/R
export R_LIBS=$PWD/packages

Rscript main.R


base_url="http://aleph.gutenberg.org"
n=$1
start=$(echo "20 * ($n - 1) + 10001" | bc)
end=$(echo "20 * $n + 10000" | bc)

download_file() {
    dir1=$(printf "%d" $(($1/10000)))
    dir2=$(printf "%d" $(($1%10000/1000)))
    dir3=$(printf "%d" $(($1%1000/100)))
    dir4=$(printf "%d" $(($1%100/10)))

    for suffix in "" "-0" "-8"; do
        url="${base_url}/${dir1}/${dir2}/${dir3}/${dir4}/${1}/${1}${suffix}.txt"
        wget --spider $url

        if [ $? -eq 0 ]; then
            wget $url
	    break
        fi
    done
}
for i in $(seq $start $end);do
    download_file $i
done


for file in *.txt; do
    if [[ -f "$file" ]]; then
        Rscript main.R $file
    fi
done


rm *.txt
