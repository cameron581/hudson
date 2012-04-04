#!/usr/bin/env bash

function check_result {
  if [ "0" -ne "$?" ]
  then
    echo $1
    exit 1
  fi
}

if [ -z "$WORKSPACE" ]
then
  echo WORKSPACE not specified
  exit 1
fi

if [ -z "$REPO_BRANCH" ]
then
  echo REPO_BRANCH not specified
  exit 1
fi

if [ -z "$LUNCH" ]
then
  echo LUNCH not specified
  exit 1
fi

# colorization fix in Jenkins
export CL_PFX="\"\033[34m\""
export CL_INS="\"\033[32m\""
export CL_RST="\"\033[0m\""

cd $WORKSPACE
rm -rf archive
mkdir -p archive
export BUILD_NO=$BUILD_NUMBER
unset BUILD_NUMBER

export PATH=~/bin:$PATH

export USE_CCACHE=1
export BUILD_WITH_COLORS=0

REPO=$(which repo)
if [ -z "$REPO" ]
then
  mkdir -p ~/bin
  curl https://dl-ssl.google.com/dl/googlesource/git-repo/repo > ~/bin/repo
  chmod a+x ~/bin/repo
fi

git config --global user.name $(whoami)@$NODE_NAME
git config --global user.email jenkins@cyanogenmod.com

if [ ! -d $REPO_BRANCH ]
then
  mkdir $REPO_BRANCH
  if [ ! -z "$BOOTSTRAP" -a -d "$BOOTSTRAP" ]
  then
    echo Bootstrapping repo with: $BOOTSTRAP
    cp -R $BOOTSTRAP/.repo $REPO_BRANCH
  fi
  cd $REPO_BRANCH
  repo init -u https://github.com/teamgummy/platform_manifest.git -b $REPO_BRANCH
else
  cd $REPO_BRANCH
  # temp hack for turl
  repo init -u https://github.com/teamgummy/platform_manifest -b $REPO_BRANCH
fi

#cp $WORKSPACE/hudson/$REPO_BRANCH.xml .repo/local_manifest.xml

echo Syncing...
repo sync -d 
check_result repo sync failed.
echo Sync complete.

if [ -f $WORKSPACE/hudson/$REPO_BRANCH-setup.sh ]
then
  $WORKSPACE/hudson/$REPO_BRANCH-setup.sh
fi

. build/envsetup.sh
lunch $LUNCH
check_result lunch failed.

UNAME=$(uname)

if [ -z "$CLEAN_TYPE" ]
then
  echo CLEAN_TYPE not specified, assuming already clean
else
  make $CLEAN_TYPE
fi

mka gummy 2>&1 | tee "$LUNCH".log

ZIP=$(tail -2 "$LUNCH".log | cut -f3 -d ' ' | cut -f1 -d ' ' | sed -e '/^$/ d')
scp /var/lib/jenkins/workspace/android/master/out/target/product/$DEVICE/$ZIP website@exynos.co:/home/website/www/gummy.exynos.co/public_html/$DEVICE/$ZIP
echo zip is at http://cna.exynos.co/$DEVICE/$ZIP Happy flashing!
check_result Build failed.
mkdir $WORKSPACE/archive
cp /var/lib/jenkins/workspace/android/master/out/target/product/$DEVICE/$ZIP $WORKSPACE/archive