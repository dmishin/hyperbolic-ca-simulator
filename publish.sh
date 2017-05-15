#!/bin/sh
set -e

echo Publishing data on dmishin home page
ODIR=../homepage-sources/res/hyperbolic-ca-simulator

cp -r *.html *.js media *.css README.md $ODIR

cd $ODIR

git add *
git status

git commit -m "Publishing updated hyperbolic-ca-simulator"

git push
