#!/bin/sh
# This script was generated using Makeself 2.1.5

CRCsum="1057805282"
MD5="bdbaa8d0135fa555a94791bb59f4131d"
TMPROOT=${TMPDIR:=/tmp}

label="Testing installer"
script="./setup.sh"
scriptargs=""
targetdir="contents"
filesizes="6355"
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
	echo Uncompressed size: 32 KB
	echo Compression: gzip
	echo Date of packaging: Tue Feb 19 10:15:25 CST 2013
	echo Built with Makeself version 2.1.5 on 
	echo Build command was: "./makeself-2.1.5/makeself.sh \\
    \"--notemp\" \\
    \"bundle/contents/\" \\
    \"testinstaller.sh\" \\
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
	echo archdirname=\"contents\"
	echo KEEP=y
	echo COMPRESS=gzip
	echo filesizes=\"$filesizes\"
	echo CRCsum=\"$CRCsum\"
	echo MD5sum=\"$MD5\"
	echo OLDUSIZE=32
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
	MS_Printf "About to extract 32 KB in $tmpdir ... Proceed ? [Y/n] "
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
if test $leftspace -lt 32; then
    echo
    echo "Not enough space left in "`dirname $tmpdir`" ($leftspace KB) to decompress $0 (32 KB)" >&2
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
‹ ¥#Qì<ıwÓ8¶üšüÂ³Ì¤:M[`^K9Ó):¯´¼¶,»‡ö°n¢$ÇöZv?–éÿşî‡$Ë“2³À¼}g2‰¥«««û­+¿wç«VàóøñCüî?~¸â~›Ïşj¿¿òxuµÿèÑ•şÊÃÕ‡wÄÃ;ßàS¨<È„¸£‚i˜óánëÿıø½£İíg¯vıü*ÿšò´¾>OşkëĞ×ï?^[¼òğQä¿ººöøXùSş_ıóVşp!Eš%áPE>‘â<Pá@dòŸE˜É©Œs%FI&Î‹0†ñXñPdEãïË0Ÿˆ@\Y(ók‘ŒD$‘ò…8LÓDåbLÓ(9 Oƒ,G ¡¼Q’Z‚‹@„
éHe]‹0DÍ†}PI¼¬BÀ#—û>ş÷d0î0’"§’èRÅù4Ìé™h œğ'ò*—YD"
Ï³ »—“p0—R
†'åÌ2$C)®“"clJ…I,Î%ğ@
%c¢
çHÁÈìBf¸bf¥’Ğ5%ŠT¨€P€ÿ š&.“ì£‚qÄbvrÅ,ØDaªxÛqŞ~ç@ÛG)SD
‹‰Å4ˆp„¢ 	(	âkË™eI† ItÄşr|x°œÉˆD0ˆ¥¤òÛíöîÎşŞëãİvM	|øõAr¢Å§i $ »êjÖáôƒ CP’A"›¦	H—È‘¼_œ$b˜é]àL„HŸ#ËOÅÁßöbâÄ0¢dÌ¡Ò$EvAx)R‚@£$Ê&" Ô{!c™‘G”&I‚Â°$ÍQhŞîU¨rdÁk^‘bòŞ¢Ò` =˜şyz]wµä¤È’$×ËJ@S şœ±’––(¶iO²pŒh„áœ…Ú ï/ÃdÓ(É†Ëq±hû0Ğ¨¢Q&ƒá5zƒ	l¶DÏ÷{Ã z`BÂùıâpÿ™'Š¹C‹ Í$ñ(Y@Ì0<{Æ¶çuQ9§ÁGPÙ"#…GQÅ°öÁ$ˆÇRÅ¬VåY1ÈiOŒ¡‘™ ¡á8Fú¬V UyÇã5Ğ‚âp •ÈåiFÔŠ«#š•³ØIb•D8ùv¤’.õÕTS¨IRDCËJö!¼MîP¦`À`â×Í>­bûàd£}Yµˆ@;EòşÕ4â	Ñ-âJÙÆ¨Ì¿ •#«7Úí¿`›1Kı¼Ğ¿˜$˜pçğÕ«íƒgbï lq-ûA@´§	³M‘MQË.û.¶Š(¹D=×ıŠ´‰5ŞšM®m”%Sæjf¯ªÜDıô#<‡Ï2ËƒTxÜóÄ²õ/â¾àíï„È%°èGõÖˆ†öÄ1Ğ±tà -¬0äÍßDO¼ÚŞ‡ÇK•l”è˜¹²·{Ïß~–Í:–;ÿ?~Ïpäõäı‡V×ò¿µşÚÚŸùß·øôzbç¸¿º.^¾í—F¨c9…ª"#?“cyåßßœíÙß>¼ºjèİÎ²àº©có<ø9}Ç²©õe &3=a‚´¶Óâ2OvIvqâS»-Dï>ü%î‹¿—a/–˜ CLL†áèS*ÊãL$‚”¬	›Ï£)ÁdôT‚T˜d)'cSõ”J!ea1Kş ˜¤“$–".¦ç1ºPÒWÆWÌ–r1	p†LJÆ€)€˜J£6¸	> â Òb0’C¿uÒIÁ–ÅyÇ^\˜Ë)ÄÌø!—°ÈòëTâ·AFÏ€ÌsVI#7„„Â"<éáÂ¼Ô³È.‚¨2@P@ê	r;“i&!ÍÎ[œŠ›YdQÚ TRºÉPªA¦š´sÀ¤x¨IW ³{JåˆìQ³NkĞK	|,R)ÜA ²A’aÀddçr\„Ğz9‘”I¸í¡p!VÛ0'e¦Q=ø[áZš5£ Ä9ßdAœGò‰î}ú	C~^€:‰cfŠõ Ä¼ÙÔ‰"kì qè¶=IgI|ºij¯M×ufèºHa|›Å‚jìx±U£T÷“Rm9„’8ƒ"OP³0§º6©)«Ø*¤=´€D¨HJ39QÙUóˆ-éçÉ>Üq%†«¬T¯b,óçšRdF&!ÿKâç98à´9 EjX–ÿtûÊÒOwè9ì®%jÕ?ÁdTçğœöIÉië¥`­ı°$Ã=OÇ¬Á×ˆV:Kâûï‰æ²Ÿ¨™™gÛYÈş5{.ôY“È>;%©š–µş}Kõ@ôß':*LBÙÔ ¼P'İ`³'IÇ2¤œÌ”;ÓÔÑG¿çpÄ06İwÜİ-±Rbµr@ÌÈgf\ÏJ«sg$F»³Ø93éîú,®2Uğ³ÀåUÓÍ<á³â²Vü@x§°¹{ÀÁÀ>9î§ÀÿÛdÈ»Wº4ØuäX‹!ÿ)¯ò„ƒ3š=àpî÷¥£z­GL¯Ÿ‡™ÊÍã–éğõ«ãuNO/,ıÄ_§§¾¬—â½Ğ!ûğÙ¡¼õQ/.€•"_mÔ&9çºE5“
„qZ@,.3Œ!Ú59iƒ.9å\ ±1…*;•7#Ã¾?):åÎŸ6rd—`·Ïs!ô8Œv;—aaÕÂgôæÿüºÜs]‹ƒ#§3=•VLÂl¸Á0Æ=ô†3î_ü\ŒF2“Ã#Øvƒ7&î½©¢Ñù‚ÙÅòRØlÏBƒ}!ı öâ^—_ù ƒó”a4õ†[rËF]a¸¡ÀŒ,5¬ìCÌÄ`[qE›óÀ\»›BUı)ÕÁÑÖv¦Àª)8‘xXÅ!˜bÄä³¤H;}tlŞOh=¦i•šH7‘Ö™éof£‰ËV"tui’%w°a¾6ÖÑÀÍŒ¯B>¢Ä‰‘ G°ÚÎŞáîÕ@rNåDyéƒÅÆù1 şxvmÇ¬®d–¾¼
sX®ë´Jâ6ÉgÔtm¤n’.‡a®ëŠºÌç‚ëJaşƒ*íÈ$hd%Ö@ ŠQmOK”_7X	êÿ8¦6e[d$ÏB«y€’cê¿e¨ÊT5m$Y¡Aí£ÇÂåª…*2Î]|Üäæê-ääÏ÷ °íjEe*æØh4mMoµ«cÓ£%Gµ\ÍÛ¢ëM*»ÚuØ‘·èÛBkÖ9£u_F÷¬KgpØšQ-éZ ÷ âm ru!Æ	` MWéÄUlx´–º*uL‡¿ªÖDI0|øŒŠ!nğE“f£™oÓ/Wä¿[à–ËicúDç»3àÜGµù5½3N  é«4±cNâhÄb÷‰Ãß­œué»¯¿WÏœñ¸ÆFï9Çg~m§‰ôüf¥uKğ‡vµÀZJ¾Ï&)º6 5¶«tt¢kB%–1Hy#_È8”1ä,´ı’ä#ò™JRäÈ™[t;PÇ„[;0eÙ£¤Í(t(Ô *@İfƒ	[¬şà!|°	¤¶ÎÀ¨¬SÊòqªû4Ç#*MıÏ!ïãcË„UN¶ÉIéÚdPIÇÏ Ğ0$c~Û9LBé¤*)Æ.8À|l{ÓD…yx #z:ÚVBH@û8 ¶YQ]$áÒÅ$“š)(aï6¸#³Š,	ş=t±øtoÆ-Y86ôDº»Š&û”ÌbDµVğåé<L–*C)H‹9Š;^I¹
ÿ½å=¨7= ×d©)¡ª-Æ?§àğò ŒÉÎôUçé{­îSÊÓÄ †¼¶ºĞ¡-ãÑdˆŞÒişİâW&+¢Sw´cé÷H©zÕ›±Œ>[,#äÙ4¹·òlÔÌ³Ñ"='c©1môÅ™6ú2L‹ç2­Ê—Qìò¬ÆĞÓâf¦Å·2íÀxÍ´ø‹3-ş½Lk ù¸˜N<ÅÏÓ-6K)<FÜ:ªµÆÜ»f|S©BÀæ,Ö±À½R€8àL‘Î”Ñÿc²WfĞv‹¯sh@@›dSÒ¯Úwİ_qrL¾4Áå!:²˜r©B–;d¤´e›ÆÖ·Aº€MWÖ±9_•‘îIğÙd<†ÅAj·:#%™e%÷ŒåÆinnàYÇ{XßSñ„”©yê5fL+•ŒÉ¢¸ ¼–Â4vu\‡*ÃßÙŞá2 İhÆ)7±Ù:è›ÜÉÁÔ„O‹à›ö7<ÿ/@'ÜıÏşÃòşçÊ#¾ÿ×_ÿóü÷[|¾»Û;ãŞ9„†v{çÍÑÑîÁÉÖ?ÒËá?Úm9˜$ÂÃ‹JÛñ0Cã>/â!úÌ`oT6çğ=Ğk·³©ğÌ£U-h¿óççÿêıºäòõnÜvÿcõáÚãÇlÿëÖû}¼ÿ½úhıáŸöÿ->µ[ÕÏÌ¥Š²Ş3Óµ‡¥ˆû2˜Îƒ( 3}‡Tàáo³0¯aOôæh¿±"o,³hu÷.]è­áƒıtÓ\û¯ğ4,Ÿ…cY¿tba’ãb0ÙÆ	<N¦sVqëın®]JáÛiŸÚí–Í™ğ’ôŞ3S¶ÍŸ„÷·äÕÉßÃÿöÄÍfm VP›†¼†¾>Á·[zfŞÈÓÄ½8—cÈ‡hNÚ®·Zy0côù’GÇÛÚ:·¶4ñ”\'QA…´Z‹_ñÒ-Í§°{%³Aùÿ=…c½®˜$S‰×¡ß‡x@‚»ğV‹É€e@®5Ms$s³VsÇ»¡úk…Ã×ÔÑ$3Í­¦ôñî]±_à;ß@ç›Èrè{„ÜLÔ·æ¬›;[-D¼{•
¼âj&ÒÅÊ>&Ñ÷ u×€kyš´÷è/Õ§­Ğ|\;ìñ@b”Õ„r
Ş »¬ £dÆ¯ÍÕÙ-ıL<dş™Z+¶Û~Ou3’Ö±¨ş‰%¡ÑpiVüú+Cš‹WJeGõÛXCĞñHñŒÅÓA5ìVŠLÉ,¾ï©×Ã=0^ÀgÃ4S¦®uş©îCuš=ƒ1@¥úİÜåõÒÏøCÀ·²	_OjÀĞöà†n9óSU)ĞóvB­#7È
!qçLƒÑ.#M®™ÃÙA¢i~½¹Ø™`N%I¯¢];“ãpx7–¹…euèr&ÚêHe«‹Y|)iZc«¢šÎ8­F=a«Û Ó¯À(‡ĞĞÕº÷AqÕ·ÆêœÙÎA	ÓÜÕ[Ú7pÂnËTÓ{Ïà>±EudÉ%ÖTX>Æ§šq53Ú5Ó·‡´£á;)AW¯k	ïøÙ@R+>™å•r2“Ö¥£IñŞìï‹£İã×‡Ç»^)¯[£Så¹‘ÜåKãˆï)PTTAüUzI6°½Ã_gU·Yñ*0–\˜lè˜v–êkÔ¾;õƒqY6¦oˆ·Xÿ0µü™á]Pº<_(¼Ï7*ê7tğ-àEç É%¿õCÃÊ7]T[V2æº¡¿d=¥³(6*k£—E<H!×ª7JÑ_A¥Ãz˜z¥“ .¦°€¹[9U× ı:AoğËm{eRÁTcib#9 6ù’ÚÅÁŠÄhúÄ;\
UÅD^•şâáOŸjİTzp@6˜õÌvÏn“ÈñB‡€_0÷‚Ÿù4A£Áé` Èz•ÛğÌ¤‚:ˆ£‹^'vl6²ÆÚşû"‹jÌ™äyª6z=¾Gl‚—Ÿdã^ÀÛì MU¥¿Û¤^y“µg‘zÍ“²×ø’32F30´6ã%fêæìê$Á÷ÌølÈrqæ²Q†¢X†ø a6ëíÛQ¤¥fIÜ½AÖçÆĞ„mù”²ex<E´ı× ô2"CØ"l?Ÿû•Ë¢sAørèÜníÒM?°€ú n¿ax·D§…nöÏÍ†T-¯A–U L?ß °S’\q½
ŠúŞòŠ &JŸs7l÷ø¼›iHyßíæ¥ÛÕ/a:7pè½=$É«ğ@«8’ešÑ.ÀSr®×­C#*çH]Q‰ÿl.NÍ­·Hûô5ŸÚã†U3¿tá›7(™Ãö–25g=»ÛŞ¥bæR&íØH(´†ó%¼şŸ\*áòøÓ¾YªĞ9ÇËâvÍ-Ö!ÍªE5î—<k) é7„Ë÷Î =÷²µu÷G¯Sà*«_…º•ä’’’æk/zNÒ İªõhÉÒ»®çaª‰,_£¶ZâŒÅª$~aélò·å¡xƒÎiÃu-¥D¸é„®n9~kŞGì¼ÜŞßß=x±+^îî¿Ş=:Û£8--Q—¨—9aµâ¤¸Ù‰ô3I!ƒlFQÛ´=)¡Ì™ç]•Ìa¤4KXšÎM»Á3÷_)ÜàQ&Ó?µ›T™t\Êâ«T¦p@3è4¶ÜÂ‡±Ô-tÇTt:újÏP¹u·šÕS.ãC°—ñĞ\X¥æşÒìı¥úïWıÑ¹aKû|1{¹©Õj.p,¨¨àkë´s»XüpOı°û°Dâ…-©H”Œ.İu–,‹Ê¼¬Ì
u.;ÎMªÌ›Õ¢S]qÍûZÏ‚cÄ%ŒÚ5Ö
jJ§ÜExËy@°ËıÍöÜmÏ1¿U¯_™GcåæíoÙ<o²šŠ)2]s­±’jõ›ê¸`·æÁ>Í”…¸Œ…á;yØ-+›ïB,k˜`Åjõ&Á¬‡S8*‚Ì˜,z–`Tt!=zg
ğN1¦6Ä;;=]mùÌåa^«7]Áyr!``ÍW)¼íi¼[¾K?˜$á@Šwıå{Ã³qæ¥Ò“•†Á$ãØf.ˆÎwi3GŠ[ã¥JùÃŞğto¶[NUX—±|hPvk¸U3']YÓşkÖ{Í)ÎV½”ÆI…_•C0œ×ø@Ô|”SŞÔ8ˆñ”Ñ÷H_~G·ø»ƒI×VnÎê1õİYµç¾ÑÍ‘ÆpM¤vd°~V‘õ›£}ÛIOÚÆ–WU9ƒÁ½”ù¹…£ı´¶ì×2-¡0Wy–p&ÜÁëŠ0{"äìqf;µj9hÇ”9é5ãîâ’ôƒß:jsùŒ÷=X÷^¿‰DWyÊc$Ÿv4{½7'Ï—ô4nÇ÷å6ú=òÿ½
‡„J[â;ÊÙìÀL—ßÓL •­¡ŒÂ©WBºñù˜c•g”¬Õôì|n<˜ÉQjJÅ´g²uî¦&t•*vŠP¶º›cÀµÈË‹×nùš®‚SˆÈ3{/üôW}R@ƒAŒw|"~¬•åš½ p+¯T{´# ÈÔÏªˆ¿6Œõ-Ê”ÖM_Œ· ñÄç`@—lñZ.•„Ån|•J%·@}h“
Äªñˆ!¬"ÀY¾A€û/X‘àÍ"¾G-Àûm–?ü/–„¹ÉÖx¦5g¦ÏLbé¬¬
iWïät¿Í†ôûqÇskÒUäl¿ê™«¥§î:ºÎ…‹nu÷T>æ0—ëÖµmY?^Íé5?£ka¯Ím}˜áË¬Ot]ÛYİ7Vÿ»]lMY ZD×y ä£uıÀ,]ú\¼¸­ÿlÜ,Ÿ[p—!ÔxúEø­z,$a©¯2¼9²»ÕãÿÀ°^FPbM-{­†Ío7ÙgÚZ¨ú½Y¨Ò÷/ğ5^íc>/ÿ4ÂİçÙgÀÃï¾Ø;¸½ôCÅ7“­~6¥±•[Ÿ‘­®V³Õ²úåÜØ§cåÎ®ûrùÒ†ğæ%.ñl*^nã#ÌÙN/Ô$È’şOa€I¨ôÄsÙcnw,äÈĞ­¤ö‘JŞÏÿóáÙZpôó/Š•V’ZïW©f”èÑ^ZRüÂøìI~c$§I‡İÊe =×Q¹k&ş·óWAÂø«A¨ Eë¢‹Kñju«ZĞ¡ïîı‹M¤Uq”ï·(é]j.5ı’\[m·j)up¡aü´§éA¶^&¶ààBÖ•Ÿö6~[^""o~•†<àÜg²“Ş®I•já§;È‡#1×ö$Õ¹ `ÆfÊõ¦÷ëá÷vÙh™­6wSË©˜şëüa1ZP”’B¾Ç-S‘¼:v+Ñİ\W”“àn*uš›œ;VTúãé­7ŒrÕÇ®v
ç?jO~oå‹ütràë‹Ö.ºIí³^	DI#õg¥rPlÜØ%%Úë²–N²YÓ³Ï|ªßÙpeàPW?ïLáŞ£óxf¶êóã%t"Íó²t/;æ8ê&¾f9[ÚãXak¤¥                ş‡¾åÒ	 x  