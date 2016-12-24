#!/bin/bash
vmfile=$1
vm=$(basename $1 ".id" | tr -d '\000-\011\013\014\016-\037\r')
idpath=$(cat $vmfile | tr -d '\000-\011\013\014\016-\037\r')
id=$(cat $idpath | tr -d '\000-\011\013\014\016-\037\r')
filepath="file_lists/$id.files"
echo $id
echo $vm
echo $filepath
delm="------------------------"
echo $delm
echo "CEPH RECOVERY"
echo "Assemble $vm with ID $id"
echo $delm
echo "Searching file list"
if [[ ! -e "$filepath" ]]; then
	echo "[ERROR] No files for $vm ($id.files does not exist)"
	exit
fi

echo "$filepath found"
echo $delm
imgfile="data/$vm.qcow2"
if [ ! -d "data" ]; then
	mkdir "data"
fi

if [ -f $imgfile ]; then
	echo "Image $imagefile already exists"
	echo "Aborting recovery"
	exit
fi

echo "Output Image will be $imgfile"
echo $delm
count=$(cat $filepath | wc -l)
last=$(tail -1 $filepath | rev | cut -d "/" -f 1 | rev | cut -d "." -f 3 | cut -d "_" -f 1)
lastnum=$((16#$last))
missinglines=$(($lastnum-$count-1))
echo "There are $count present parts, $missinglines parts missing"
echo $delm
missing=0
tmp="$id.files.tmp"

if [ $missinglines -gt 0 ]; then
	echo "There are  missing parts. These parts will be filled with zeroes!"
	echo "Searching for missing blocks"
	echo "Tmp-File: $tmp"
	if [[ -f $tmp ]]; then
		rm $tmp
	fi
	echo $delm
	echo "Checking if there are missing parts..."
	expected=0
	missing=0
	for x in $(cat $filepath); do
		ver=$(echo $x | rev | cut -d "/" -f 1 | rev | cut -d "." -f 3 | cut -d "_" -f 1)
		num=$((16#$ver))
		exhex=$(printf '%x\n' $expected)
		if [ ! $num == $expected ]; then
			echo "ERROR: Part $exhex is missing, got $ver"
			to=$(($num-1))
			missingamount=$(($to-$expected+1))
			echo "       $missingamount blocks missing"
			missing=$(($missing+$missingamount))
			for y in $(seq 1 $missingamount); do
				echo "broken_block" >> $tmp
			done
		fi
		echo "$x" >> $tmp
		expected=$(($num+1))
	done
else
	echo "Fast completeness check successful"
	cp $filepath $tmp
fi

if [ $missing -gt 0 ]; then
	echo "WARNING: There are $missing missing parts!!!"
	echo "There could be a problem when reassembling"
	echo "Missing blocks will be filled with zeroes (4MB)"
	echo "Would you like to continue anyway?"
	read -p "[y/n] " cont
	if [ $cont != "y" ]; then
		echo "Aborting..."
		exit
	fi
else
	echo "All parts are present as far as we know!"
fi
echo $delm
pcount=$count
count=$(cat $tmp | wc -l)
echo "Starting reassembly of $pcount known blocks (Total: $count blocks)"
curr=1
echo -ne "0%\r"
for i in $(cat $tmp); do
	res=$(dd if=$i of=$imgfile bs=512 conv=notrunc oflag=append status=none)
	perc=$((($curr*100)/$count))
	bar="$perc % ["
	for j in {1..100}; do
		if [ $j -gt $perc ]; then
			bar=$bar"_"
		else
			bar=$bar"#"
		fi
	done
	bar=$bar"]\r"
	echo -ne $bar
	curr=$(($curr+1))
done
echo ""
echo "Image written to $imgfile"
