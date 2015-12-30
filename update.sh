#!/bin/bash

########################################################
# https://github.com/lrs-lang/lib/blob/master/Documentation/adoc/building_and_using.adoc
########################################################

function get_rustc_url () {
	echo $(wget -o /dev/null -O - https://raw.githubusercontent.com/lrs-lang/lib/master/VERSION.adoc | grep X86_64_NIGHTLY | awk '{print $2}')
}

pwd=$PWD

# create pkg/new and pkg/actual dirs
function prepare () {
	mkdir -p $1/actual  # the actual version
	mkdir -p $1/current # actual extracted
	mkdir -p $1/new     # the last downloadable version
}

function update_compiler () {
	local COMP_DIR=$1
	local NIGHTLY=$(get_rustc_url)
	local FNAME=${NIGHTLY##*/}
	local LAST=$(md5sum $COMP_DIR/new/$FNAME | awk '{print $1}')
	local PREV=$([ -e $COMP_DIR/actual/$FNAME ] && md5sum $COMP_DIR/actual/$FNAME | awk '{print $1}' || echo 0)
    
	if [ $LAST == $PREV ]
	then
		echo no rustc compiler update available
		#rm -rf pkg/new/*
	else
		echo updating the rustc compiler
		#mv $COMP_DIR/new/$FNAME $COMP_DIR/actual/$FNAME \
		cp $COMP_DIR/new/$FNAME $COMP_DIR/actual/$FNAME \
		&& rm -rf $COMP_DIR/current/* \
		&& tar xzf $COMP_DIR/actual/$FNAME -C $COMP_DIR/current/ \
		&& cd $COMP_DIR/current/rust-nightly-x86_64-unknown-linux-gnu/ \
		&& sudo bash install.sh
		local res=$?
		cd $pwd
		return $res
	fi
}

function download_compiler () {
	local COMP_DIR=pkg/compiler
	local NIGHTLY=$(get_rustc_url)
	local FNAME=${NIGHTLY##*/}
	
	prepare $COMP_DIR
	wget -O $COMP_DIR/new/$FNAME -c $NIGHTLY

	update_compiler $COMP_DIR

}

function update_repo () {
    local REPO_URL=$1
    local REPO_DIR=$2
    
    mkdir -p $(dirname $REPO_DIR)
    if [ -d $REPO_DIR ]
    then
	echo "updating $REPO_DIR ..."
        cd $REPO_DIR
        git pull
        cd -
    else
	echo "downloading repository $REPO_URL to $REPO_DIR ..."
        git clone $REPO_URL $REPO_DIR
    fi
}


function compile_driver () {
	echo "compiling the driver ..."
  update_repo https://github.com/lrs-lang/driver.git repo/driver && \
  cd repo/driver && make && \
  local rustc_dir=$(dirname $(which rustc)) && \
  sudo install lrsc $rustc_dir/ 
  print_result "driver lsr installation"
}

function print_result () {
	local res=$?
	cd $pwd
	echo -n "$@: "
	test $res && echo OK || echo KO!
	return $res
}

function build_comp_plugins () {
  echo 'running make_plugin.sh ...' 
  cp make_plugin.sh $pwd/repo/lrs/lib/ && \
  cd $pwd/repo/lrs/lib && ./make_plugin.sh 
  print_result make_plugin
}

function build_comp_assembly () {
  echo 'running make_asm.sh'	&& cd $pwd/repo/lrs/lib && ./make_asm.sh 
  print_result make_asm
}

function build_first_lrs () {
  echo 'running make_lrs.sh'	&& cd $pwd/repo/lrs/lib && ./make_lrs.sh 
  print_result make_lrs
}

function try_lrs () {
	echo 'try compiling using lrs'
	rm helloworld 2>/dev/null
	lrsc helloworld.rs
	test -e helloworld
	print_result use lrs
}

function build_libtest () {
	cp make_libtest.sh $pwd/repo/lrs/lib/
	echo 'try compiling libtest'
	cd $pwd/repo/lrs/lib && ./make_libtest.sh
	print_result make_libtest
}

function build_builder () {
	update_repo https://github.com/lrs-lang/build.git repo/build
	echo 'try to make builder'
	cd $pwd/repo/build && make
	print_result make build
}

function run_tests () {
	cd $pwd/repo/lrs/lib/tests/
#	lrsc --test lib.rs && ./tests
	make && ./tests
	print_result run_tests
}



download_compiler && \
LRS_DIR=$pwd/repo/lrs/lib && \
update_repo https://github.com/lrs-lang/lib.git $LRS_DIR && \
export LRS_OBJ_PATH=$(realpath $LRS_DIR)/obj && \
echo "LRS_OBJ_PATH = $LRS_OBJ_PATH" && \
compile_driver && \
build_comp_plugins && \
build_comp_assembly && \
build_first_lrs && \
try_lrs && \
build_libtest && \
build_builder && \
run_tests 
