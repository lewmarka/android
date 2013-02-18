#!/bin/sh
# This script was generated using Makeself 2.1.5

CRCsum="1980728973"
MD5="f14eef810743807277e7fb1f6f3bb16b"
TMPROOT=${TMPDIR:=/tmp}

label="Test Isntaller"
script="./setup.sh"
scriptargs=""
targetdir="contentdir"
filesizes="7348"
keep=n

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

MS_Progress()
{
    while read a; do
	MS_Printf .
    done
}

MS_diskspace()
{
	(
	if test -d /usr/xpg4/bin; then
		PATH=/usr/xpg4/bin:$PATH
	fi
	df -kP "$1" | tail -1 | awk '{print $4}'
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

MS_Help()
{
    cat << EOH >&2
Makeself version 2.1.5
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
  --noexec              Do not run embedded script
  --keep                Do not erase target directory after running
			the embedded script
  --nox11               Do not spawn an xterm
  --nochown             Do not give the extracted files to the current user
  --target NewDirectory Extract in NewDirectory
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

    MS_Printf "Verifying archive integrity..."
    offset=`head -n 401 "$1" | wc -c | tr -d " "`
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
				echo "Error in checksums: $sum1 is different from $crc"
				exit 2;
			fi
		fi
		i=`expr $i + 1`
		offset=`expr $offset + $s`
    done
    echo " All good."
}

UnTAR()
{
    tar $1vf - 2>&1 || { echo Extraction failed. > /dev/tty; kill -15 $$; }
}

finish=true
xterm_loop=
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
    --info)
	echo Identification: "$label"
	echo Target directory: "$targetdir"
	echo Uncompressed size: 20 KB
	echo Compression: gzip
	echo Date of packaging: Mon Feb 18 16:26:25 CST 2013
	echo Built with Makeself version 2.1.5 on 
	echo Build command was: "./makeself-2.1.5/makeself.sh \\
    \"contentdir\" \\
    \"testinstaller.sh\" \\
    \"Test Isntaller\" \\
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
	echo archdirname=\"contentdir\"
	echo KEEP=n
	echo COMPRESS=gzip
	echo filesizes=\"$filesizes\"
	echo CRCsum=\"$CRCsum\"
	echo MD5sum=\"$MD5\"
	echo OLDUSIZE=20
	echo OLDSKIP=402
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
	offset=`head -n 401 "$0" | wc -c | tr -d " "`
	for s in $filesizes
	do
	    MS_dd "$0" $offset $s | eval "gzip -cd" | UnTAR t
	    offset=`expr $offset + $s`
	done
	exit 0
	;;
	--tar)
	offset=`head -n 401 "$0" | wc -c | tr -d " "`
	arg1="$2"
	shift 2
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
	shift 2
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
	echo "Creating directory $targetdir" >&2
	tmpdir="$targetdir"
	dashp="-p"
    else
	tmpdir="$TMPROOT/selfgz$$$RANDOM"
	dashp=""
    fi
    mkdir $dashp $tmpdir || {
	echo 'Cannot create target directory' $tmpdir >&2
	echo 'You should try option --target OtherDirectory' >&2
	eval $finish
	exit 1
    }
fi

location="`pwd`"
if test x$SETUP_NOCHECK != x1; then
    MS_Check "$0"
fi
offset=`head -n 401 "$0" | wc -c | tr -d " "`

if test x"$verbose" = xy; then
	MS_Printf "About to extract 20 KB in $tmpdir ... Proceed ? [Y/n] "
	read yn
	if test x"$yn" = xn; then
		eval $finish; exit 1
	fi
fi

MS_Printf "Uncompressing $label"
res=3
if test "$keep" = n; then
    trap 'echo Signal caught, cleaning up >&2; cd $TMPROOT; /bin/rm -rf $tmpdir; eval $finish; exit 15' 1 2 3 15
fi

leftspace=`MS_diskspace $tmpdir`
if test $leftspace -lt 20; then
    echo
    echo "Not enough space left in "`dirname $tmpdir`" ($leftspace KB) to decompress $0 (20 KB)" >&2
    if test "$keep" = n; then
        echo "Consider setting TMPDIR to a directory with more free space."
   fi
    eval $finish; exit 1
fi

for s in $filesizes
do
    if MS_dd "$0" $offset $s | eval "gzip -cd" | ( cd "$tmpdir"; UnTAR x ) | MS_Progress; then
		if test x"$ownership" = xy; then
			(PATH=/usr/xpg4/bin:$PATH; cd "$tmpdir"; chown -R `id -u` .;  chgrp -R `id -g` .)
		fi
    else
		echo
		echo "Unable to decompress $0" >&2
		eval $finish; exit 1
    fi
    offset=`expr $offset + $s`
done
echo

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
‹ ‘ª"Qí™wX“Í¶èC‡Ğ¥WC“Nè¤ƒTĞA	  	„Ş{‘"HSAé½wA‘"½ˆJSºtTÚÁ¯íoŸoï»Ï?ûì{ï“_'óÎ¼3kÊšYkæ!0àßğ%RR?C)	á?‡¿–—ÿ|’ €$ ÿxº{ÀĞ Àæ‚@Ãşy¾õşÿQ„À?ûïáé*äîôoÔ¿¤¤ø?Ó¿ˆ¤°@XTTRLBJBDü2]DTJòRÿÂıÿÛá`Û `˜»#¨ld` ª•³võ¶³UT¡rìœz:ªìÀ›ºw~³p[Gˆó·Ü¿F@oGÄ]8Èí	—Ù¡€ KĞp˜HĞÄ®‚ù¢<AŞwG
„@^úİ» G„;Èr@Ã\n°ƒ|‘¿”²…¹ÃAœ¾ÈËl¿ÄbaækÅâı‘ğ;¿4…ıÖ¯2.+¸”jÿ½¸İåˆóg»Á0¤…°±ÿ3wá?ë…#=àèË†ÁA®0G=
ı»0™¿–ü¥¿Ì_^şãz8ÿÇÙö àeƒ/Â²úK¦Ë†"ÿ’xÉ/ªú§uÁï^öôûu(Th¸­
í{©G¸;‰ò Á}îBì-dø×=ùmıYìÿÃáb‡şÔÄ¿Ôî?Ğê_Ú\ªËYVöosJùËœºì›ÇŸ’Iúó”€!İ½/ç„ïåP\Î$Jˆı·Üpw˜-Ğ…„.Îvô¯m=‘~WŸĞÏÿKş–Šv	ş–|ç¢²¡)úÛ[”‹Ë¥V‚ş½şÿÿ`ÿÿÎÿ‹Jˆı´ÿ¢âRûÿ¿äÿá¿zÿÿØşODBBòoúıUÿ¢ÿñÿÿñÿÿßøÿK_ü¿Ñş+¢m^ğŸ­ıø	‘Ëóßö_Xâ§ı—ÅØÿÿniáàR_†„€å˜ …[ŞGö8  '  P TUtT…<|<ŒLI †~ìúqqîz‡XÔ€h'rBÑ~Âï:O›»]‹ã&1İ=«Ş6“Æ9ûéËß¾zG¥>)èË­!ÏØÿ<œ9³xGNi£TJb’"‘P–&?ñÂ³Ç6\:%ÚÊá®Ë{¬ÔòNï7ıû3İ<«iRô`ÿI( 1~üVLN)¢òŸh@y@j£ÃømJİ2ë°ÇwsÄôÅ.ëˆòA&ø¯ ¦A¥ËŞ¬ĞIZ¶|ªê‘-Fª1i7kísş/1x‰'7Ûöè Wä»r‰ŞÍƒrX–ì3â*“yõ1‚p=î¥-ƒ4DVıv%o2$İ`‘¾¦0¥’Ö¿ÃS çñ©á'ÿ›‘œ’rDÛ.}F–Oê>P¶X¿şšEaµbÃ,Å1t›^“é˜ş6š§œ+7s»ï|ºÂ¤P=Ó<§ˆ¥,ñX{¹ığ†”÷~ÿQ%_Lîı{ZiB±¼ÛrÚkœíÆdN’÷îÖqm#óÂŸ=²9iWÄÓŒ ºjOƒÔo[­ò$FÙˆ“EÆc£‘·ùµ9õšÔŞŞ«„ç½ööXM¼bÈ™l¦oÔÏ0~/—I¡–ı,/iÍ¥¸rÔÔõ**Ëu'Ìâ!ƒSÊF.y3H<;X	o¶Û^V´¶†n3J8¼æ•6³íŸ‚µê¥¤md5
¼É9-µ¨‘Î‚°Bn•ÕWfßëÔÃ[õ²ú+ŠxõIIJ¬µƒ#Úß}µMÓ&>cşó‘Í5¹Z¸l6	¸mù\Ï»#—×¶‘í‡®ú}êmq2sFªkNdºß¬¬Øîhï’Ñ!è¢Å¦pCàùñ:¨B'Öd¿Š æ8&thçi…±ƒ-)g%ˆÃFyªoô²~«DÓõë‹½cµ_ÛB²Ÿ|Ô`L·™p·uW2‹3@|Ó:U.²,ÈÒ»vue’şê^#}–(—®O}ir!èÙ¢™åç~y-ÂçÖÓ©
fdøÎ*×œ™u÷·akòW_D/›³É"7<Ì]üõtZf×7ÖİÌä–O${%/w\úk™‰‚ï<xçYòN?AHŒ Ñ>]o];AN¼˜
]ŒõxHYˆdøG&Ş÷CğĞ'˜ÎÆp±İG.áàĞÁÅØsB&Í[Ù9§û²¿f[œB›€‡L  éåš5t…¹h£ĞvBN0/ØÏeó·eÛhæbn¦¼¸“Ö½¶ş.m…šÇÚ,Ê‰Ñ¿EDÛ'ìóü½ììóå¨å,‰ƒyY± ã†äÑnÊ+Ù÷Ÿ0¼Y’"7èíİ<İ[şşqºùÆÓšÁ,oTcé±İ”óÒ4Á‹…•OvŒµWšW:×ÎºÏ7å¡øeëOÒDd›wÍ)ÎpüÚ -SÇ^jVÇ?`3±F‚Í’½ò[["^€‹œ£«r5æb…,†JãCˆÉ5sI‹‰ÉÊBs‘ÒGÄ^UiKiû£šoÓ%cèÊÛYÌ·#¸~p5»6A$YÔ/„Aci¸aóÍGì-6‹Õ,Ç¢+q•›©£°8ÃpBôª Ü©ü'oj%z©â)n+³8<U`=éwêqXäúpOïŠ”*¿Üˆ
ê•ß°,—¨„vBÖTz‘
AùFÜ0äñi|×ª,¡ÖİÇiİßÃˆj(âMcğ›VénNG5‡÷E„†„6É„Ì“ê
«é¬•ì¶Å%÷à°WR<î5¼ÜÁ\…ŠíÌ‡rn˜5SœÙİ³„27Sf‡s®…'B6ƒèÂ
®L¢ë¹`i’ø_#_g 8+>TDÚ„G
ÛºZ(ú…°]ï0–Áscyõ’Ö%A8Aâ¯k¹î‡üVG~µ]®×7äÇ!àöZ³Š†auÈ4ßcËœÏq`É/$Ùd¶fZ|”Şæ‘]à¡úË.‰Ö×³è¼’]0Líê'(¦4£AÍ	–OZVª„P,;•£@æ4Ía¤r*ô "#ÕBÖÒ{ºîKÕ÷OüGróİ£Ö¯5[¤=¢(‘ÂNĞs¬t~a·?+èLÊ)åİSŸÅ):&X|…ê›ÖñVš˜²;—»R·ÚSÀ­ßG™µ3å‹M1–@Ê7¼y¤p
háêf=øèi¯à©Úà_Ä<ïâK³ÂÂ¼ŒFù)	Ù‰•Á”ğ5Ï>İó ?mÚvàÒ¨öÎNK¬šå»´İuz¢Å_¬²j™¿‹&ª|é·÷`Ş;[‹—c*¼.šÜçûği¼äwÃşÖS´GyAà§‚švM²¢{Wkf|¶¬Çƒg®…òvqÎÍ!äs‚üÜ>¸ç/Õïö&÷øm?~Agá ‚øØ”ì´UåZ„âÉĞ–]ÅQoäHğÜİ0{bR¬´Ñ·¼ó‘yûåÑÕ©©Â’h¼i­³¬ÈôÀİCÕÉ¶-sr–„¥ŠÈgÏˆ„"â3áûØ‡8‹na¬W4%%s#Ó9ÚúL‰r‘‚½2çúÂ²
¡¬ËxŠ6(•$ò
Òj\ş3ÒÄ®FzìÏß*°>5SŞ(…ˆ3ƒÕeèÁ³´´f‚µr°ùˆõ{É¨h8w®j˜ĞénŸ)Ñ„„(›:IQ ÉËÚ÷Ş‹ˆ'ç?ü$µİÓí†j?¢èÖ½Ç”^Ô®BIÅ¸£ôíÓˆ¿Ei€ô÷¬çÀL÷/ˆ0Vl·%æ†BëÄŒ< äúpH2
†¥»Ç”dáä87İ·×¶aÛU·¯IÓ÷ıpaPµSâÇî› oğLÔo5JànÜÔ#9·5iAÊ =±7Ğ¡®boÛÍA^va–wl'ÒîADÒÆ`†Îy]šİ ó§‡”¦Ş»Ã.\§Úi¾úJ=|ŞDa7n+Şæ–™˜ì²3‹µXëxß†§¡¾¢[j¿I²ÊvsŸÍjà®]Îa*ù û‹ôÜÜ“8–}2ÇT.^Åœ8ÄPrsª@åÜ;¢Å`¸ÏCµ¦ŞäeçÇIìzgVı!·z†l‡‰ó
âó´*L[lÜé—óÁºvêµˆ8ŠÜ¸õÇ©>tQ{+•Á˜_×1ÛÔ—²<EÒè×î4Î¼ÍIãøZŞ$¸ç”Œğ¥ÖT_ÀF%²#Yİ)=³	üKüÑ-fÌsÍ$å]äŒ±õLM£ P!+[ÊfÛúİ÷lë^İ¦Á†ãS¸¾”6<LNïüXm=ö¿(Ÿgâdhdİ/Õó;?%»~ü®§ıFÌ–BXjá–¡ìNvVpvßù~½·úïùì—ƒßŞõÌ¬W>Í»¶¾.Ür±j<Èğ¢P£$¡A„ÂÁ*uµzíTö*¯~ö“>Öôˆ	5^ê!3—Æó˜w+o>–DgùbÏ½¿li)ø©Ï­7V\?B • uo{\ÃÓè#.QH¿Ş‚;j®¯Úg¯gÆÅh
r&fE­!Ö½}Şw¾WOëœw4·+ººGHNk%Inlç‰Ïéf?áyÙªm¤òê¹ŠÉóN¬7b®[[iºÈ¤†Ğ"ºY˜9WhVk5¤r|Bm±GÕE¥ÖĞŸq:Ñ^S/~†3]å‚•¢‹îöÎvZ¡
İœ„ç®¼öRÍ¤uE¿7©˜Ê·*XÃ`”¯l!…:o…ê™Ñk›ñ÷JJÙ‚dŞÉrÅ¹\ÔÊÖ4+ŞÊQ_ï-ŒåsèÕÜşqŒµEŸqÜfS
Ò6åYÕü²‚+1½`s1{ö}7û5¤¢Æ¦yäEÌ•ŞV©ü†²Ã…ß'`ˆ‡§b¸'‡N*|‡P<f^O&¼Š%²{ëŠÅ:g£%ïdÉæİ22¼3üF7ºTOŠäŸ£<gãß<Tr«W=ÍúŞ­‘±®¾d’ùÔhÅÄ(«Ç;Å„°åIé±OK¡s}¡ÒĞYAL0[ÎÄW ŠÅüArVÉK)òhN_õï8Ä&sœö›¾1çvï¾E>h<`—ó/ñ:f¤f­)UÎ«f|o1›¡'jKùt\Gã„×Óéx|z;5B$ÿ˜`Ğdñu£Vp«ï½àò£v0Q[ÉpùëÍîƒ»¢"\”LÎJİ¯mh—rçGòEvRgÉ†CÜl³†ßgqëlt»]‘>-BÕFİ ~Ü:#ÿÛ†ÇÓÊ@©­?m3 ¸à ˆnx<m\lw~RtÙõnw&ÏÜÇdö¾TSdñB”×Å;ÚÌÚ°S7œıuyKqéß•ù2-¯…\S¼8¶¸ÉoQ÷´!qaûó·ĞÑm§—w¼Ú†ê•’Àøn´m¼ÕU¦ybjÆ›Èîí£çÙX5•¾p«%›è9ce·Ùì¬,¯jä¹?eÜ5¿•µÍ÷]–!mSÿâ„´VöI$³;Ói¤ØıH2KLÈ¸ƒÙ!EÔr“{Ÿ„•nÆ •]7ì,/§Yİ-%uvlÉWZk1)‚hå‰öÀŒ(íò\yDâØ÷×©ËÑ(éŞçl{R‹g‚'[§_¹w³åĞÍs
"­ÉH4ĞŸïå»W)ÕõvK–Í«EaÃf¹oãthTK=[	¯ V$‹PIş‘aãšF£Å€B}uom"fKà-Ôl!Àõk/îæøØx0LÜj©²kb!â`—¢e‰R I·{}Ch©ïëñIrg–=Nw_ÜİÇÄımä²í·TOÕE.øuW¡Xßûê>ÏÇæÙÌúÄ0M])”Ñ&Ò„huÀL©}b["+Z¾V&Y ü’w¾9WiPd$Ó§ùài§PR2ÌàâàÜ?"¹’şæuØu®ü }Óh‡Bã7Š™Ë!ElZWhÙòñ¨à²½¬ÒrSî²ºÊ‡fËŒÿKòkŸUÿ·UŠ—,UJ_òúXÃ»?¤9í¦Ò‹à©$¬‡›TÛş·_ñ4qŸ)b1áèIg=Ûíâ‘«KÆ³  œT ´üìÜmVAşoÀÀs‰í›Ş¢RÅ­/hnmõHkD+6¶}âî&¼IrĞä½ğ¶_¸B.0vDnã4DíXºÃıŒ>pY·,¬y_É<:œÉ@`È½>3õds:ŒœS}¬§Ã™¯möv·*ü5gV1õĞ+…i*š
¯èPöªÇUİŠ£Û6Õ‚•v›ÒUˆ…\oÆc:+a‚(‹ø&…l‰>«Ñ=gº÷î[Ûb'ØO„éš>~P`_Mç4ÎÂy=²™Õ)¦¢¦¥÷CP€Ã‰³Œæz»¡áÑy8®b1Q\û'ô¢iJiT$·ªÎC\[˜ÙË÷úcLæú™gÈêY‚edØ–ú×úwí6'Z¥´«®Ë*´œZcï^#POâ	–ÃŠ…r5w^Òá.ë``µTöœªÅoùQ]Õî+Cÿ ûş´?&Y…s÷™½j€§R1® ”‚-eçøXX>ò9o¬…Òê0Ğn¢11Ÿ¸9Í-[]¥ùE•Ú˜j³‘jöB.ê"Rõ¦}<÷UIj73^B®|—5¼È6(EÆ2qFºˆÓRÖ”zÿzn³5¾+K\5=eSóìı—QétHëGÊªvè| _:@}ŠÚNÙÛS ¨{Ä;ÃçË-­›&µ P£ÄÁTõ;)ivo,j˜¬¨,Hæúœ–Š€{
¶üÀ,qP—AIØ	‡*
9¼&mÅšcÖŒ Ñ¿XÛC$ÌëN@½/ê’£Ğ´JË(µu²IÍ>›N>v¬XÆ—€¹ÙÙ¬¤x:Lµ¡Ôœêhœëä1·SìgÈ-Ç¥n&³ReQÚOèÓë'ié£Ft­Û¾„%/i!$¥ËN²‡óÊÜ8¹eáXn7ğşUnØİ,E%\~¢Ì1Öbvû§‘Xò©µ³›Ê·ÃÇË‰zŒ…õ·ø?r•İM´k­-¦Z>•¼ÓœÀ6¿ÏÂê>”­Àqç)	™u«’–;Vƒx˜yêÁ¯¦šhÀMxÁJXn¯l«û,½)æUZvdgåºâëk~ˆÛ™éŸ9¨/y%d(—yäøÔKÒğÚ3KNœVÓP]E¨‘Û}´­Sªn®s–ÛŞËBézœg:òîKŒp®–Úİ‘ª(9•‰øÊ.ÑŞñ8äÈØÈ‰6Ù¯iîöËÅÅ)*YU`¬$œšëU9åó>$¤ÖótK×öã!‹¼Éû^_¢°³úmÁƒŒ‰’I³è›XŸ*´KaiE©¹×Ijø":†@T;ÍnşŠÂñ%9¯b¬LvL±Ÿ_¿~’¸×~µ‚3PsHmk¨d¾…²F”¯ªŸÅ~lh{î¸w-œÆısÏ@àİ”~lPñÛ…×(M×)MÊ'BKaæ‚P7Ğ;°‹UÇ€Ó mùøDİ^‡”‰iÍ‡ù‡:İÂg'2ÒD~3•ì{À»×h FÔ	E[F¤‘¼€¡btK²U^Aç€GHÀ¶1)k,ºĞ©“%> !)ØËŞÊ	æ/hŒÏotz“£Û!Ú„\XJ]Ævù:ÈªĞ#\Îæ0} *.÷3ÄMÚ4cäP>Ñ½PÂ’İ>gÊ¿>¹Q#¹	ŠÆ¯§Ù¬Ì›ôº JËëkÈHõ*tÔ“üÂ²JşéŸ”ƒæš`x¾ìË;¥%Uƒï7í8»Í½¸XA‡ëH4ı5®¿)]kÑèÿ6ãL¿¼kkó¾Êİx¢ñ ¡Ç*HFïåÜ0'—Rk—go†€µ	Ò(©™¬ÏºôZ¸»|ğœgüÂçôÂøƒZñ8£ç°lAÇÑ2•øù8#ÿ•:¢ØÈ¨lmVòõşÏª½ŒE8HAI"5V«®R6¾º|Šø¸ªYÃæ(RjÔéC×Ù=…];«8º§ğ©x ŞÖLùµÈã¤³'÷ÍpÖêú“Ä½›´Ÿg;¾µíÊw½â}«¢hh%åäø½ª†sû•§5ÅE¹ÕLá¬­d0§—­„ u¨˜OÍt;Îâí%™;Ò%Y¿Jú7­ú@DY'˜®8%*Ï•@Oz€Ã!ãy$g8èJ:ÜÓ²$)ënxl.Ú'k,¹é]„Ç,G…hõñ¼{¶¶£ {OxgYŠÑB0mŸLíÈàó—¬n2ÑY¿«.æÊıæ+.Eü°;Ô\Œgj}ën³™«æ´3ÏøB+öÌÇğ¶4Ô¼²¶0Ğaò(:aıhXö<â±G÷ñ²eiPµ£ÊÕ‰@™àæÃQåYÚ„^O¦@ŞÃàş%]™>¹	¢.´¡6(w¨Ñ{z·VuTÃş¾^Ëıª7%|õ­+3wáò<	À×Ïf+×#ŞnâBWÄR©“,*ëŞkì*´h“’e½Ùç4¾Oö(Ôo§ımöË¥Lliñ˜{÷«û{L«d!Mb[
ÀÕC§C:
?ŞŞ¸ÁÇEêü|Í\£Ñh
Æwµ7@¹’˜½¨\}ìŸ´a3š)€Åoµ¸‚²Ì(^:Æğáóv4} uq²·šEœ×p?1¿#­ÌU+<‘!¿öÌst°”W@°ß²OÓ¯¼èÄvŠ5iqµ·²/¡¢2³ÏÈ=@Jô9˜d]C®&ÀŠ\y½„’møHÅG•A¶'=îX½;\FÍyôç?ôÒnPk``béJ†t·Ú­c½“yaŸZçö§pcÄE®ÜâÂzvVşx¤Ê°äŞÁÆªÉvmºÕ!CÉóÁöR/ñ‚|Ìï©bšãDy¦ä…³¯á^/Å9£æ‘èÓsìOÒ=¢'²¯)L·×ğ°
Ÿ†{ìï|;—Èx>vwiÅÁ„a# q'Äéğ±EåäxÃ?”ãĞ|æê ©’ğ‡ï˜“…è1ÃêŞoWnèÚ<¼õXß¾F4@×Ğ§ö²‡`/Bn
õ›ˆÛlòšbq–Ån}8ñNÆx¢èø3øÎùb”<úĞÀw‹±%8rV–Á ÿ¦äñhŠù"BüCPÊÇÇı¹¾àWŒŞ¯d0S³*5¯”	‘iQ ×Sv$¿võ¨Yâ*Ìgq8k~Æ2HIiî€sVç|-‘ZãŸàáí3PÎ–-aUw²1¤JõÅ8 „ºóÓ·ë¥Tõw.äŞt3z.t‘sÿHAK± H–?]´~ÏÉ“+y3n(çSÕ½Œ¦$m¨dsvà!¾½^àˆgòœ÷©õÖãº0É=C²ëÓˆw¾Ûëz'#|ºú£2*¥œ;M7@qBŒÕºªJë“âÆsÓ13Nœok£T·Ÿ«‡Wô9q=
“¹â}‰ñ¥ŞPv`~V^ˆNıöŒ.+ÿ¥Û8xwâ+à†ÿûIåéç	Á8·´°°ipşÙå
Éï70
¡?ƒ?_µşqÕòßeüıÇŞ?Ëh¸”üß>ışñé÷Ïbşz„ú³˜ÂËÈß¨ÿ8PİÒÂÃÿ™çò7rZ0 0`À€0`À€0`À€0`À€0`ÀğŸä¿ èÏxÄ P  