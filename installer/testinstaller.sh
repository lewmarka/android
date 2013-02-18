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
� ��"Q�wX�Ͷ�C�ХWC�N���T��A	  	��{�"HSA�wA��"��JS�tT����o�o��?��{�_�'�μ3kʚYk�!0�ߎ�%RR?C)	�?������|� �$ �x�{�� ��@��y����Q��?����*���oԿ���?ӿ���@XTTRLBJBD�2]DTJ�R������`� �`��#�ld`����v���UT�r�z:�����w~���p[G��ܿF�@oG�]8��	�١��K�p�H�Į���<A�wG�
�@^�ݻ G�;��r@�\n��|�������A����l��ba�k�����;�4��֯2.+��j�������g��0�����3w�?�#=��ˆ�A�0G�=
��0�������_^��z8���� ��e�/���K�ˆ"��x�/���u��^���u(Th��
�{�G�;�� �}�B�-d���=�m�Y����b���Ŀ��?��_�\��YV�osJ�˜��ǟ�I��!ݽ/���P\�$J����pw�-����.�v��m=�~W����K���v	��|玎����)���[��˥V������`�����J������R������z����ODBB�o��U��������������K_����+�m^����	�����_X�������ni��R_���� �[�G�8  '  P TUtT�<|<�LI �~��qq�z�XԀh'rB�~�:O��]��&1�=��6��9����߾zG�>)�˭!���<�9�xGNi�TJb�"�P�&?�³�6\:%����{���N�7��3�<�iR�`�I( 1~�VLN)���h@y@j���mJ�2��ws���.��A&�� �A�����IZ�|��-F�1i7k�s��/1x�'7��� W�r�����rX��3�*�y�1�p=�-�4DV�v%o2$�`���0��ֿ�S����'�����rD�.}F�O�>P�X���Ea��b�,�1t�^�����6����+7s��|�¤P=�<���,�X{������~�Q%_�L��{ZiB���r�k���dN����qm#�=�9i�W�ӌ��jO���o[��$Fو�E�c�����9����ޫ����XM�bșl��o��0~/�I���,/iͥ��r���**�u'��!�S�F.y3H<;X	o��^V���n3J8��6�ퟂ���md5
��9-���΂�Bn�՝Wf���Á[����+�x�IIJ���#��}�M�&>c����5�Z�l6	�m�\�ϻ#�׶�퇮�}�mq2sF�kNd�߬����h��!�ŦpC���:�B'�d�� �8&th�i���-)g%���Fy�o��~�D������c�_�B��|ԍ`L���p�uW2�3@|�:U.�,�һvue���^#}�(��O}��ir!�٢���~y-���ө
fd��*ל�u��ak�W_D/���"7<�]��tZ�f�7����O${%/w\��k����<x�Y�N?AH� �>]o];AN��
]��xHY�d�G&��C��'���p��G.������sB&�[�9����f[�B���L  ��5t��h��vBN0/��e�e�h�bn����֎���.m����,ʐ�ѿED�'���������,��yY� ����n�+���0�Y�"7���<�[��q���Ӛ�,oTc�ݔ��4����Ov��W�W:�Ξ��7��e�O�Dd�w�͏)�p�� -�S�^jV�?`3�F�͒��[["^�����r5�b�,�J�C��5sI�����Bs��G�^UiKi���o�%c���Y̷#�~p5�6A$Y�/�Aci�a��G�-6��,Ǣ�+q�����8�pB���ܩ�'oj%z��)n+�8<U`=�w�qX��pO*�܈
�߰,���vB�Tz�
A�F�0��i|ת,����i��Èj(�Mc��V�nNG5��E���6Ʉ�̓�
�鬕��%��WR<�5���\���̇rn�5S��ݳ�27Sf�s��'B6���
�L��`i��_#_g�8+>TDڄG
ۺZ(���]�0��scy���%A8A�k���VG~�]��7��!��Z����au�4�c˜�q�`�/$�d�fZ|���]����.���׳輒]0L��'(�4�A�	�OZV��P,;��@�4�a�r*� "#��B�Ґ{��K��O�Gr�ݣ֯5[�=�(��N�s�t~a�?+�L�)��S��):&X|����V���;��R��S���߁G���3�M1�@�7�y�p
h��f=��i����_�<���K��¼�F�)	ى����5�>�� ?m�v�Ҩ��NK�������uz��_��j���&�|��`�;[��c*�.�����i��w���S�G�yAূ�vM��{Wkf|����g���vq��!�s���>��/���&��m?~Ag� ��ؔ�U�Z���Ж]�Qo�H���0{bR��ѷ��y���թ�h�i�������C�ɶ-sr�����gψ�"�3����8�na�W4%%s�#�9��L�r���2��²
���x�6(�$�
�j\�3�ĮFz���*�>5S�(��3��e�����f��r����{ɨh8w�j���n�)ф�(�:IQ ����ޞ��'�?�$�����j?��ֽǔ^ԮBIŸ���ӈ�Ei������L�/�0Vl�%�B�Č< ��pH2
���ǔd��87ݷ׶a�U��I���paP��S��o�L�o5�J�n��#9�5iA� =�7С�bo��A^va�wl'��AD��`��y]�ݠ���޻�.\��i���J=|�Da7n+�斏���3��X�x߆�����[j�I��vs��j�]�a*� ����ܓ8�}2�T.^Ŝ8�Prs�@��;��`��C����e��I�zgV�!�z�l���
��*L[l�����v굈8�܎��ǩ>tQ{�+���_�1�ԗ�<E����4μ�I��Z�$�甌��T_�F%�#Y�)=�	�K��-f�s�$�]䌱�LM��P!+[�f����l�^ݦ����S���6<LN��Xm=��(�g�dhd�/��;?%�~����F���BXj���NvVpv��~������엃���̬W>͏���.�r�j<��P�$�A���*u�z�T�*�~��>����	5^�!�3���w+o>�Dg�bϽ��li)��ϭ7V\?B � uo{\���#.QH��ނ;j���g�g��h
r�&fE�!ֽ}�w�WO�w4�+��GHNk%Inl���f?�y٪m�������N�7b�[[�i�Ȥ��"�Y�9WhVk5�r�|Bm��G�E����q:�^S/~�3]傕������vZ�
ݜ����R��uE�7��ʷ*X�`��l!�:o���k���JJقd��rŹ\���4+��Q_�-��s����q���E�q�fS
�6�Y����+1�`s1{�}7�5��Ʀy�E̕�V��������'`���b�'�N*|�P<f^O&��%�{��:g�%�d���22�3�F7��TO�䟏��<g��<T�r�W=��ޭ����d���h��(��;ń��I��OK�s}���YAL0[Ώ�W ���A�rV�K)�hN_��8�&s����1�v�E>h�<`��/�:f�f�)U΁�f|o1��'jK�t\G����x|z;5B$��`�d�u�Vp����v0Q[�p����"\�L΁Jݯmh�r�G�EvRgɆC�l���gq�lt�]�>-B�Fݎ ~�:#�ۆ���@��?m3� �� �nx<m\lw~�Rt��nw&���d��TSd�B���;����S7��u�yKq��ߕ�2-��\S�8���oQ��!qa��О�m��w�چꕒ��n�m��U��ybjƛ�����X5��p�%���9c�e���,�j�?e�5������]��!mS�����V�I$�;�i���H2KLȸ��!E�r�{���n�� �]7�,/�Y�-%uvl��WZk1)�h����(��\�yD���ש��(���l{R�g�'[�_�w����s
�"��H4П��W)��vK�ͫEa�f�o�thTK=[	��V$�PI��a�F���B}uom�"�fK�-�l!��k/���؏x0L�j��kb!�`��e�R��I��{}Ch����Irg�=Nw_�����m��TO�E.�uW�X���>�������0M])��&҄hu�L�}b["+Z�V&Y����w�9WiPd$ӧ��i�PR2������?"����u�u���}�h�B�7���!ElZWh��������rS��ʇfˌ�K�k�U��U��,UJ_��X��?�9�ҋ�$���T���_�4q�)b1��Ig=����K��  �T�����mV�A�o��s��ޢRŭ/hnm�HkD+6�}��&��Ir���_�B.0vDn�4D�X����>pY�,�y_�<:��@`��>3�ds:��S}����Ù�m�v�*�5gV1��+�i*�
��P���U݊��6Ղ�v��U��\o�c:+a�(��&�l�>��=g���[�b'�O��>~P`_M�4��y=���)�����C�P�É����z�����y8�b1Q\�'�iJiT$���C\[�����cL���g��Y�ed�����w�6'�Z�����*��Zc�^#PO�	�Ê�r5w^���.�``�T����o�Q]��+C� ���?&Y�s���j��R1� ��-e��XX�>�9o����0�n�11��9�-[]���E��ژj��j�B.�"R��}<�U�Ij7�3^B�|�5��6(E�2qF���R֔z�zn�5�+K\5=eS����Q�t�H�Gʪv�|�_:@}��N��S��{�;���-��&��P���T�;)ivo,j���,H������{
���,qP�AI�	�*
9�&m���c֌���X�C$��N@�/���дJ�(��u�I�>�N>v�XƗ������x:L��Ԝ�h���1�S�g�-ǥn&�ReQ�O���'i�Ft�۾�%/i!$��N�����8�e�Xn7��Un��,E%�\~��1�bv���X򩵳�ʷ��ˉz�����?r��M�k�-�Z>��Ӝ�6����>���q�)	�u���;V�x�y�����h�Mx�JXn��l��,�)�UZvdg���k~�۝��9�/y%d(�y���K���3KN�V�P]E���}��S�n�s����B�z�g:���K��p���ݑ�(9����.���8���ȉ6ٯi�����)*YU`��$���U9��>$���tK���!����^_����m������I��X�*�KaiE��׏Ij�":�@T;�n����%9�b�LvL��_�~���~��3PsHmk�d����F�����~lh�{�w-���sϞ@����~lP�ۅ׍(M�)M�'BKa��P7�;��Uǀ� m��D�^���i͇��:��g'2�D~3��{���h�F�	E[F�����btK�U^�A�GH��1)k,�Щ�%> !)��ސ�	�/h��otz���!ڄ\XJ]�v��:���#\��0} *�.�3�M�4c�P>ѽP�>g��>�Q#�	�Ư�٬̛����J��k�H�*tԓ��²J������`x���;�%U��7�8�ͽ��XA��H4�5��)]k���6�L��kk���x���*HF���0'��Rk�go���	�(���Ϻ�Z��|�g�������Z�8��lA�ѐ2���8#��:��ȨlmV���Ϫ��E8HAI"5V��R6������|����YÐ�(Rj��C��=�];�8���x ��L���㤳'��p����Ľ���g;����w��}��hh%�������s����5�E��Lᬭd0������u��O��t;���%�;�%Y�J�7��@DY'��8%*ϕ@O�z��!�y$g8�J:����$)�nxl.�'k,��]��,G�h��{��� {OxgY��B0m�L����n2ѝY��.����+.E��;�\�gj}�n����3��B+����4Լ��0�a�(:a�hX�<��G��eiP���Չ�@����Q�Yڄ^O�@����%�]�>�	�.��6(w��{z�VuT���^���7%|��+3w��<	���f+�#�n��BW��R��,*��k�*�h��e���4�O�(�o��m�˥Lli�{���{L�d�!Mb[�
�ՏC�C:
?�����E��|�\��h
�w�7@�����\}쟴a3�)��o�����(^:����v4} u�q���E��p?1��#��U+<�!���st��W@�߲Oӯ���v�5iq���/��2���=@J�9�d]C�&��\y���m�H�G�A�'=�X�;\F�y��?��nP�k``b�J�t�ڭc��ya�Z���pc�E����zvV�x�ʰ���ƪ�vm��!C����R/�|��b��Dy�䅳��^/�9����s�O�=��'��)L���
��{��|;��x>�vwi���a#�q'���E��x�?���|�꠩�����1���oWn��<��X߾F4@�Ч���`/Bn
����l��bq��n}8�N�x���3���b�<���w��%8rV�� ����h��"B�CP��������W�ޯd0S�*5��	�iQ��Sv$�v��Y�*�gq8k~�2HIi�sV��|-�Z�����3P�Ζ-aUw�1�J��8��������T��w.��t3�z.t�s�HAK� H�?]�~�ɓ+y3n(�Sս��$m�dsv�!���^��g������0�=C��ӈw���z'#|���2*��;M7@qB�պ�J�����s�13N�ok�T����W�9q=
���}���P�v`~�V^�N���.+���8xw�+����I���	�8����ip���
��70
�?�?_��q���e����?�h����>������b�z����������8P��������7rZ0 0`��0`��0`��0`��0`��� ��x� P  