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
� �#Q�<�w�8����³̤�:M[`^K9�):����,����n�$��Zv?�����$ˎ�2���}g2�������+�w�V����C��?~��~�ϝ�j���xu���ѝ����Շw��;��S�<Ȅ���i���n��������g�v��*�����>O�k����?^[���Q俺����X�S�_��V�p!E�%�PE>��<P�@d�E�ɩ�s%FI&΋0��X�PdE���0��@\Y(�k��D�$��8L�D�b�L�(9�O�,G����Q�Z��@�
�He]�0D͆}PI��B�#��>��d0�0�"���R��4��h ��'�*�YD"
ϳ ���p0�R
�'��2$C)��"clJ�I,�%�@
%c�
�H���Bf�bf���5%�T��P�� �&.�죂q�bvr�,�Da�x�q�~�@�G)SD
���4�p���	(	�k��eI��It���r|x��ɈD0�������������ݍvM	|��Ar�ŧi $� ��j��� CP�A�"��	H�ȑ�_�$b��]�L�H�#��O����b��0�d���$EvAx)R�@�$�&�" �{!c��G�&I���$�Qh��U�rd�k^�b�ޢ�` =��yz]w��Ȓ$��J@S ������(��iO�p�h�ᜅ� ��/�d�(Ɇ�q�h�0Ш�Q&��5z�	l���D��{� z`B����p��'��C� �$�(Y@�0<{ƶ�uQ9��GP�"#�GQŰ��$��RŬV�Y1�iO���� ��8F��V�Uy��5Ђ�p����iFԊ�#����Ib�D8�v��.��TS�IRDC�J�!�M�P�`�`���>�b��d�}Y��@;E���4�	�-�J�ƨ̿��#�7��`�1K��п�$�p��ի�gb� lq�-�A@��	��M�MQ�.�.��(�D=�����5ޚM�m�%S�jf���D��#<��2˃Tx���Ĳ�/⾏����%��G��ֈ����1бt� -�0���DO�����K���l�蘹��{��~��:�;��?~�p�������V����ڟ�߷��zb縿�.^��F�c9��"#?�cy��ߜ���>��j��βຩc�<�9}ǲ��e�&3=a�����2OvIvq�S�-D�>�%�a/�� CLL���S*��L$���	�ϣ)�d�T�T�d)'�cS��J!ea1K� ���$�".��1�P�W�W̖r1	p�LJƀ)��J�6�	>�� �b�0�C�u�I���y�^\��)���!�����T�AFπ�sVI#7���"<��¼Գ�.���2@P@�	r;�i&!��[���YdQ��TR��P�A����s��x�IW �{J��Q�Nk�K	|,R)�A �A�a�dd�r\��z9��I��p!�V�0'e�Q=�[�Z��5���9�dA�G��}�	C~^�:�cf�� ļ�ԉ"k� q��=IgI|�ij�M�uf�Ha|�łj�x�U�T��Rm9��8�"OP�0��6�)��*�=��D�HJ39Q�U��-���>܁q�%���T�b,��RdF&!��K��9�8ഞ9�EjX��t���Ow�9�%j�?�dT���I�i�`���$�=OǬ�׈V:K��������g�Y��5{.�Y��>;%�����}K��@��':*�LB�� �P'�`�'I�2��̔;���G��p�06�w��-�Rb�r@��gf\�J�sg$F���93���,�2U���U��<���V�@x���{���>9�����dȻW�4�u�X�!�)����3�=�p����z�GL������������uNO/,��_�������!��١���Q/.���"_m�&9�E5�
�qZ@,.3�!�59i�.9�\ �1�*;��7#þ�?):�Ο6r�d�`��s!�8�v;�aa��g������s]��#�3=�VL�l���0�=�3�_�\�F2��#�v�7&����������R�l�B�}!� ��^�_� ��a4��[r�F]a����,5��C��`[qE���\��BU�)����v���)8�xX�!�b�䏳�H;}tl�Oh=�i��H7��֙�of���V"�tui�%w�a�6���͌�B>�ĉ��G�������@rN�Dy����1 �xvmǁ��d���
sX�끴J�6�g�tm�n�.�a�느����Ja��*��$hd%�@ �QmOK�_7X	��8�6e[d$�B�y��c�e��T5m$Y�A�����*2�]|����-���� ��jEe*�ؐh4mMo��cӏ�%G�\�ێ���M*��uؑ���B�k�9�u_F��KgpؚQ-�Z����m ru!�	`�MW��Ulx���*uL����DI0|���!n�E�f��o�/W�[���ic�D�3��G��5�3N  �4�cN�h�b���߭�u黯�WϜ��F�9�g~m����f�uK��v���ZJ��&)�6�5��tt�kB%�1H�y#_�8�1�,�����#�JR�ș[t;PǄ[;0e٣��(t(Ԡ*@��f�	�[����!|�	������S��q���4�#*M��!��c�˄UN��I��dPI�� �0$c~�9LB�*)�.8�|l{�D�yx��#z:�VBH@�8��YQ]$���$����)(a�6�#��,	�=t��to�-Y86�D���&���bD��V���<L�*C)H�9�;^I�
���=�7= �d�)��-�?���� ����U���{��S��Ğ�����С-��d���i���W&+�Sw�c��H�z՛��>[,#��4����l�̳�"�='c�1m�ř6�2L��2�ʗQ������f�ŷ2��xʹ��3-��Lk����N<���-6K)<F�:�����f|S�B��,ֱ��R��8�L�Δ��c�Wf�v��sh@@�dSү�w�_qrL�4��!:��r�B�;d��e��ַA��MWֱ9_�����I�ُd<��Aj�:#%�e%����in�n��Y�{X�S��y�5fL+��ɢ�����4vu\�*�����2 �h�)7���:�����ԄO�����7<�/@'���������#���_����[|���;��9��v{��������?���?�m9�$�ËJ��0C�>/�!��`�oT6��=�k����̣U-h�����������n�v�c�����l����}����h����->�[��̥���3ӵ����2�΃( 3}�T��o�0��aO��h��"o,�hu�.]���t�\���4,��cY�tba��b0َ�	<N�sVq��n�]J��i���͙���3S�͟������������fm VP�����>��[zf���ĝ�8�cȇhNڮ�Zy0c���G���:���4�\'QA��Z��_��-ͧ�{%�A��=�c���$S�ס߇x@���V�ɀe@�5Ms$s�Vsǻ��k�����$3ͭ����]�_�;�@��r�{��LԷ欛;[-D�{�
��j&���>&�� u׀ky�����/է��|\�;��@b�Մr
� ����dƯ���-�L<d��Z+��~Ou3�ֱ���%��piV��+C���WJeG��XC��H���A5�V�L�,������=0^�gÍ4S��u���Cu�=�1@������Ҏ��C���	_Oj������n9�SU)��vB�#7�
!q�L���.#M����A�i~���ؙ`N�%I��];��px7���eu�r&��He��Y|)iZc����8��F=a�� ӯ�(������Aq���ꎜ��A	���[ڝ7p�n�T�{��>�Eud�%�TX>Ƨ�q53�5ӷ����;)AW�k	���@R+>��r2�֥�I�����ׇǻ^)�[�S幑��K��)PTTA�UzI6���_gU�Y�*0�\�l�v��kԾ�;��qY6�o��X�0����]P�<_(�ρ7*�7t�-�E� �%��C��7]T[V2溡�d=��(6*k��E<H!ת�7J�_A��z�z�� .�����[9U� �:A�o��m{eR�Tcib#9�6�������h���;�\
U�D^����O�j�Tzp@6���v�n���B��_0����4�A���`� ȝz������:���^'vl6�����"�j̙�y�6z=�Gl���d�^��� MU��ۤ^y��g�z͓����32F30�6�%f����$����l�rq�Q��X���a6���Q��fIܽA�����m���ex<E��� �2"C�"l?���ˢsA�r��n��M?����n�a�x�D��n��͆T-�A�U�L?� �S�\q�
�����&J�s7l����iHy�������/a:7p�=$ɫ�@�8�e��.�Sr�׭C#*�H]Q��l.�Nͭ�H��5���U3�t�7(����25g=��ގ�b�R&��H(���%���\*������Y��9���v�-�!ͪE5�<k) �7���� =���u�G�S�*�_���䍒���k/zN� ݪ�h�һ���a��,_��Z�Ū$~a�l��x��i�u-�D���n9�~k�G�����=x�+^���=:���8--Q���9�a�⤸ى�3I!�lFQ۴=)�̙�]��a��4KX��M��3�_)��Q&�ӎ?��T�t\��T�p@3�4����-t�Tt:�j�P�u���S.�C����\X���������W�ѹaK�|1{���j.p,���k�s�X�pO����D�-�H��.�u�,�ʼ���
u.;�M�̛բS]q��ZϞ�c�%��5�
jJ��Ex�y@������m�1�U�_�G�c���o��<o���)2]s���j����`����>͔�����;y�-+��B,k�`�j�&���S8*�̘,z�`Tt!=zg
�N1�6�;;�=]m���a^�7]�yr!``͞W)��i�[�K?�$�@�w��{óq��ғ���$��f.��wi3G��[�J����to��[NUX��|hPvk��U3']Y��k�{�)�V���I�_�C0���@�|�S��8�����H_~G����I�Vn��1��Y���͑�pM�vd�~V����}�IO��ƖWU9�������������2-�0Wy�p&���0{"��qf;�j9hǔ9�5������:js���=�X�^��DWy�c$�v4{�7'ϗ�4n���6�=���
��J[�;����L���L ����©WB����c�g������|n<��QjJŴg�u�&t�*v�P���c���ˋ�n����S��3{/��W}R@��A�w|"~��嚽 p+�T{�#���Ϫ��6��-ʔ�M_������`@�l�Z.���n|�J%�@}h���
Ī�!�"�Y�A��/X���"�G-��m�?�/�����x�5g��Lb鬬
iW��t�͍���q�sk�U�l�ꙫ���:�΅�nu�T>�0��ֵmY?^��5?�ka��m}��ˬOt]�Y�7V��]lMY ZD�y��u��,]�\����l�,�[p�!�x�E��z,$a��2�9�������^FPbM-{���o7�g�Z���Y���/�5^�c>/�4����g�����;���C�7��~6���[����V�ղ���اc�ή�r�҆��%.�l*��^n�#��N/�$Ȓ�Oa�I���s�cnw,��Э���J�������Zp��/��V�Z�W�f���^ZR����I~c$�I���e =��Q�k&����WA���A��E뢋K�ju�ZС����M�Uq��(�]j.5��\[m�j)up�a����A�^�&���B֕��6~[^""o~��<��g����I�j�;��#1��$չ�`�f�������v�h��6wS˩����a1ZP��B��-S��:v+��\W���n*u���;VT���7�r�Ǯv
�?jO~o��tr���.��I�^	DI#�g�rPl��%%����N�Yӳ�|���pe��PW?�L�ޣ�xf����%t"��t/;��8�&�f9[��Xak��                �����	 x  