#!/bin/bash

# Bulk process json files from a zip file

# load zip file from the the 1st argument; check that the arg exists otherwise exit with an error
# make sure the $1 is a .zip file
if [[ $1 != *.zip ]]; then
  echo "Please provide a .zip file as an argument"
  exit 1
fi

rm -rf companies features products
cp zip/$1 .
unzip $1

# take the base name of the .zip file and move files from that subdir to the cwd
base=$(basename $1 .zip)
mv $base/* .
rm -rf $base

# remove the .zip file
#rm $1
