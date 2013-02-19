#!/bin/sh
# This script was generated using Makeself 2.1.5

CRCsum="3818972011"
MD5="12123db3d44f6e1a4eff11d2da2e2638"
TMPROOT=${TMPDIR:=/tmp}

label="Testing installer"
script="./setup.sh"
scriptargs=""
targetdir="contentdir"
filesizes="6672"
keep=y

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
    offset=`head -n 402 "$1" | wc -c | tr -d " "`
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
	echo Uncompressed size: 40 KB
	echo Compression: gzip
	echo Date of packaging: Tue Feb 19 10:03:21 CST 2013
	echo Built with Makeself version 2.1.5 on 
	echo Build command was: "./makeself-2.1.5/makeself.sh \\
    \"--notemp\" \\
    \"contentdir\" \\
    \"testsh.sh\" \\
    \"Testing installer\" \\
    \"./setup.sh\""
	if test x$script != x; then
	    echo Script run after extraction:
	    echo "    " $script $scriptargs
	fi
	if test x"" = xcopy; then
		echo "Archive will copy itself to a temporary location"
	fi
	if test x"y" = xy; then
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
	echo KEEP=y
	echo COMPRESS=gzip
	echo filesizes=\"$filesizes\"
	echo CRCsum=\"$CRCsum\"
	echo MD5sum=\"$MD5\"
	echo OLDUSIZE=40
	echo OLDSKIP=403
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
	offset=`head -n 402 "$0" | wc -c | tr -d " "`
	for s in $filesizes
	do
	    MS_dd "$0" $offset $s | eval "gzip -cd" | UnTAR t
	    offset=`expr $offset + $s`
	done
	exit 0
	;;
	--tar)
	offset=`head -n 402 "$0" | wc -c | tr -d " "`
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
offset=`head -n 402 "$0" | wc -c | tr -d " "`

if test x"$verbose" = xy; then
	MS_Printf "About to extract 40 KB in $tmpdir ... Proceed ? [Y/n] "
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
if test $leftspace -lt 40; then
    echo
    echo "Not enough space left in "`dirname $tmpdir`" ($leftspace KB) to decompress $0 (40 KB)" >&2
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
‹ I¢#Qì<ıwÓH’üêü=ÚcFGC s	áM&È\H¸–İGòxŠİ¶²¤UKù8Èÿ~õÑİjÉ²ÃÌ{{o<¶º««««ªë«[½;ßü³
Ÿ‡ôŸæ7ıî¯õû«k«ëë·±±ºqG<¼ó>¥*Â\ˆ;yš‹ànëÿ7ı½Aš2)Tïÿ„ü×ú ×ï?|ğ§ü¿·ü÷v¾ÜŠ«âÈÿÑúú<ù?X‡¾~ãÁúÆêÃGı ÿkVïˆÕ?åÿÍ?oåORdyzåP)ÎCD.ÿQF¹œ¢jˆQš‹ó2Š‡Q2a2y™$øû2*&"aÉâZ¤#Q¤i¬!^¦iª
1H§YÂĞga^ ĞP^È8Í,†áE("…td2¯E”â’fCŠ>¨4YQà‘+ı ÿû 2wKQDSIt©ò|ôL4 Nø
yUÈ<	cGçy˜_‹ËI4˜ˆK)JÃÓjf™Ò¡×i™36¥¢4çx …’	Q…s¤‚`d~!s\1³RIèš Œe&T
@(À M—işQÁ8â1;½bìâ(S¼Š¤è¿¡í£”"…Å$bD4B
QĞ”„Éµe†Ìó4GĞ‹4¾@b;9:\ÉeL"Ä¡RRKKK{»û¯Nö6—JÀ¯rP-ÈB qØUW³§„‰‚’
Ù4KAºDäÅâu*†)‘ŞÎÄˆôÒ¸òDì<ğm?!N£0NÇÌš!K3äa„—!%4Jã¡Ìaâ8B½ç2‘y{Dé`’¦(L K³…æí]Eª@¼â)&ï-J!ÒƒéŸE ñuWKN
ÜézY)h
ÀŸ3VÒÒªÅ1íi0œ³P› óı˜l§ùpå"é!½?4ªhœËpxMD€Ş FÛ…Ææã’w¢½aX„=ØBÂùıüèà©'Ê¹C‹ Í Ë>ŠÆe3ÏòŞóº¨œÓğ#¨l™“Â£¨Xû`&c©…bV«Š¼ ‰´§f£Ñ6B£q‚ôY­À]åŒ×BŠÀVB W¦aS+®6ÉĞ¬Ül‹İ4QiŒ“ïÄ*íR_C5…š¤e<´¬dÂëĞäe¶øu»MÁ]±søzsé²¾#BmÉWÓ˜'D³ˆ+e+˜ 2ÿ†»Y½¹´ôØf¶¥~^è_LL¸{ôòåÎáSq°{qŸwö%‚€hK)Rf ›"›â(‘]¶]¼+âôõ\÷+ÒZ$ÖXkf4™¶QNi˜«™½ºrõÓğl<#È@¬2áµrÏ+Ö¾ˆ{‚/ıEˆBK€~ÔXPoˆñhhOœ @ĞÂò!oş&zâåÎ®8:Y®l%`³BÇÌu½İ?|zôöK°l5±Üùüqâ?#Ü÷‹ÿú­m4â¿õşÃõ?ã¿ïñéõÄîIm]¼xÛ¯6¡öåäªÊ"Šƒ\åUpok¶glØ°êª¥w'ÏÃë¶pÌóàçôÈ¶Ö¡šÌôD)Òº”•çy²I²‹Ÿ––„èİƒ¿Ä=ñ÷Êí%`ğ‰é0]cHEqœñDàŠœ5ax4˜ŒœJ˜©ƒ,å„ÑQNbª½Ré ¢(=£ g©İ8“l’&R$åô\#z
ú*ÿŠÑR!&!ÎKÉ0S‰cÔ&7ÁTBXFrè·:ÉyÁ²8Îb¿Â‹‹
9ßƒ?ÄYqIü6ÈèÙaÎ*iä¦°BX„'=\˜—yÙE—ÒAJ À@nç2Ë%„Ù`KRCq;‹,Jû”JJ7"J5È£L“–Ãs˜5á
 ctO¡‘=*ÖiÍ£z)€Oä@*…"¤9:LFv.'áE­—IĞ„S…	µÚF)3êÁß
×jÔÔ¨9%ùv!‚óğ<–uï“O8â“èÔIœ0ëP¬‡ æ­¶NYk‰C÷ğ~Ñ“øËâÓM[{cº®3C×E
ã—X,¨ÆÛJu?)Õ¶C(‰3,‹5cªkš²
Á^…°‡Ò„Ê,¥0“U]9Øæ‘A‘àÀ]ç/3\m¥zcY<Ó”"3r	ñoR?gÈkX€Në™úW¤ÆeY0ğ/GWæ~ºCÏ!»–¨Uÿ€-£ü£sÊÒŠÓÖJÁZ}ı°,RÃ=oÖhD+eñãDsÕ…OÔÌÌ³í,äÿZ‰†œmÖd¢O¿"UÓò ÏRã@İı{DG­‘I¨šZ„é öìëÔ·©&F 3åî4sô1¨Æ91Ìƒ¤ÛwÇı°-V+¬vAˆyãÌŒkâYiuîŒÄhw6;g&İİœÅU¦~X«¼ºY¤ücV\vßŞ)$w÷ÙØ'Çœàøÿmä½«MdÖbÈ~Ê«"áàŒ&Áüc¾QªWzÄôúY”«Â<n›@§X¾çŸ^Ş_ş…¿NO9,=X/ù{¡]öÑÓ#ÇyëœQ/.„ÄJ‘­6j“sİ€¼š	¢$+ÁWúmšœ°A—œ
.€XŸB•ZâÍˆ`c_H†Â~•ùS"çHv²}s®g‚Ãa<í\FqŒU[œÑÉÿùu•s]‹#‡3=•VÂ¬»ÁLıZÃó/~-G#™Ëá1¤İ`‰;Foêht¼ @v‰¼6Ú³fCƒ¾~„à{1×¥Æ—a1@ç<eM‡D½á–Ü²QWn(E0#KkĞ 3qì­¤Œã­y`î¾›B]ƒ)åãh»w†Àª)‘dXÇ!˜bÄŒó´Ìü>6ïÜ=¦išH·œ‘Ö˜éof£ñËV"tui’ew°a~ {Ì×ÀÍŒ­B>âÔñ‘ G°Zÿhïj 9¦r¼¼`Ç&Å	 şøöµ²ºVYò**`¹®Ò*mˆÛ"›ÑĞõ&uƒt9Œ
]W„ĞÍ@`<ÆXWŠŠŸTµL€F»ÄnğbTÛÓ›ƒ6K\\·ìÔÿqNmÈ¶h“<¬æJö©ÿÔf@U¦ªéh“ iÔZ,lQ®š‘«
 ÂàØ%À$·Po!&÷½ÀÀ%W+¢¤¬B1g‰Ö­­é­wù†0ı8ZvTËÕ¼8ö]kâPÙÕ¦Ã¼Eßj\»Î­û:ºgM:ƒCjFµ¤kÖƒŠ·¡(Ô…§€’®Êˆ«ÊÙğh-uUé˜vu­‰ÓpøğCÜ`‹&í:F3ß¦_®Èÿ°À-–ÓfëïÎ€sÕÖ·´Î8€ d ²Ä1‰£‹Í'·zÖ¥ï¾ş^;sÆã[­ç›ù­&Òó»•Ö-]ÀÊjCµ”lŸRtm@k*¤«tt¢kB¥9–1H9N.dÉbJã4ıH‡…|¦’–ræİÕ	áÅV¦¬z”´…n…Ô²ÛjÙDã6«?X EÈ$ÔæŒÊ:¥¬ èãPİ§9SiêŸàxqë\¦D¨r¢MòHøĞƒJ:v†mFà·=‘Ã ”NªÒr<á‚Ì—CÚ›¥**¢ÓÓîĞ¶Bê ÚÇ!µÍŠê"†.¦¹ô6¦¤€½ÛbzŒÌj²$ø÷xĞÅâÓ¼³dáŒÛĞéî:N˜ìKPj0‹iÔû´†¯Èæa²T2x“‚´x#Ç‰ïU”«è`Co{÷›M÷Á4Yj*¨z‹±Ï¼"ŒC²3}çEö^«{m+Ùb_£†¼²ºàSJÇx4â¾·|ZüeñÇ«‚á7í¦ÁXÙ½RêVõ¦E,£/Ëy6M/ä­<µól´ˆgÏh³4˜6úêL}¦%s™VçË(qyÖ`hƒiI;Ó’[™vh,ŒfZòÕ™–üQ¦µĞ|RN§!âÙ6oK)<FÜ:j´&Üš¸Ûø¦V…€ä,Ñ¾À½R€†8äH‘Î”Ñşc°WEĞ6Å×14  $Ù”ôk‡ö]·ÀÂWDœ“/Mpyˆ,¦\ªUf‚Œ”¶ìaÃØf¤Øä!pe¾ùÂ|¬Œ$0'Áç –É¡İÚŒ”dWÜ/U8–›§…=ºyŒgïa}OÄcR^¤æ‰×1­Ö"&‹â‚âZŞ¦ÑoÕqín¨hc'½Ãe@¸Ñ>ŒCnc£uÑ7#¸“©qŸÚ!Á7Kÿ’ó_:íşê§¿·ÿ®=|°±Á÷?×­÷ûğşß£Gş<ÿıŸÆ©i=Ç›9T­ò½™®}L}`ßËp:¢J€fú(?àáoó¨hO &zs|ĞÚ;/‘ƒY´º{.ô5ğA<]Â4×ÁK<ÍË§ÑX6-ÌazR&;ñ8…ÇÉtÎ*n=¿ææÆ¡4ßNù´´Ô±6/Iî?5e!ÛüIxK_¾şûQô_¸ÙjÀ
JÛWĞ×'ø¥™yšØß‡½?{HsR¸Şé´øAÆğ!¯ïmoŸ&ÛÛšxr.'i\Râä‚NÜ øŒ—î°h6E€½+™"ğÿwõºb’N%^‡|a£ğN‡É€e€­f¶¹ÓAßñC¤şÆÑğùšd¦¹Óæ>~øAì'8ÄNÆ7Pù&¢!wõ9ëæÎNï]e„x#ÍDºXÕG'zPw¸–§q{÷E¹9mæ“ªî¸B‚‡ÅIM(g¡øóÙe§ã(ye®Îmëgâ!óÏÔZ°İökxÊ›-HÖÄb úg$"”„FÃ¥ñù3CšƒAÏk¥Qı¾6ø)ÙñtPÑJ	ùqŠ „ÇŠÔëaŒpyƒa Íä©µÎ?Ñ}¨N³5XT©ŸÑÍmÑ"P^/E¤xÆ¾Õ-øzÜ †¶û÷5tÇ™ŸªJH×´Ü +„ÄÈ™-£)\1
F,$šÜm!²ƒDÓüzÙóîKáÉX’ôjÚµ;9‰ÆIˆ7@aqcYXXV‡.!g¢­Ô±º˜ÅW’¦5vjªéŒÓÚiÔBİ˜~F9„Î€®5Ğ½Ë«6¸¬îÈ™”0+\½¥è¼…[ˆ¢iLS¦÷Á2:|âÕe—XÆ˜S±|ŒM5ã4jft j¦ohCÃ%6R‚®^×2Şñ-ó¤V|2Ë«äd&mJG“â¾98Ç{'¯Oö¼J^·z	¦Ês=˜ËÆßU ¨¨‚ø«éô’¬c{‡¿Îêf³fU`L¹˜ì è˜úËÍ5jÛÎúÁ˜,ëÓ7Å[ÌL-ïBæxŒ.Ï–
ÏsñF•#B}CKèáRŸ@ø‡i!ùÖ?«n4+º¨²¢dÂuƒ`ÙZJgQÚmÔÖF—Å<H!×ª'Ê¡è¯¢Òa¾[=Œ³I˜”SXÀÀÜ­F*‹Ãkƒ¾N\àÍb¾aµc¯L)˜j,o$´D¶¤qq¨&1Z†.’z¯!–BUq‘U¥¿xø“'Z7•Üf-s„Í³Û$
¼Á.à7Œ½àg1ÍfĞhp*¬™S¯v	–Y€TP' ±wÑëÄ­VÖØ½ÿ¾Ìãs&E‘©Í^ïç¤ù¸	yÁY˜eª¿Ú_Y]í÷ª›l=‹ÔkŸ”­Æ×œ‘1šé€¡/1R7µë×)¾gÂµaËÅ™ÃN¢E°$ñAÃl5ÛwâXKÍ6’¸{=‚lÎ!Œ¡Í	Ûò	d*/ğxŠ`ûÁ¯ëeD†°9DØ~>
j—Åæ‚ğå°¹İÚ¤›~`õ@İ~Ã !p¶D§nôÏÍ†T-¯a× L?Ÿ Ú)I®¸^ÈEŒmouEH¥Ï¹ZÒ=>ï"BZBŞw{ÇÇGÇg§EevõKXÎ	<½·ƒ$y5hG²L3î°Àœëuk×ˆJÁ1RWÔü?oG§æV‰:¤}úŠOí0aÕÌ¯Lø–ÆÆJŞR¤æ¢g7íõ-3—²(c#¡ĞÎ—ñúoz©„ËãO7<úf¹FçœıX·f±	iV-ê1p¿âY‹HàX¿!X½wá¹g-¨­¹o8Yx×iXû&4Ğ­o”¦”´{ë9Iƒt«Ö£eKïBºEI¤&²zÒh‰3;V¥ÉsKg›½­ÅZtNo\w§T·¡Âi”‡¥ß÷»/vöŸï‰{¯öOæÃ¶ø(G«¨KÔËœF·Z3RÜìxú™ ÊÀÈ Q4’¶Ç”©ÉsÜU‹FúH£‚Ew éÜ²	¹ÿF±à&2aœ6¤øiÜ¤È¥cR_¥0…šA‡±U
%R·Ğ3áûújÏP»ñC=ª§X& g/“¡¹°FÍ7ü¥1ØûÍ!ŞgıÑ±aGÛ|1{¹¡Ói/p,¨¨àk«´s»PütWı´	ùìDâ…-©H”Œ.İùË–EU\V÷Nf…:–çUæ¦u½èÔT\sŸZëÙ0ŒxQÚ¨]k­ 1¡tÊ]„·š»ÒßZš›öœğ[µú•YÄ 1Va^ĞÜôl›gm»¦¶™®¹»±jõÛê¸`·æÁ>Í”…¸Œ…„ğˆ<êV•Íw–5LXÛµ:I0ëáŠ 3[-Ë&0*º™¼SŒiñÎNOW[¾py×ê¤+<O/¤ ¬Ùó*…· =Möªwi“4Hñ®¿rwx¶)nÁÜ¢Tz²jcp‚dÛÌ±ù&mæHÀ¯™…(Y®•?ì/÷ØRÇ©
ë2V JÂƒcÃn-wÛIWÖ´ıšµ^sŠ³u+¥qRáWĞç5Şå”75%b<•÷=ÖWßÑ-Şî`Òµ•›³¦O}wV¯Æ¹×¢»¢İÓÂ®‰4ÖÏj²~s|  Ô0ğä7[^Uís)ósG)hmÕ¯eZAa¬ò4åHØÇëJ0{"ää8³Zµ´c
œğšñwqI:Ãà·–¸|ÆyïëŞë7è(¿:F
x ¯Ùë½yılågOãvpüX¥Ñï‘ÿïU4$Tz'¾c¡œÍÌu¹ğ=ÍRÙÊ8šz¤ëŸ¿Âv¬óÌ²µÏõ31J#B©mí™èD»¡	]¥Hœ"”­îEpÃÅòêâ¥[¾¦« ä"ŠÜŞ=ı¬O
Èr0ˆ±ÅÏ²\» nµj6ô/‚˜úYİñ×¦Ù}‹"%†uÃc-èB,±Å9Ğ%[¼–€K¥a±_¥FÉ-PßZg Á¤±æ@<bkƒp–oààşV$8YÄ÷(åOx¿Åò‡ÿÅ‚¨0ÑÏôÀ™éç3X:+«CÚÕ;1İï3ã_ ½ÅvÜ±Üš´E9[Ç¯[æúAe©»®sá¢[ÏªÇærÍºŞ†CÖ×cºTÍè:Økc›Vfø2k]ÓvÖ´5Ä?şa[GSˆÑu*ùh]?0K—¿/¦õ_Œ›åsîÊ…K¿¿U…ä¢"Ìá"õÕ†·{v·züoèÖ+J¬iD¯u·ùİü&oÇÙ€¶áªşhªôı|OÛ˜/‹?psá"ÿ‚âXøƒ£çû‡·—~¨øãF²ÃÏ¶0¶vká¢Õµz´ZU¿œût¬ìï¹/—.o
oşQââÿ‚ô§æØéå>ÂœíôŠPMÂ<íÿÅ ˜FJ¿A8—=ævÇBÌ İJj©Ôéıúß>ıMÑ¡òÂJÒÂ]Àù*ÕŒR} ÚË*Š¿‚Ÿ=Éoõä4é°[» ò:jwÍÄtØæª©µÈÆÌx2€ôàäÅÎJ_ËæİO[È¿C,Áh|•®›á›t’>‡]BLÂ½î@9rb‹×”Ù˜ékPÄûëu!•ï½9YÙ9Ùİß7Níša¯ã—æÑ6p)Òo¿%9/GÿÛÎµ´¶áûüŠíF=Ä$®¥F>Ô„ÒÖ†äP’ôPLh,KÁ"©d"Bâ€ÿ{wvF¯ÈÆ"a¾ƒA«Ù—f´ïÎ|›=ëwc[*0wÙhîs›ÊvT>ö¼{½§‚ê®Û	Vªÿïx¢ï‰¼uÜÏÜhm´l<«2´µRsJJ×†õİŞ´2ùÚeKh:¬#m•Äÿš
UeLû¹6V:TµwF·ÂúÙc^·rÁ‚õYm/7Qœ‡{q?ãH‡øÜÌa=Ú„]½kj¯–ñßÆÉícfc6ş_×÷ûÿí{‡ü_Û÷%şû%°óáS`>˜æüø}r2Ÿ^,îÂ€áèôìP;G¿~4ÿÒµˆfóT9,M— ´×ƒş@…)'MNCµ¿Pz˜©aœÍñl"ÆÏÙõ5åPsjıW­–6¿‘Ø|œ%ù™·“?Ëóª¤­à8Í‘Æïw@©+;tQzSÈE¬”Äˆ¼’éMŞØ—fM;?~0›ëûqZ‹Ç—j‚„Š:¯¢ÕyCÈ4iXUmìËî­¬«FbXä#…iDÁf©vu³Òe¼}&lGU5è–K3Mêí®Ñj³ÁÀ¨ëjPfsOÆ‰µ)ÌªÛ¢ªIL“I¦–æQkHÒ®fé(›Î L“€¨2íX n“‡x¡:]ü5
äR ovı¶µ¿ÿ»ë®óÿ»îAOÖÿW_ÿË7ğ/ÁmbaöèäŠæÓpóÏ,X|Y˜–~£Æ/@ @ ïÿ'h· x  