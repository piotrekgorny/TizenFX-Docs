#!/bin/bash -e
SCRIPT_DIR=$(dirname $(readlink -f $0))

VERSIONS="API4 API5 API6 API7 API8 API9"
BRANCH_API9=master
STABLE="API8"

GIT_URL="https://github.com/Samsung/TizenFX.git"
REPO_DIR="$SCRIPT_DIR/repos"
OBJ_DIR="$SCRIPT_DIR/obj"
SITE_DIR="$SCRIPT_DIR/_site"

branchname() {
  local version=$1
  local branchvar="BRANCH_$version"
  local branch=${!branchvar}
  if [ -z "$branch" ]; then
    echo $version
  else
    echo $branch
  fi
}

pushd() {
  command pushd "$@" > /dev/null
}

popd() {
  command popd "$@" > /dev/null
}

clone_repos() {
  if [ ! -d $REPO_DIR ]; then
    mkdir -p $REPO_DIR
  fi

  for v in $VERSIONS; do
    echo "Retrieving $v ..."
    local branch=$(branchname $v)
    if [ -d "$REPO_DIR/$v/.git" ]; then
      pushd $REPO_DIR/$v
      git fetch origin
      git reset --hard origin/$branch
      popd
    else
      pushd $REPO_DIR
      git clone $GIT_URL --branch $branch --single-branch --depth 1 $v
      popd
    fi
  done
}

TEMP_SLN_NAME="_tizenfx_public"
TEMP_SLN_FILE="$TEMP_SLN_NAME.sln"

restore_repos() {
  for v in $VERSIONS; do
    echo "Restoring $v ..."
    if [ -d "$REPO_DIR/$v" ]; then
      pushd $REPO_DIR/$v
      if [ ! -f $TEMP_SLN_FILE ]; then
        dotnet new sln -n $TEMP_SLN_NAME
        dotnet sln $TEMP_SLN_FILE add src/**/*.csproj
        if [ -d internals/src ]; then
          dotnet sln $TEMP_SLN_FILE add internals/src/**/*.csproj
        fi
      fi
      dotnet restore $TEMP_SLN_FILE
      popd
    else
      echo "No repository to restore : [$v]"
      exit 1
    fi
  done
}

generate_metadata() {
  docfx metadata $SCRIPT_DIR/docfx.json
}

build_docs() {
  docfx build $SCRIPT_DIR/docfx.json
}

generate_symlinks() {
  pushd $SITE_DIR
  rm -f stable latest devel master
  ln -s $STABLE stable
  ln -s stable latest
  for v in $VERSIONS; do
    local branch=$(branchname $v)
    if [[ $branch != $v ]]; then
      ln -s $v $branch
    fi
  done
  ln -s master devel
  popd
}

build_index() {
  command node $SCRIPT_DIR/build-index.js
}

build_full() {
  clone_repos
  restore_repos
  generate_metadata
  build_docs || echo "Ignore errors..."
  build_index
  generate_symlinks
}

clean() {
  rm -fr $OBJ_DIR/.cache
  rm -fr $SITE_DIR
}

purge() {
  clean
  rm -fr $OBJ_DIR
  rm -fr $REPO_DIR
}

CMD=$1
case "$CMD" in
  clone) clone_repos ;;
  restore) restore_repos ;;
  metadata) generate_metadata ;;
  build) build_docs ;;
  symlinks) generate_symlinks ;;
  index) build_index ;;
  clean) clean ;;
  purge) purge ;;
  "") build_full ;;
  *) echo "invalid arguments" && exit 1 ;;
esac

