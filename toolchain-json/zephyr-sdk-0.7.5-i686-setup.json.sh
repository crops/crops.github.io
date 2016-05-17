#!/bin/sh
# This script was generated using Makeself 2.2.0

umask 077

CRCsum="646607089"
MD5="5304d9a721c71078f96047ea153f1fff"
TMPROOT=${TMPDIR:=/tmp}

label="SDK json descriptors for Zephyr"
script="./setup.sh"
scriptargs=""
licensetxt=""
targetdir=".crops"
filesizes="2965"
keep="n"
quiet="n"

print_cmd_arg=""
if type printf > /dev/null; then
    print_cmd="printf"
elif test -x /usr/ucb/echo; then
    print_cmd="/usr/ucb/echo"
else
    print_cmd="echo"
fi

unset CDPATH

MS_Printf()
{
    $print_cmd $print_cmd_arg "$1"
}

MS_PrintLicense()
{
  if test x"$licensetxt" != x; then
    echo $licensetxt
    while true
    do
      MS_Printf "Please type y to accept, n otherwise: "
      read yn
      if test x"$yn" = xn; then
        keep=n
 	eval $finish; exit 1        
        break;    
      elif test x"$yn" = xy; then
        break;
      fi
    done
  fi
}

MS_diskspace()
{
	(
	if test -d /usr/xpg4/bin; then
		PATH=/usr/xpg4/bin:$PATH
	fi
	df -kP "$1" | tail -1 | awk '{ if ($4 ~ /%/) {print $3} else {print $4} }'
	)
}

MS_dd()
{
    blocks=`expr $3 / 1024`
    bytes=`expr $3 % 1024`
    dd if="$1" ibs=$2 skip=1 obs=1024 conv=sync 2> /dev/null | \
    { test $blocks -gt 0 && dd ibs=1024 obs=1024 count=$blocks ; \
      test $bytes  -gt 0 && dd ibs=1 obs=1024 count=$bytes ; } 2> /dev/null
}

MS_dd_Progress()
{
    if test "$noprogress" = "y"; then
        MS_dd $@
        return $?
    fi
    file="$1"
    offset=$2
    length=$3
    pos=0
    bsize=4194304
    while test $bsize -gt $length; do
        bsize=`expr $bsize / 4`
    done
    blocks=`expr $length / $bsize`
    bytes=`expr $length % $bsize`
    (
        dd bs=$offset count=0 skip=1 2>/dev/null
        pos=`expr $pos \+ $bsize`
        MS_Printf "     0%% " 1>&2
        if test $blocks -gt 0; then
            while test $pos -le $length; do
                dd bs=$bsize count=1 2>/dev/null
                pcent=`expr $length / 100`
                pcent=`expr $pos / $pcent`
                if test $pcent -lt 100; then
                    MS_Printf "\b\b\b\b\b\b\b" 1>&2
                    if test $pcent -lt 10; then
                        MS_Printf "    $pcent%% " 1>&2
                    else
                        MS_Printf "   $pcent%% " 1>&2
                    fi
                fi
                pos=`expr $pos \+ $bsize`
            done
        fi
        if test $bytes -gt 0; then
            dd bs=$bytes count=1 2>/dev/null
        fi
        MS_Printf "\b\b\b\b\b\b\b" 1>&2
        MS_Printf " 100%%  " 1>&2
    ) < "$file"
}

MS_Help()
{
    cat << EOH >&2
Makeself version 2.2.0
 1) Getting help or info about $0 :
  $0 --help   Print this message
  $0 --info   Print embedded info : title, default target directory, embedded script ...
  $0 --lsm    Print embedded lsm entry (or no LSM)
  $0 --list   Print the list of files in the archive
  $0 --check  Checks integrity of the archive
 
 2) Running $0 :
  $0 [options] [--] [additional arguments to embedded script]
  with following options (in that order)
  --confirm             Ask before running embedded script
  --quiet		Do not print anything except error messages
  --noexec              Do not run embedded script
  --keep                Do not erase target directory after running
			the embedded script
  --noprogress          Do not show the progress during the decompression
  --nox11               Do not spawn an xterm
  --nochown             Do not give the extracted files to the current user
  --target dir          Extract directly to a target directory
                        directory path can be either absolute or relative
  --tar arg1 [arg2 ...] Access the contents of the archive through the tar command
  --                    Following arguments will be passed to the embedded script
EOH
}

MS_Check()
{
    OLD_PATH="$PATH"
    PATH=${GUESS_MD5_PATH:-"$OLD_PATH:/bin:/usr/bin:/sbin:/usr/local/ssl/bin:/usr/local/bin:/opt/openssl/bin"}
	MD5_ARG=""
    MD5_PATH=`exec <&- 2>&-; which md5sum || type md5sum`
    test -x "$MD5_PATH" || MD5_PATH=`exec <&- 2>&-; which md5 || type md5`
	test -x "$MD5_PATH" || MD5_PATH=`exec <&- 2>&-; which digest || type digest`
    PATH="$OLD_PATH"

    if test "$quiet" = "n";then
    	MS_Printf "Verifying archive integrity..."
    fi
    offset=`head -n 498 "$1" | wc -c | tr -d " "`
    verb=$2
    i=1
    for s in $filesizes
    do
		crc=`echo $CRCsum | cut -d" " -f$i`
		if test -x "$MD5_PATH"; then
			if test `basename $MD5_PATH` = digest; then
				MD5_ARG="-a md5"
			fi
			md5=`echo $MD5 | cut -d" " -f$i`
			if test $md5 = "00000000000000000000000000000000"; then
				test x$verb = xy && echo " $1 does not contain an embedded MD5 checksum." >&2
			else
				md5sum=`MS_dd "$1" $offset $s | eval "$MD5_PATH $MD5_ARG" | cut -b-32`;
				if test "$md5sum" != "$md5"; then
					echo "Error in MD5 checksums: $md5sum is different from $md5" >&2
					exit 2
				else
					test x$verb = xy && MS_Printf " MD5 checksums are OK." >&2
				fi
				crc="0000000000"; verb=n
			fi
		fi
		if test $crc = "0000000000"; then
			test x$verb = xy && echo " $1 does not contain a CRC checksum." >&2
		else
			sum1=`MS_dd "$1" $offset $s | CMD_ENV=xpg4 cksum | awk '{print $1}'`
			if test "$sum1" = "$crc"; then
				test x$verb = xy && MS_Printf " CRC checksums are OK." >&2
			else
				echo "Error in checksums: $sum1 is different from $crc" >&2
				exit 2;
			fi
		fi
		i=`expr $i + 1`
		offset=`expr $offset + $s`
    done
    if test "$quiet" = "n";then
    	echo " All good."
    fi
}

UnTAR()
{
    if test "$quiet" = "n"; then
    	tar $1vf - 2>&1 || { echo Extraction failed. > /dev/tty; kill -15 $$; }
    else

    	tar $1f - 2>&1 || { echo Extraction failed. > /dev/tty; kill -15 $$; }
    fi
}

finish=true
xterm_loop=
noprogress=n
nox11=n
copy=none
ownership=y
verbose=n

initargs="$@"

while true
do
    case "$1" in
    -h | --help)
	MS_Help
	exit 0
	;;
    -q | --quiet)
	quiet=y
	noprogress=y
	shift
	;;
    --info)
	echo Identification: "$label"
	echo Target directory: "$targetdir"
	echo Uncompressed size: 32 KB
	echo Compression: gzip
	echo Date of packaging: Tue May 17 14:45:10 PDT 2016
	echo Built with Makeself version 2.2.0 on linux-gnu
	echo Build command was: "/usr/bin/makeself \\
    \"toolchains/.crops/\" \\
    \"zephyr-sdk-0.7.5-i686-setup.json.sh\" \\
    \"SDK json descriptors for Zephyr\" \\
    \"./setup.sh\""
	if test x$script != x; then
	    echo Script run after extraction:
	    echo "    " $script $scriptargs
	fi
	if test x"" = xcopy; then
		echo "Archive will copy itself to a temporary location"
	fi
	if test x"n" = xy; then
	    echo "directory $targetdir is permanent"
	else
	    echo "$targetdir will be removed after extraction"
	fi
	exit 0
	;;
    --dumpconf)
	echo LABEL=\"$label\"
	echo SCRIPT=\"$script\"
	echo SCRIPTARGS=\"$scriptargs\"
	echo archdirname=\".crops\"
	echo KEEP=n
	echo COMPRESS=gzip
	echo filesizes=\"$filesizes\"
	echo CRCsum=\"$CRCsum\"
	echo MD5sum=\"$MD5\"
	echo OLDUSIZE=32
	echo OLDSKIP=499
	exit 0
	;;
    --lsm)
cat << EOLSM
No LSM.
EOLSM
	exit 0
	;;
    --list)
	echo Target directory: $targetdir
	offset=`head -n 498 "$0" | wc -c | tr -d " "`
	for s in $filesizes
	do
	    MS_dd "$0" $offset $s | eval "gzip -cd" | UnTAR t
	    offset=`expr $offset + $s`
	done
	exit 0
	;;
	--tar)
	offset=`head -n 498 "$0" | wc -c | tr -d " "`
	arg1="$2"
    if ! shift 2; then MS_Help; exit 1; fi
	for s in $filesizes
	do
	    MS_dd "$0" $offset $s | eval "gzip -cd" | tar "$arg1" - $*
	    offset=`expr $offset + $s`
	done
	exit 0
	;;
    --check)
	MS_Check "$0" y
	exit 0
	;;
    --confirm)
	verbose=y
	shift
	;;
	--noexec)
	script=""
	shift
	;;
    --keep)
	keep=y
	shift
	;;
    --target)
	keep=y
	targetdir=${2:-.}
    if ! shift 2; then MS_Help; exit 1; fi
	;;
    --noprogress)
	noprogress=y
	shift
	;;
    --nox11)
	nox11=y
	shift
	;;
    --nochown)
	ownership=n
	shift
	;;
    --xwin)
	finish="echo Press Return to close this window...; read junk"
	xterm_loop=1
	shift
	;;
    --phase2)
	copy=phase2
	shift
	;;
    --)
	shift
	break ;;
    -*)
	echo Unrecognized flag : "$1" >&2
	MS_Help
	exit 1
	;;
    *)
	break ;;
    esac
done

if test "$quiet" = "y" -a "$verbose" = "y";then
	echo Cannot be verbose and quiet at the same time. >&2
	exit 1
fi

MS_PrintLicense

case "$copy" in
copy)
    tmpdir=$TMPROOT/makeself.$RANDOM.`date +"%y%m%d%H%M%S"`.$$
    mkdir "$tmpdir" || {
	echo "Could not create temporary directory $tmpdir" >&2
	exit 1
    }
    SCRIPT_COPY="$tmpdir/makeself"
    echo "Copying to a temporary location..." >&2
    cp "$0" "$SCRIPT_COPY"
    chmod +x "$SCRIPT_COPY"
    cd "$TMPROOT"
    exec "$SCRIPT_COPY" --phase2 -- $initargs
    ;;
phase2)
    finish="$finish ; rm -rf `dirname $0`"
    ;;
esac

if test "$nox11" = "n"; then
    if tty -s; then                 # Do we have a terminal?
	:
    else
        if test x"$DISPLAY" != x -a x"$xterm_loop" = x; then  # No, but do we have X?
            if xset q > /dev/null 2>&1; then # Check for valid DISPLAY variable
                GUESS_XTERMS="xterm rxvt dtterm eterm Eterm kvt konsole aterm"
                for a in $GUESS_XTERMS; do
                    if type $a >/dev/null 2>&1; then
                        XTERM=$a
                        break
                    fi
                done
                chmod a+x $0 || echo Please add execution rights on $0
                if test `echo "$0" | cut -c1` = "/"; then # Spawn a terminal!
                    exec $XTERM -title "$label" -e "$0" --xwin "$initargs"
                else
                    exec $XTERM -title "$label" -e "./$0" --xwin "$initargs"
                fi
            fi
        fi
    fi
fi

if test "$targetdir" = "."; then
    tmpdir="."
else
    if test "$keep" = y; then
	if test "$quiet" = "n";then
	    echo "Creating directory $targetdir" >&2
	fi
	tmpdir="$targetdir"
	dashp="-p"
    else
	tmpdir="$TMPROOT/selfgz$$$RANDOM"
	dashp=""
    fi
    mkdir $dashp $tmpdir || {
	echo 'Cannot create target directory' $tmpdir >&2
	echo 'You should try option --target dir' >&2
	eval $finish
	exit 1
    }
fi

location="`pwd`"
if test x$SETUP_NOCHECK != x1; then
    MS_Check "$0"
fi
offset=`head -n 498 "$0" | wc -c | tr -d " "`

if test x"$verbose" = xy; then
	MS_Printf "About to extract 32 KB in $tmpdir ... Proceed ? [Y/n] "
	read yn
	if test x"$yn" = xn; then
		eval $finish; exit 1
	fi
fi

if test "$quiet" = "n";then
	MS_Printf "Uncompressing $label"
fi
res=3
if test "$keep" = n; then
    trap 'echo Signal caught, cleaning up >&2; cd $TMPROOT; /bin/rm -rf $tmpdir; eval $finish; exit 15' 1 2 3 15
fi

leftspace=`MS_diskspace $tmpdir`
if test -n "$leftspace"; then
    if test "$leftspace" -lt 32; then
        echo
        echo "Not enough space left in "`dirname $tmpdir`" ($leftspace KB) to decompress $0 (32 KB)" >&2
        if test "$keep" = n; then
            echo "Consider setting TMPDIR to a directory with more free space."
        fi
        eval $finish; exit 1
    fi
fi

for s in $filesizes
do
    if MS_dd_Progress "$0" $offset $s | eval "gzip -cd" | ( cd "$tmpdir"; UnTAR x ) 1>/dev/null; then
		if test x"$ownership" = xy; then
			(PATH=/usr/xpg4/bin:$PATH; cd "$tmpdir"; chown -R `id -u` .;  chgrp -R `id -g` .)
		fi
    else
		echo >&2
		echo "Unable to decompress $0" >&2
		eval $finish; exit 1
    fi
    offset=`expr $offset + $s`
done
if test "$quiet" = "n";then
	echo
fi

cd "$tmpdir"
res=0
if test x"$script" != x; then
    if test x"$verbose" = xy; then
		MS_Printf "OK to execute: $script $scriptargs $* ? [Y/n] "
		read yn
		if test x"$yn" = x -o x"$yn" = xy -o x"$yn" = xY; then
			eval $script $scriptargs $*; res=$?;
		fi
    else
		eval $script $scriptargs $*; res=$?
    fi
    if test $res -ne 0; then
		test x"$verbose" = xy && echo "The program '$script' returned an error code ($res)" >&2
    fi
fi
if test "$keep" = n; then
    cd $TMPROOT
    /bin/rm -rf $tmpdir
fi
eval $finish; exit $res
‹ æ;WíkSÛ:–¯øWœš´!Ü:/BÒ)¥náîe—B§Àl»¥“ql…ø[^Ë†f)ÿ}äGlÇ<ÒâôÒÑébY:ïst¤ÕK¥C¡×Ûà¿[½fúwK­v¯ÕíµšëîR³ÕÚhµ—`ci0_÷ –|ŸzcË9»©ß]ï)Ô>¥cc¤[¦{†æÒó‰FÆÃú_Œ:hÿn§s“ı×{íNbÿv¯‡öïv»ëKĞ”ö/®Ôâ˜ÔS_‚*ŒÏÌsõ9¨eò¦ÿw4ñ4lÔºGlâëcÍê¾èjü£–ñ>Ìğ(c}ƒÚ®5&AÚ§4ŞcD™/®ø›ïÁ±ñlÂ<Jù;•?öûşÄ%ı>ş“Á6ÊøZ!øª^ã3'Ï›>_©HÒÖs†ä™!øâ=ûºw&züšÜjP×oLm´ëÍz«½e4:õK³cÄ›R×Û·üÁÑm!;§lŞÂÜo¿-’¹3Ü!ñÛ¹3ĞvÉàû÷s©OgÌİAcû(M1ÜJal.Püı4kHúvë˜ƒŞî ğß3úE·’`¾g¹ó9:ş°—1cˆåVBîŒ­¹Åù°}°¿—‘(Âs+-:øË îd^b‡¿ÿóíáûOij1¦»È™í~¹“wïsä¦ÛCÂ›—Òö‡L@x·ãwìyñ¼KãÇñyüvg^”ï:i”8şúKêù?"á5|
ÇñG;ÿtÉN@ÑÔ•šæ	ê<«!şd²â]®ÄL	²æyßr°û¦%æáÊ2Ûß;8:ŞŞßïïì}¸æ/ˆÇ,êğ‚ŞfZ]4;Q«×óÕŒø[g£²ëÿŞõ_«Õìtrõÿz»%ë¿…ÀÊ“ÆÀr”İ?¶OöÓ73¿Õ±Âs™r|x¸ÿöÏí½ƒşÁö»İ-E	ãªÏ½½xKU‹¶Ä³1ÑÀİj)u†–go5%`úÕ\) †îÃ«W°{ø>œˆ7/¡’¥¯@Ó 9Â8`ğZQ”ÃğóK£ğG;sÇúü‘Å`DÆ.`®òÕòë
ïiÂ+dòuÒÿÈ%†5äı	èFÇOÀÕıĞ¡hÄx„HN0¿x“á$AµøÔÆ>LÌ@®‡Å°Ï6Ag,°	¨Ø®â²Ä.‰Ç» Ö¸¢ã¸Vwd©OY¨ Cg8¶²ğ4«©È§;ºwi9µbŒ(Tà# èõ®K=Ÿ˜OªQT´ÂÏ››Å
ìóšú¹•:ãÉt‰.¢CDd%¤"šª9D‡ˆÂÃAP¯×ÃFŒ|ße/âÔ/­sË%¦¥×©wÖàO.ÓÊîWİvÇ„…£v¨Sõ¹fè%WQ¤|dõ6‰Ìb?-l9Æ80QİÆäUñşmá’æ’=QÑ±îa7âÂZ°–QÖ‰“¶XI„é7Êå—5ğÑRáÉ®TàË&˜TYö©´¸Q–ù m5eyyYø8ÿ 06ù'Ä·¼Œ>(Ş³‘5ôù‡\ UZÓ®Â'RXÍÍiÿIØ/4u¢N_®…ï„èê®çQï%ì9úØ29@u|8EùN1„gøO˜
‰˜7©C…¹–ãoµ¦\)ËcjèèÓ–)äŸL‚!¹…Wo#nâcpÛª~kh§Õ¸Õr†Ô'_ı­J[Y5~n¡íµ&T%´_7LrÑpl•ô‰ínU®"¬+o®ñëY?>?5¾ÀS=µuàcZj‚$æ©Â±%ÈªâYå(Ù˜*B…ÓÁôG7¤X(TVù/´ rµ“»®EŒ§Fó1B•ÑÏ)çk1ã)n“·S’èŸ&"´ƒ5Dg­9 ó¶„÷b E>k˜PÉºaØ¾âÙÀ,ŸhÂ£ÎÖ¦­Ä¹°<êp§ÑDï†çd>İ	ÅrÜÀÇ¼§*6õ#·Œó~è‰ÇØ=Œù8ÃN“k¸ä~0 à›^`J1!ÕJ„7ŒËÉT4˜ÆººCaB¸ÔÑÉ1«à$à4i8µ7‡Ğé8·aæ‚2ôÜ'4šk›´9h¯˜íq€ŒÃ³g0@êç©®!ÿq¤†*=M†b1ˆ¹“ç ğUuRô¿ªS}™H%Ü
1I)?†K&E‰4šU¾`/å1B=ÎE.&ÇçS™èŸ2>uò½DX5ÉPÆ>Îê…Fù„¼óİÌWQ>c`UP4…\ğÜëœ#%Dş<ãoèJ5ø’È<uÖYE¹°šCPëKî±º“­,ê°=À9ç	†r˜Y7oæu5$›WÅ7†3V•5 qz
³j-´Î,³ZK$˜Ámtß÷Ò¬)ÂSfGpÃc%|š=;´&ÄqxÁ"xÏõúvæa­Bµ–âl~İòğÅUÃœ­„Í¨4Ôh8"ûñì’8¤?Ã—ª$*Ì{BÂæ
ì…5á”=‘¸#mÍ}şÒ³¸™‰g[Œ¯Ù¢Dü´ËYÄc4p@S#“°ö‡U˜´Ê§Šx>„l]bY•cSãÅE:ï†É;Ÿ3oÈWŸRöã0okŞ0/Dc32"¦†ĞQöŸ–ÍÑëPÎÄ™ÂZ„Åª÷Ë´%ÿR	1¼E¹nŸ0Tn¯clçÉ÷ÎkhUbZ	‹eÃ U¨€aF3)a¼éhëlä³š0f\¢§`4{3†MU)í×ÏZ·ó§Å˜š˜ğ»Ì*‰nuvOövxÎjB­Sl®³ÛÊŠ ´’4µÛb¬b¸<‰§¿	²6^t³_ÍŠSùÅÕTdbíë‹.ˆMzai\¨
&Ù7˜2)²xª]e5¬(ğÙ­`G’öº*Æ„Â‡CÕşuÏ¾ØˆĞÖH€˜~’Æ÷ Ç¿ñSø·tÛ	ÄÓˆ!üAlËeëm¯ı ÖàÈ EjO€Q¶‰Ç¦'ÂútJÄ\Èç
‘/±hÁh"‡K~Y¸OÌ–üı§ÕmO÷Û½¥f§¦Üÿ}Lßÿo)<©%B[Ì9€Â…§0Å‹ÙE³×Ûs}¹[/?~@ ˆë¢cåúî“ÅÊ.<?°PÎï>RPÀy)
èüğñ‚ïĞÈ§Š,YÊYƒBe8( Wò¹ƒŠåŸ>(&Zò„¢zø“T~ÅóÉTzÿ	Eyàîƒ	a¿¿óé	‹¬ÿ‹—º¥Ÿÿí´›­éùßu~ş£×é¶dıÿ˜êÿØw
— üå¢OgişX’şĞÖÖz?ŒtÏÔ†cªû¼9ÛJ‹uïªl&~|U“¦hAğ÷‘æîÕÂŒq

‰î^Ed%*e‘%ñÃk‡¹µpçÊ!gÕRYe®²”J^*d‰•¿J˜¡Wò!¿6Èø—\ÂùV³şÈ+K(wÿæ[ß…üı_§¹¾‘Ôÿ­èïÿšrÿÿqíÿo„õûíÛÿ?cçÿÆÚ_””¢ŠŒ™¿ÿ¾kšÀïùßXİ/Œß9wûo«ßÆóœûü…:<ìa‰åé`¾ıElê/n?¡[ù‹ŞÅ_ô~é{÷¿æ¶ıÆÌ,6WtËÚ\ÂÏ¾ÿcöÔäBîÿè®Oëÿõu¾ÿßîÉúÿ‘İÿ¾sÃ öÔ§vHšæCÜ’‰Œ‡¸$ÃàÜ2ƒ÷¹
$§Â‡¸d>&ïsHšÉ’îI“x€AæÒÁ=îÉ˜©¤KAÒ4Ê½$M©ôkAÒÄq/H^éƒd‚£Œ›AÒ~Í«Aìy¯É†÷]E=ï#«z	$H A‚	$H A‚	$H A‚	$H A‚	$H AÂ\ğ=‡ÿ x  