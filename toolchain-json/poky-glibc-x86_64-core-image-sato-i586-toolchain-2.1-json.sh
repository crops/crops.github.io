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

if [ -e "$target_sdk_dir/poky-glibc-x86_64-core-image-sato-i586-toolchain-2.1" ]; then
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
�7zXZ  i"�6���P!   n�=�'�}] �GxE�Dbx�K���LnP�!]��@c~|M�_�����N9�)v$bA��`m��ą�Z���R���c �1�H6G\�N)�!�;��ԇ�dJm�X�&��N��(�	h��
\�R��R,�&�qU���8�g3�mq�>fmU��=�m�Ι�F쒥��|��5KZ�A`F�T�M���w�IU��yΞe�:Uv��oxpub�eƟ_|��� =��bY���Q�e� l�޿��$h��+����g��n�{�?����o��B�N��c?�:xaY���=cs���Z%A��R�cs��5aPUV3�\��&�fe'R>W��b��*K�Ј�����r�9�CHi��OZ�QĒ��
A'�b�O�z��A	]ڬ�X����m��1�t�`�,�^��x�ؤ	�o�ǻ@��V��Ѽ�b�\}�61nIⶮ��t &kL/wo%��4U��͌LI��G�k��B�r�D[yj�~#�4�gF��:��3|'�|M�[�����a53��L����=A��Ek�kTL
)4\QܣrG'�M���F<�o+�
�Y�^���W��h���m�`�0&��a��/�{N)�m_3@��a��+q�kp�F��
ןe���Q8�PD�0?�k��_!����,�7�.�te�:`�^�ߠ	~���2�1�r�WF+�`#@'V��f�9G@b)k���'R-������d��֙3ώ��&���V���B���9b��F��nF�W�v����Z	���F���-�Мv>/>zE�<�u��歋F
::�x$��%����܀;�S��"�ģx(mҴ�6X'�k�8Dt�j3m�0�S���I���
;Z�-�H�ۂ;{ķ�&�?�    /��� !   t/�� i V] SB����@���N+Wg����'����a����x��>%0�LQ]�$a��������:ig�;ع';���ӟ��U �#�!��a    ���' ��Pnj?�>0�    YZ