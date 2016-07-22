#!/bin/bash

#setup Yocto Eclipse Crops plug-in build environment for Neon
#comment out the following line if you wish to use your own http proxy settings
#export http_proxy=http://proxy.yourproxyinfo.com:8080

help ()
{
  echo -e "\nThis script sets up the Yocto Project Eclipse Crops plugins build environment"
  echo -e "All files are downloaded from the Yocto Project mirror by default\n"
  echo -e "Usage: $0 [--upstream]\n";
  echo "Options:"
  echo -e "--upstream - download from the upstream Eclipse repository\n"
  echo -e "Example: $0 --upstream\n";
  exit 1;
}

while getopts ":h" opt; do
  case $opt in
    h)
      help
      ;;
  esac
done

err_exit() 
{
  echo "[FAILED $1]$2"
  exit $1
}

uname_s=`uname -s`
uname_m=`uname -m`
case ${uname_s}${uname_m} in
  Linuxx86_64*)
    inst_arch=linux64 
    inst_ext=tar.gz
    ;;
  Linuxi*86)
    inst_arch=linux32
    inst_ext=tar.gz
    ;;
  Darwinx86_64)
    inst_arch=mac64
    inst_ext=tar.gz
    inst_exec="Eclipse Installer.app/Contents/MacOS/eclipse-inst"
    inst_ini="Eclipse Installer.app/Contents/Eclipse/eclipse-inst.ini"
    ;;
  MSYS_NT-6.3x86_64)
    inst_arch=win64
    inst_ext=exe
    ;;
  *)
    echo "Unknown ${uname_s}${uname_m}"
    exit 1
    ;;
esac

#make sure that the utilities we need exist
command -v wget > /dev/null 2>&1 || { echo >&2 "wget not found. Aborting installation."; exit 1; }
command -v tar > /dev/null 2>&1 || { echo >&2 "tar not found. Aborting installation."; exit 1; }

#parsing proxy URLS
url=${http_proxy}
if [ "x$url" != "x" ]; then
    proto=`echo $url | grep :// | sed -e 's,^\(.*://\).*,\1,g'`
    url=`echo $url | sed s,$proto,,g`
    userpass=`echo $url | grep @ | cut -d@ -f1`
    user=`echo $userpass | cut -d: -f1`
    pass=`echo $userpass | grep : | cut -d: -f2`
    url=`echo $url | sed s,$userpass@,,g`
    host=`echo $url | cut -d: -f1`
    port=`echo $url | cut -d: -f2 | sed -e 's,[^0-9],,g'`
    [ "x$host" = "x" ] && err_exit 1 "Undefined proxy host"
    PROXY_PARAM="-Dhttp.proxySet=true -Dhttp.proxyHost=$host"
    [ "x$port" != "x" ] && PROXY_PARAM="${PROXY_PARAM} -Dhttp.proxyPort=$port"
fi

# prepare the Eclipse installer in folder "eclipse-inst"
ep_name=neon
inst_URI=http://download.eclipse.org/oomph/epp/${ep_name}/R/eclipse-inst-${inst_arch}.${inst_ext}

if [ ! -f "eclipse-inst/${inst_exec}" ]; then

  pushd .

  if [ ! -d eclipse-inst -o -h eclipse-inst ]; then
    if [ -d eclipse-inst-${ep_name} ]; then
      rm -rf eclipse-inst-${ep_name}
    fi
    mkdir eclipse-inst-${ep_name}
    cd eclipse-inst-${ep_name}
  else
    rm -rf eclipse-inst
  fi

  # For now always download from upstream, until we decide to mirror oomph
  if [[ "$1" = "--upstream" ]]; then
        wget "$inst_URI"
  else
        wget "$inst_URI"
  fi

  echo -e "Please wait. Extracting Eclipse Installer: eclipse-inst-${inst_arch}.${inst_ext}\n"

  if [ -f eclipse-inst-${inst_arch}.${inst_ext} ]; then
      if [[ "$inst_ext" = "tar.gz" ]]; then
        tar xfz eclipse-inst-${inst_arch}.${inst_ext} || err_exit $? "extracting Eclipse Installer failed"
      else
        eclipse-inst-${inst_arch}.exe || err_exit $? "extracting Eclipse installer failed"
      fi
  fi

  rm eclipse-inst-${inst_arch}.${inst_ext}

  popd

  if [ ! -d eclipse-inst -o -h eclipse-inst ]; then
    if [ -e eclipse-inst ]; then 
      rm eclipse-inst
    fi
    ln -s "eclipse-inst-${ep_name}/${inst_exec}" eclipse-inst
  fi
fi

# If necessary, set proxy settings in <installer-folder>/configuration/.settings/org.eclipse.core.net.prefs

# Append eclipse-inst.ini
if [[ -e "./eclipse-inst-$ep_name/$inst_ini" ]]; then
    echo "Appending eclipse-inst-$ep_name/$inst_ini"
    echo "-Doomph.redirection.cropsProductCatalog=index:/redirectable.products.setup->https://crops.github.io/eclipse-crops/setups/org.yocto.products.setup" >> "eclipse-inst-$ep_name/${inst_ini}"
    echo "-Doomph.redirection.cropsProjectCatalog=index:/redirectable.projects.setup->https://crops.github.io/eclipse-crops/setups/org.yocto.projects.setup" >> "eclipse-inst-$ep_name/${inst_ini}"
    echo "-Doomph.setup.installer.mode=advanced" >> "eclipse-inst-$ep_name/${inst_ini}"
fi

# Launch installer
if [ -e "./eclipse-inst-$ep_name/$inst_exec" ]; then
    echo "Launching eclipse-inst-$ep_name/$inst_exec"
    "./eclipse-inst-$ep_name/$inst_exec"
fi
