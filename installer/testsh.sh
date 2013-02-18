#!/bin/sh
# This script was generated using Makeself 2.1.5

CRCsum="118144030"
MD5="00000000000000000000000000000000"
TMPROOT=${TMPDIR:=/tmp}

label="testsh"
script="./startup.sh"
scriptargs=""
targetdir="new"
filesizes="7809"
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
	echo Uncompressed size: 12 KB
	echo Compression: gzip
	echo Date of packaging: Mon Feb 18 15:23:05 CST 2013
	echo Built with Makeself version 2.1.5 on darwin11
	echo Build command was: "./makeself-2.1.5/makeself.sh \\
    \"testmakeself/new\" \\
    \"testsh.sh\" \\
    \"testsh\" \\
    \"./startup.sh\""
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
	echo archdirname=\"new\"
	echo KEEP=n
	echo COMPRESS=gzip
	echo filesizes=\"$filesizes\"
	echo CRCsum=\"$CRCsum\"
	echo MD5sum=\"$MD5\"
	echo OLDUSIZE=12
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
	MS_Printf "About to extract 12 KB in $tmpdir ... Proceed ? [Y/n] "
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
if test $leftspace -lt 12; then
    echo
    echo "Not enough space left in "`dirname $tmpdir`" ($leftspace KB) to decompress $0 (12 KB)" >&2
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
‹ ¹›"QíšTSÙöğC‡Ğ¥WC©¡@ÒKèE%Ğ{"HSé½*]ED:Ši¢Ò”.•öÇ™qfŞÌû¯o­÷¾õ}‹_Ö]'÷ÜsöÙûìsnöÎ½ü`ÀqQQĞ÷Rì—R@Hä—ò A!AAQAQQ€ °˜˜ $
ø/àéîCŸªâsA a×=`î04Êñçv§ÍììşÙÈ3;~+ÿ,‡¶q@xÁùı®ÿ9ÿ‹‰ˆüÿÅDÄD~ø_@DHPôÔÿb§Õ À¹ÿÿãè¨caSğO?óÑ²?_È zJrŠšJü>ÆD }?VİØXwí]J@<ôr
BÖzÀƒë:MgÙ*‹Ávæ¦EW‹Q:ı”Çå[ió_>{G¦dtç> Í	Øş811{]Z~¥T\ôY¾UnÂ‰g§M8?îxr”…½³Ë[Œ”ògŞ/{¶':Ø./¦ŠÓ‚eı£Å €„¸èœRDåkn¡€ò€”zÿºKr­2#«°‡×S„´Å.wjòõAF¸Ï!ÆA¥óŞzÌĞN1j–t\ŠêÁ5zŠa	7+c¶OÑï¸ß¬¶lÑ@.ÆË´ÓåÜ·Ê†²™—lÓña+xuÓƒ°=n¦ÎƒTıwô6Å®Ñ%^e’¸$;&’Ğ½uÕ“·óŞ¡şÿk7ØÅ¤í	ÖëD]ºxÍ3kŞ‘7Y½øœEf†±`Í(ÉÖoI«Æğ…JXwM…ÕÊ	Î•°ì>¯0*TÉ0Í©b(ˆŞÓXG®ß¹*î½İ³WIÀ$™{ë¦z*]×:´Ş{«!‰£ØÍ[C5EëÈ¼ğGwÌj#ÅqTƒ¨ö‡‡À>ÊWÍ|zyb½C,„IBu#1‘úHKvíåW7+áy/¼=Sù.è²'Ù¡iëuÓßJg)…e?ÊK\r)$¬2vı†Š„‡sİñ³.“ÀÉ¥nÌyÓ‰>ÚY¯°]Ÿ³²‚®Ó‹Ú¿
æ’0±éƒ¶êï¢å£®g6¼Æ>.>«šÆ„°@j‘Õ‘WfWãØÉ†]õ´ú3Šp1³$9ÆÊŞíï¾Ø¢f—>ıq‚§Èú¥²ôC¸T6¸mşX†Û»-—Ë¦å›–Ê-ÊuSzŠK$Z_,,Xôœõ46Ih4QÂcØ!ğü8MT¡#s’_E c,:´‚ıú¸ìğÎš¸“<DÏ~¥<Å7j^·Y´áJÛ•Ù;ûŞ1/¬w!Ù™ïµ"èÓ¬'CGİmÜåMbõïÂ´úŠÌ²´/]\˜†¤=¿YO›%Ä¡åSäc\œ	z4kbş±GFÿ±ÕxŠ¬		®“â%'F­íõ^}Ø¯ÌÅ'Qó¦,RÈ^SmÍæ½É{µµV38eÃ_]ÈËá£ü\f$ë;Şx”´ÑƒÍK°MÓUÓŠ—'¬Hó Æ¼ß¯ÀO4ğ-çë.¸ÿÌke Xœæ=‡@phßìÌ)~£Æ•µìœÃm©Şu<|ï=» , €ïŸö0ñéÖw…¹h Ğ¶ü0/ØÙ6ş}×›ø£ÉO®g‡µb.-¿N] ¼le©ÏÄ„èêÇtø<~+5ùx>r>ËCtgZJ8€w¿.i¨ƒüBö­Lº—sâ¤z]]«‡[ó_ß7^½ÿ /ËU_ºo;æ47÷dfáƒ­ıÃÏ–î»O7ä¡õx¤jR¤7M÷É°üïX#wÍcû^Êûß`½1|bt]2kk‚^€“X{¥˜
2éËô#Ş,™Š™u¾©,4,½kFèU•:—º=¤ö*°>M,š¦l¶•Ét=‚ãG£k4^ŒIåD 4œŠ–>­Ú¸ÇÚd=[Ít‡o8r×©[_¡‘2ƒ?+D»
Ê™ÂCwğò¡hE™¥ü “ı}Yæƒvğ3m6³\ÎñMÁR…§+‘A]Ò"+v|å¢•Ğg%Å.¤lP>'9Ex×¾(…¯î|/µãkÁ²8ãhú†Eškã‘áİ¡!¡ı’áïÄòÄÛÃ*AšK%›-±Iİ;X¬•d÷ºŒùœá¶¡ÂÓ¡ì+&dG@V@Ç$¾äµäÉœ+Eá	Õ ZŞ°‚oĞµ°T1Ü¶Ï7ø^¤£Ø+ŞUÜ°¿!`ãj&çÂr¥ÍPSØéùSj—xx,ˆ¿–ù²òKøùz¹vw¿›8€ÓkÉ"
v„Ñ Ùx“%c:Ç5‚)<“hØœaö^bı²ÔÌeà¡¿/şœĞPm-“æs™Ğe^ı”ö¼br*Ô_ùóJÅ²yÇrÈ”ª1ŒXZ‘@ ¡¿ìE1“5×ï¦õT©ÓıÏôtÇÕµ&q9}Hr¤€#ô#G ÄÆéÏ:wL~ıÍØgvŒ†W¡ô²y¤™*ºì:îìöğ°aã·ãQ¦gåDşdU˜)ü%W1œZ¸¸Z~ºßÅw¨Ü÷Î1ç;ûÔ¤°0/½^fL”Njt¡/9¼@SÙ³[ë8HÖOƒº87¤±±Ñ£§l¾Ä*a{…–`öö'‹ì™‡Œ_…?õØy0n-ÅI3^
Jêö½s?Nì«~Oó¡"Ú#È´ ğCÁƒV5’¢›Lø¬Y#Nú\yelcCH{§vøx8}°ŸªÜ<àëJêô[ÏxBkf‚øX—l´Tåš…âHR—]ÄRid‹÷Ü\1yb«´Ö5¿şqıéŞÅ±±Â’(œqõ£¬i›»JoZÖLI]˜âç*nL`9yFÄ	ÜÂÔÛÅÚ™ukc¾ ¦/&–ƒÏÑĞeH¾Á‡×%y¬+ %kÊ<#gRL$­ ®Ææi2!~Bèj Íúø•,ó}…•Rˆ#XE’<IMmÂ÷P6±|ÓÃ,	çÌU
ã"ñÍíã]yªcGq2`| iùLëÖ«cA‘x¼ã;D¡6[ZP»4¼Z7ÒŠZÉ)è7ä¿|ô7+øšõ˜áş	ÆŒé6gÄX·€od•€¼VIBÁ0´¶Í¦†£º·ZV¬‚cÚk¶Õ¨ºï£ïÌŒª–s¢Kü¸Ã}ãuõ	ù-ÆRğ:Çİ•v[’à#Ò~	ío/ö¶Yíãbğ`zÍr áîD a¦{6­EµTbzWµÜØ,À{sÀ…ãP#ÕÓWW¾“Û› ìª¥œ%§Lôè›v[“³¥¶·-˜8ª*Z¥v«D‹,×¶Y,F îålÆb·1?I¼“ÄÎ=ˆeÚ¾LâÂÁ%—‹èOJdLá­œziK0÷¹£ÜĞ•4ït/5PûÈ¢'D§³ßf€0¯€7.O½Â¸ÉÚı®n97¬}£V€­ÈmónO¬Ò#@;¥×ˆ|ŒñE£um)ÓÎ}$•îÃú‰W9©lŸËø¶“¾”j*³˜¨V$³;¹g6i?º)İ„qª‘¨¯”>¦–¡aÊoaCŞhS»ù–eÙ«ÃØ!X¤.}ìÛ—Üú2ƒãk?f-ı/½
ÇXY;ªY·JµıI®ì¿îl½Z 9‡!–R¸f†/õ’•œİ}¼]ë­²ã{A&ûiß—×Ë_eóc/-o‡‹7‡œ,öÑ=)T-	D¨ °0J]-^8–=ÏÀ©ü Œ‹1~=bTù2e?¯Ç‘Kıqôë…—ïËğ¢²|1§ŞZ&™›ó}èvëŠÑ@E‰Aë—pT»„IƒKdÓ"Â¯4a™ê*uÛi›pĞƒœÆ	™QKˆeoŸ·ÏŞª¤>›vĞ±.º¸…OJm!Fnhë‰{ÓñZşq$É¢Í…ÅxªÒoŸa¼v][«OÕB&Ö…ÑLÂL9Bë0š«!•Ó¤£Ê}ôJ.ŠõmpéÇìÔ´ã&ØÓO˜YÉÚi,7ÖSi¦”!—µáí°§Ê¶ õº]‰Å¾UÁªzCÜe3É”y^X¼í=‘—Ïæ#ñ¾C’+Âá¢\¶¤VñJšòJWa·}—vàú·}Œõd(úˆ­×’E>HÃøò¢Ú§lÑñë“É£¯›Ù/ ¬ŸD_èjÏï­+{7Qøu†´¿ÿ.š3ğMÿA…o¿=ê²‰Wæ› ¯bÑì.Ä²\±æÑPÉ[{)’i·ôtït¿!ÄÕ Ef‘Ìãá”çdÜË;
cnµJ‡Y_;TÓgÃUæŒ2î,duz'á7e–ú4:ÕÊ÷D³ä|Kxş"WÌt7W`‘4—,ƒf÷UùŠEh4Ån·Ê6ã}lûúk1PğÆàmViÿA¯}zJæ¥
9p¥ô¯M&´-Éök¨q:Ÿ9ìZ¦DæïãõÍ¾¨Wnö½¼âCº×j&h)(±Ú±ã,$ÈAÎî(ßñÂšz.wz0_p#eb—d ÄÍ&k ám§æJ‡Û‰Ã"TÑÃÀHËàûµ#Ò³ ¨ùö!´ ¸ÃğK üğp¹êÉÿ œ@×¯kÊ)hëƒÏ‚ŸøÓàçì8~ş>n¢ı¹ÿõ¡l¬¨lì­¬­6457H£uB0i±8É06e@¸›WÈpäÃr4oÑÉ2†E³ğ§gf—ß1ÖIL.32N7N¹k”tïN¯N	ÊÊÊÊÁÅÑÁÖÁ:ÉÎn-+;;+™^fû!S7%;ÃÑÅjÕyÕnÑ.×iÉÎ*ÇÉzıcÁŠ­İL…“İG[;¤³µ­Ãü2KH’©BŸ4/p6MÔp}ùôS‹6şëyZüqšÏâDOk„Ço&%{Z¿LÔ(ı‘û°äÖ§j²,.ˆÂ²H[ËŒio‹fÊŠ“¿æ#oqa]gQÁOã2êÈ%¹“}³k<f5÷ëfÖ?~	íZw|Zwİ«¥¿V>¼“ëFİÂU]eü,OX™ÍpÙ±¾÷ãi n¡¤Ğh6Çq:¦¯1ï0™œ”âRºqìO{É¯WqciµÄ}¤®OİĞ3»!®¥–Ê¼ÁÁèÎpØ	)vßËæ7lc´O2_åÜ&b¦é£ÒKaÕ
;ÊËiTqKN™îcğ•PŸMŒ XÈÔè¢ŸêT&Hşú"e¾,
%1ÁÆõ˜etK|öˆï`íğ3çf¶4ºqJR¤şæèÏ†óôõóäêZ«9ÓêÅ¢°“ÜWqßÚT«Å-„ñ…WPÊ‘D(&}K·vM¥Rç@¡>»77Fõ³$órª5áaûµw°½ïAÜ l6WÙ42Œ´·MV7GÉRO$MÛ¾¸Ê?×ıyÿ éY–VGw¬ó=ÂR©VË ¥CÁÍÙE(Æ×îš1yÖ“ş;ÑŒEc
%5Ô êm0cJŸ˜¦MŸ+ÍP{~I_œªTÉÒ“hS}p4’ÉÉé&°‡°°ní]H{ù"ì
G~Ğ¶q”}¡áK¹Œù"õÔ,ù8ğÛ½ÙŞz©¹ÉÎÌÅÅt@ùĞì CÉ‘oÃ‰~­“*_b×Jq’ÄKiK^Cï©šbö„4¦^“<–ˆq`bİßòùåÎ#9ì m‰¬G›mü—¥ú{ÃjÃ’@øÑÅL;(5?;{™·ç0ğXtıš·xqó*µ Nñ}Õ(¹ú–œxb×ˆv¼g^•ã
THÆJ¯†(ßK´¹ÑÎk•…=ÀFŞ’7
gDÒáésC¯LŒe®‡±sª÷5Ãq4Ùó5L^mV…¿`Ï*¦ì.Û$AAUáÊZu¯* Cnhİ:¢š¯ÒvU¢
1“ëM¿ODc!À†i× ›-Úm1´åDóÖ}m]Oø 3S€¦áı;YÖÅ¡4vc,¬ƒ«YÏ„•Õµ¿)
PÂXÑpV€ÁTW4<ª >ËU8:’cû€ÖA(U>•‚H§ê8Äµ‰‘E¿|«'Úhª‡q²¤f–)XR’Õ~®g©gÓvut¯Y\İ¡êŠ”¾lÓ¡ææ%<•TşËÁ¢Ã1PÂ¯NË‘šœemtÌæŠ^€ Ş£ }å¸5?Š‹İeèo$_ï÷D')²`?²S
ğTGÊÅD€’1Åmî	hÓŞxÌc&ÿ‰2´™ ŒAHÈ-bJ¥c£%2=Ë»ğ0ºÚd°šµƒ²ˆX¥aÇ}Qõ¥›G¼	>G¾Ë’Î(Yú<azš:ˆİ\Ê˜rûJn£®+CD)-yUíèí§!‰4ŞVw”lÑù@Yî4€Ê¥­‚·'oQÇ wºÏ'õkFoC¡'ˆ±ê×â¬Ş”0)!)ä•)uE^÷dL™ŞIÂ v½X¢°6%²{IÂ‚94Ë¤A¥Ê?r	°´†îŸÖ…zŸÔğ&E¢©åçì!P+«$£DªmÍ|ÌáôOuÒ““ï˜‰ğ4˜R]©)ÅŞÇÁ=NÇ˜‡¹“R!êèÃ+	‰½zt<µÛ¶¨9q!$¹ÃN´…óÊX9Ğ1s(7ˆí}û<7Ì9KN^3—‡ c‹ù„Õîş™”‡“«
–á#åt†ºk<ïñ9Êœl[†SÌŠ]oŒg™^datìJUàØÓ|äøŒZ»ÕwˆËªÁu—/×‚Ÿ5~S…qå1Üß.ÙTw›Ó{“M+6mHMJ·ÇÕ<V{»91Ñ3±S[òœ__:cÏá¾+†˜ş¥F¦œXõ†şš²P·[hÇ­\§·­§OøÓ´o;M<£7˜É»%:tÀ¾Xj{]¼¢äP2â3«hkÛ½=CGê$¿†)Ë§³³cªRJDÀRbpJç¤ä»‘‡‡kZ6ïw™dŒŞvùÄƒTÆ¨n§7‰n”¼1‰º†ñ¡BC¿–Z”"š{eŸèá7ŸBD[?ˆb£ÑmÆ_N ®$çy´…Ñ†1æã+W6@à‡Ÿ-àt”zâëªŠéÄ¯ Ìå‹*G1ïëZc‡ï‚Û®Æ^
§rÿØ¹Åx}s‚
¥TüjæE=JMÓuL<“.Ìôvjô*zv²èp¤!— ÕeŸ<ú€IBíNş®fÇíğÉÑô4Ä(ßDïN%ëÌĞùÔ€2¾hÍ€ø`…¿İ”d‘W ÷¬×#$`İ˜9]èøŒ)Ş!*ØÊ^Ï	æ)¨ŒÉ¯w|™£Õ&Ô€œ™K™éÀtşÜÇªĞÆŸÏf3¾-$ƒ.÷3èÃN\5¡çâU8Ğ:‘Â’Ü>fH¾8¸uò@lÖ…[KµZ™÷ÆëD”"5¯».=Å«ĞA[ìk2Ó"é‡KÜP6ªK|áùRO¯—–Tõ½]µeï0õâÈ´€Ô©ù«^y9XºÔ¤ÚóeÂ	?n~ÓÆúm•»á Dõv]§E2„ÖË©nJ:-ù¡m	v Æ*H7 ä!ÈhyÒ¥ËÌİåç4ı'nÇ'†ï”‹Gè=¤
Úöú(DGèy.ÔÄÜˆÜÀÔ`&]îù¨ÄÛE_„åä#Pf¶h/eQ]éíí®É'‹‹­ZÀ“ÒiŒ$¦D}“ØuÜ’İ´µˆÕ¤¹‹à¬M”_º±Ÿx”yKßk™·¦{6ñvìë7v"Ó,û:ë®ÜW*Ğ6Ë	…V’¿é·SRuj½°qÿYqQn5Y8s3	Ìñi3>¤h*ìóÀz¼kÖrNrÆ–xÎHÊ¯’öe³.QöLó 8&$ÃO¿Ås!é¹'­ßçJ<ÔÙ2'*ë¨»§.Z!©/¼æ]„Ã(Mhòôt>ZZ–•º)°1/NoÆ—ºM¢¼§÷ñSV‰ĞÆ¤ßES…Ó—"ØuJúº#åîe·ÉŒESê‰GÜ¡[¦Ã8kj·<·2ÓÓdğ(:`~¯_ö8â	¡GÇş¼yiP<¥ƒâÅÑ•@ÉàÆİ!…Iêø.O†@®İà9ÕÛí>¹ñB.lÔş(g¨ÁkZ‡zudİö¶vÓ­ª—¼%ÜµÍÎp‡ÑËñÀ&+—#^­aCîÆP¨ÍÊêŞªnÊ¶èi“d½Üf7¼Er7Ôo£õUöÓ¹L*	‘è›·ª»û:«¤€!ÂkÏdÛ€‹ïûû5e¿½ºõ(p…›ƒØéø’©j!¢ŞŒëjÛn(Öƒr$2zQ¸úØe¶`Ò›È‚Etš\AY&dO¢¹q¹ÚŞ°³6›D>àÌ4½Š%¡ÀñP`4]fé‘çP_)/_y·š_yÑìãÙÅ®ÊîøŠÊŒn÷ q¡Ç`¢eUé¤ü¸È}èU ¤dÅG<.²²şÆƒîºÅëİy¤Á”G§@ş/:…©::¦ö„`HG³í2ÆkÉ'v)µ×-?„"Nr=àf'V““2ûƒUú%7wVÖ¦Y,áóÔ•ì1î¬÷#µNH‡ıîË¥:Ò–gˆ8ùê_ïò’›R5¸jz}xŒùA¢ónÔhö%ÙñÖ—™Cñƒ=¶7¾¿N ?Ou[°7¢[	¨ßqÜ½gVùf¼âÊ¶k:q±ÏX^àİwôÁLÔ°~u×—‹uWµ¬ïè|Ö¶.ôÒÔu+?í$ Ø	’CıFcWüúÇ˜œD‡0›ïŒ¾–4-Úÿ¾şN¦Ø%ƒŞÕó]cG¬ñ•¥ÓÁ¿È{Üc<‰y”üş^ÏhîíûOxù¢¶+éL”-JM+%C$›diµH/]ÜkT†¸
p›íNš1õ‘“[ÛàìÕ#9ŸKÄ—xFF/suë)ŒgK•0«8ZõQ¤øb÷îC‡İyh÷[µ“+zÍä^s6|Ì’skOV]® HŠ	7M¨vËÑ“#y-¶?çCÕÍôt†D#¨Xcvà.®­và 6{Ò”÷¡ÕÚ½š0±^m}’+ãˆ×¾ëËÚƒÜZºzw"Ó+ÅõŸİ/4¬ƒ8`…*·W•ÖÜ#ÆÚ!c7¤a¤=^×@)­?V	¯è²c{&qÄùâŠ¿¤jÃäû8®0•òåMVşS·ğæègÀUÿ·oÆÇce1-=©«D À	÷?e1ÔÊÚş>¡ùûœÍƒ,üKyè]–QÖ°+A˜œäG€àÕôÊM>è *Kk99­2KUG¥›N–è 5;KI!‘Í±öÉÁñîÁ·CíØß“¯Ù©W6§Š•O¾00©°~O7ş úÕÙ‚Ğ³âçoø¿=xû³ŒŸs`â?Èè8•ü§¬ÿ·¬õ1—0ÿ.æHîÅéÉOé3şoéóŸ5ù9Í¤ıƒ&‡?‹øK*ıg¥~wìÏ.'üƒÄUbÀ“Uüß|ûg!?;€úBjè»V~–‡ƒ{Ö÷ôS   ÿŸÁjüÙpOW~w‡ÿ;ï‰
ÿöş‡˜ØÙûb‚"¢çÏÿÿ+àPã0 M˜H[dúÁYİéÍ  :=|OÌÛ U2†²èÙüÃZ‘ƒBõ~|=ë‘yzş©	Æïõ46(~˜««3œ
÷ñPBÚ lHûÓ‹Pe>ˆ” °ˆ ¸DpÎbÿÿ§wÿ¿İÿ‚b‚Úÿ¢âBbçûÿ¿Ø[Ÿš*èé)iA¥­\½m­€@E%}¨4+»ª¶¦+ğšÖõ_ÎY@¸
Äş£õ/§@ ·Âò@{Â¥@¶(àÙM‡Ù‚ø\A¬Š(/Êäpw y @äél:;ƒ<î W4Ês¹Ê
òE~ïes‡ƒØ}‘§Í€¿ŞÌL|-¸A\ ß*~å»*¬:¿È8àTª5ü×à¶§ß@ìgzƒaH[4
abı;Îğ³qáH8úT18Èæá ²C¡&ù×ßíû11¹ø¯Çaÿ_7GØÌ@|§
ÿÚ…dñ—F§Š"ÿRyÊwWıíXpçSKÿU·_¦B†Ûx Ğ¾§~„»ƒ(ÜáîÁÏú×NvˆoÉuô³Xÿ—ÓÅ
=óÄ¿õî¿ğê_ZŸºËIJê÷5¥…ü¾¦Nmóø©ú{ÕÏK†t÷>]¾§Sqº(~Ö­áî0 -
	]œlè_t=‘~W÷Ù•güQ‹vñıhş5òAç?AçœsÎ9çœsÎ9çœsÎ9çœsÎ9çœsÎ9çœsÎ9çœsÎ9çœsÎ9çœsÎÿ!ÿx7K P  