#!/bin/sh

REPO_URL=$1
REPO_DIR=$2

pwd=$PWD

mkdir -p $(dirname $REPO_DIR)
if [ -d $REPO_DIR ]
then
	echo "updating $REPO_DIR ..." \
	&& cd $REPO_DIR \
	&& git pull
	cd $pwd
else
	echo "downloading repository $REPO_URL to $REPO_DIR ..."
	git clone $REPO_URL $REPO_DIR
fi
