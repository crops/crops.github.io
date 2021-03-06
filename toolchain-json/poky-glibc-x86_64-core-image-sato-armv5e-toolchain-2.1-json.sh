#!/bin/sh

[ -z "$ENVCLEANED" ] && exec /usr/bin/env -i ENVCLEANED=1 HOME="$HOME" \
	http_proxy="$http_proxy" https_proxy="$https_proxy" ftp_proxy="$ftp_proxy" \
	no_proxy="$no_proxy" all_proxy="$all_proxy" GIT_PROXY_COMMAND="$GIT_PROXY_COMMAND" "$0" "$@"
[ -f /etc/environment ] && . /etc/environment
export PATH=`echo "$PATH" | sed -e 's/:\.//' -e 's/::/:/'`

INST_ARCH=$(uname -m | sed -e "s/i[3-6]86/ix86/" -e "s/x86[-_]64/x86_64/")
SDK_ARCH=$(echo x86_64 | sed -e "s/i[3-6]86/ix86/" -e "s/x86[-_]64/x86_64/")

verlte () {
	[  "$1" = "`printf "$1\n$2" | sort -V | head -n1`" ]
}

verlt() {
	[ "$1" = "$2" ] && return 1 || verlte $1 $2
}

verlt `uname -r` 2.6.32
if [ $? = 0 ]; then
	echo "Error: The SDK needs a kernel > 2.6.32"
	exit 1
fi

if [ "$INST_ARCH" != "$SDK_ARCH" ]; then
	# Allow for installation of ix86 SDK on x86_64 host
	if [ "$INST_ARCH" != x86_64 -o "$SDK_ARCH" != ix86 ]; then
		echo "Error: Installation machine not supported!"
		exit 1
	fi
fi

if ! xz -V > /dev/null 2>&1; then
	echo "Error: xz is required for installation of this SDK, please install it first"
	exit 1
fi

DEFAULT_INSTALL_DIR="/opt/poky/2.1"
SUDO_EXEC=""
EXTRA_TAR_OPTIONS=""
target_sdk_dir=""
answer=""
relocate=1
savescripts=0
verbose=0
publish=0
while getopts ":yd:npDRS" OPT; do
	case $OPT in
	y)
		answer="Y"
		;;
	d)
		target_sdk_dir=$OPTARG
		;;
	n)
		prepare_buildsystem="no"
		;;
	p)
		prepare_buildsystem="no"
		publish=1
		;;
	D)
		verbose=1
		;;
	R)
		relocate=0
		savescripts=1
		;;
	S)
		savescripts=1
		;;
	*)
		echo "Usage: $(basename $0) [-y] [-d <dir>]"
		echo "  -y         Automatic yes to all prompts"
		echo "  -d <dir>   Install the SDK JSON to <dir>"
		echo "======== Extensible SDK only options ============"
		echo "  -n         Do not prepare the build system"
		echo "  -p         Publish mode (implies -n)"
		echo "======== Advanced DEBUGGING ONLY OPTIONS ========"
		echo "  -S         Save relocation scripts"
		echo "  -R         Do not relocate executables"
		echo "  -D         use set -x to see what is going on"
		exit 1
		;;
	esac
done

titlestr="@SDK_TITLE@ JSON installer version 2.1"
printf "%s\n" "$titlestr"
printf "%${#titlestr}s\n" | tr " " "="

if [ $verbose = 1 ] ; then
	set -x
fi


# SDK_EXTENSIBLE is exposed from the SDK_PRE_INSTALL_COMMAND above
if [ "$SDK_EXTENSIBLE" = "1" ]; then
	DEFAULT_INSTALL_DIR="~/poky_sdk"
fi

if [ "$target_sdk_dir" = "" ]; then
	if [ "$answer" = "Y" ]; then
		target_sdk_dir="$DEFAULT_INSTALL_DIR"
	else
		read -p "Enter target directory for SDK JSON (default: $DEFAULT_INSTALL_DIR): " target_sdk_dir
		[ "$target_sdk_dir" = "" ] && target_sdk_dir=$DEFAULT_INSTALL_DIR
	fi
fi

eval target_sdk_dir=$(echo "$target_sdk_dir"|sed 's/ /\\ /g')
if [ -d "$target_sdk_dir" ]; then
	target_sdk_dir=$(cd "$target_sdk_dir"; pwd)
else
	target_sdk_dir=$(readlink -m "$target_sdk_dir")
fi

# limit the length for target_sdk_dir, ensure the relocation behaviour in relocate_sdk.py has right result.
if [ ${#target_sdk_dir} -gt 2048 ]; then
	echo "Error: The target directory path is too long!!!"
	exit 1
fi

if [ "$SDK_EXTENSIBLE" = "1" ]; then
	# We're going to be running the build system, additional restrictions apply
	if echo "$target_sdk_dir" | grep -q '[+\ @$]'; then
		echo "The target directory path ($target_sdk_dir) contains illegal" \
		     "characters such as spaces, @, \$ or +. Abort!"
		exit 1
	fi
else
	if [ -n "$(echo $target_sdk_dir|grep ' ')" ]; then
		echo "The target directory path ($target_sdk_dir) contains spaces. Abort!"
		exit 1
	fi
fi

if [ -e "$target_sdk_dir/poky-glibc-x86_64-core-image-sato-armv5e-toolchain-2.1" ]; then
	echo "The directory \"$target_sdk_dir\" already contains a SDK JSON for this architecture."
	printf "If you continue, existing files will be overwritten! Proceed[y/N]? "

	default_answer="n"
else
	printf "You are about to install the SDK JSON to \"$target_sdk_dir\". Proceed[Y/n]? "

	default_answer="y"
fi

if [ "$answer" = "" ]; then
	read answer
	[ "$answer" = "" ] && answer="$default_answer"
else
	echo $answer
fi

if [ "$answer" != "Y" -a "$answer" != "y" ]; then
	echo "Installation aborted!"
	exit 1
fi

# Try to create the directory (this will not succeed if user doesn't have rights)
mkdir -p $target_sdk_dir >/dev/null 2>&1

# if don't have the right to access dir, gain by sudo 
if [ ! -x $target_sdk_dir -o ! -w $target_sdk_dir -o ! -r $target_sdk_dir ]; then 
	if [ "$SDK_EXTENSIBLE" = "1" ]; then
		echo "Unable to access \"$target_sdk_dir\", will not attempt to use" \
		     "sudo as as extensible SDK cannot be used as root."
		exit 1
	fi

	SUDO_EXEC=$(which "sudo")
	if [ -z $SUDO_EXEC ]; then
		echo "No command 'sudo' found, please install sudo first. Abort!"
		exit 1
	fi

	# test sudo could gain root right
	$SUDO_EXEC pwd >/dev/null 2>&1
	[ $? -ne 0 ] && echo "Sorry, you are not allowed to execute as root." && exit 1

	# now that we have sudo rights, create the directory
	$SUDO_EXEC mkdir -p $target_sdk_dir >/dev/null 2>&1
fi

payload_offset=$(($(grep -na -m1 "^MARKER:$" $0|cut -d':' -f1) + 1))

printf "Extracting SDK JSON..."
tail -n +$payload_offset $0| $SUDO_EXEC tar xJ -C $target_sdk_dir --checkpoint=.2500 $EXTRA_TAR_OPTIONS || exit 1
echo "done"

for json in $target_sdk_dir/.crops/*.json; do
	sed -e "s|@SDK_INSTALL_DIR@| $target_sdk_dir|" $json > $json.tmp && mv $json.tmp $json
done


echo "SDK JSON has been successfully set up and is ready to be used."

exit 0

MARKER:
�7zXZ  i"�6���P!   �F$��'��] �GxE�Dbx�K���LnP�!]��@c,g��c�|���֗Q������
�)�*Ϩ������I��kq�T��0l��L���鮁��IƝ��u���nEU��}�^V�a)Ì�8�!7�
oɋE��ա�{�X/G鼬���Uv48��R���x��폩��{��x�,��9-��WF��'���_.+v�پ[�X���:�t!�\I��x?鱓h�ʣo=�q��.HZU�n�I��.C��?Y���\a�M��w�� <��S����i��֛o���
�6�����h�VC{k3�dVdu�D"�B��	"�t晧�*��bfۮ?d�D<C�4���//,��S�&6���5%���T4�1U2��> n,9���TV��L�8|�R������G�N|m���83�t=��#��^p�!ch��$���fX�@)(�Ix<�u��aSˊ����[�+NDM^�~�6;^z���+���w"<��CA�@{+M�P@r���og��E�Js�R�� *��� ⻴5NA��L��B�����o*%���a��w�n���{��O�wWE������+_�!׀'���*�0!�/�,���	����v�:e����x�O�����r��sq����<���<E����l����Gd*Ȝ�\�e-�Y��LE�;��K�����$O#ш�	3�����>���-�E�y�Hb��mq����A�̌�6 Gkhs�z^*El�%mW�Yj\
�@xv� <����%vܵs���iAD���a�	�_2k���cM"��"���?m�i�<��?� �o�ӜI�9�z6�̽6a��� /�ŗ^c � �^=�[Z)��37�8ߨ�ǆϷC��5L��D����+%�d$  Qz�K !   t/�� k X] SB����@���N+Wg����'����a����x��>%0�LQ]�$a������Jf��a����԰U�θ�aX�/��?��&Ƞ Vf0 ��Ppl���(>0�    YZ