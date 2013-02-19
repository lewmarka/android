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
� I�#Q�<�w�H����=�cFG�C s	�M&�\H���G�x�ݶ��UK�8��~���jɲ��{{o<��������[�;���
�������7�����k�������qG<��>�*�\�;y���n��7��A�2)T������ ��?|�������v�����������<�?X��~������G� �k�V��?���?o�ORdyz�P)�CD.�QF���j�Q���2��Q2a2y�$��2*&"a��Z�#Q�i�!^�i�
1H�Y��ga^ �P^�8�,��E("�td2��E��fC�>�4YQ��+� �� 2wKQDSIt��|�L4 N�
yU�<	cG�y�_��I4��K)J��jf�ҡ�i�36��4�x ��	Q�s��`d~!s\1�RI� �e&T
@(� M�i�Q�8�1;�b��(S��������"��$bD4B
Q���ɵe���4GЋ4�@b;9:\�eL"ġRRKKK{���N�6�J��rP-�B q�UW������
�4KA�D����u*�)���Ĉ�Ҹ�D�<�m?!N�0N���!K3�a��!%4J��a�8B��2�y{D�`��(L K����]E�@��)&�-J!҃�E��uWKN
��zY)h
��3V�Ҫ�1�i��0��P�����l��p�"�!�?4�h��pxMD�ޠFۅ���w��aX�=�B������'��C� � �>��e3Ϟ��󺨜��#�l��£�X�`&c��bV��� ���f��6B�q��Y��]���B���VB W�aS+�6�Ь�l��4Qi����*�R_C5���e<��d����e��u�M�]�s�zs鲾#Bm�WӘ'D��+e+��2���Y�����f��~^�_LL�{�����Sq�{q�w�%��hK)Rf �"��(�]�]�+���\�+�Z$�Xkf4��Q�Ni�����r�ӏ�l<#�@�2�r�+־�{�/�E�BK�~�XPo���hhO� @���!o�&z��ή8:Y�l%`�B��u���?|z��K�l5����q�?#������m4�����?�������Im]�xۯ6�����"��\��Upok�gl��ꪥw'��붎p������ȶ�����D)Һ���y�I�������݃��=����%`���0]cHEq��D����5ax4���J���,��QNb���R� �(=� g��8�l�&R$��\#z
�*���R!&!ΐK�0S�c�&7�TBXFr�:�y��8�b��
9߃?�Yq�I�6����a�*i䦐�BX�'=\��y�E��AJ� �@n�2�%��`KRCq;�,J��JJ7"J5ȣL���s�5�
 ctO��=*�iͣz)�O�@*�"�9:LFv.'�E��IА�S�	��F)3����
�j�Ԩ9%��v!���<��u�O8���I�0�P�� 歶NYk�C��~ѓ����M[{c��3C�E
�X,�Ɓ��Ju?)նC(�3,�5c�k��
�^������,�0�U�]9���A���]�/3\m�zcY<Ӕ"3r	�oR?g�kX�N��W�ƁeY0�/G�W�~�C�!���U��-���s�Ҋ��J�Z}��,R�=�o�hD+�e��DsՅO��̳�,��Z���m�d�O�"U���R�@���{DG��I��Z�����Է�&F 3��4s�1��91̃��w���-V+�vA�y�̌k�Yiu��hw6;g&�ݜ�U�~X���Y��cV\v��)$w���'ǜ���m佫Md�b�~ʫ"���&��c�Q�Wz���Y���<n��@�X�矞^�_���NO9,=X/�{�]���#�y�Q/.��J��6j��s݀��	�$+�W�m���A��
.�X�B��Z�͈`c_H���~��S"�Hv�}�s�g��a<��\Fq�U[�����u�s]��#�3=�V¬��L�Z��/~-G#���1��`��;Fo�ht��@v��6ڳfC���~��{1ץƗa1@�<eM�D��ܲQWn(E0#Kk� 3q쭤��y`B]�)��h�w���)�dX�!�b�����>6��=�i��H���֘�of���V"tui�ew�a~ {���͌�B>���G�Z�h�j 9�r��`�&�	 ������VY�**`���*m��"����&u�t9�
]W���@`<�XW���T��L�F��n�bT�ӛ�6K\\����qNmȶh�<���J����f@U���h� i�Z,lQ����
 ���%�$�Po!&����%W+���B1g�֭��w��0�8ZvT�ռ�8�]k�P�զÎ�E�j\����:�gM:�CjF��k�փ���(ԅ�����ʈ����h-uU�vu���p��C�`�&�:F3ߦ_�����-��f���΀s�ַ��8� d��Ď1����'�z֥��^;s��[������&���-]��jC���l�Rtm@k*��tt�kB�9�1H�9N.d�bJ�4�H��|���r���	��V��z���n����j�D�6�?X E�$�����:�� ��Pݧ9Si��xq�\�D�r�M�H����J:v��mF�=�� �N��r<�̗Cڛ�**�����жB� ��!�͊�"��.���6�����bz��j�$��x������d�����:N��KPj0�i�������a�T2x���x#ǉ�U���`Co{��M��4Yj*�z����"�C�3}��E�^�{m+�b_������SJ�x4⾷|Z�e�ǫ��7��XٽR�V��E,�/�y6M/�<��l��g�h�4�6��L}�%s�V��(qy�`h�iI;Ӓ[�vh,�fZ�ՙ��Q���|RN�!���6oK)<F�:j�&ܚ����V���,Ѿ��R��8�H�Δ��c�WE�6��14 �$ٔ�k��]���WD��/Mpy��,�\��Uf�����a��f���!pe����|��$0'�� ����ڌ�d�W�/U8����=�y�g�a}O�cR^���1��"&���Z���o�q�n�hc'��e@��>�Cnc�u�7#����q��!�7K���_:��꧿����=|����?�������ߣG��<���Ʃi=Ǜ9T�򽙮}L}`��p:�J�f��(?��o�hO &zs|��;/��Y��{�.�5�A<]�4��K<�˧�X6�-�azR&;�8���t�*n=���ơ4�N���Ա6/I�?5e!��IxK_���Q�_���j�
JېW��'�����y��߇�?{HsR����A��!��mo�&�ۚxr.'i\R���Nܠ����h6E��+�"��w���b�N%^�|a���N�ɀe���f����A��C�������d����>~�A�'8�N�7P�&�!w��9���N�]e��x#�D�X�G'zPw���q{�E�9m�擪�B���IM(g����e��(ye��m�g�!���Z���kxʛ-H��b��g$"��Få��3C��A�k�Q��6�)���tP�J	�q� �Ǌ��a�py�a �䩵�?�}�N�5XT����m�"P^/E�x���-�z� ����5tǙ��JH��׏��� +��ș-�)\1
F,$��m!��D��z���K��X��jڵ;9��I�7@aqcYXXV�.!g��������W��5vj����i�B��~F9�΀�5н˫6���ș��0+\��輅[��iLS����2:|���e�XƘS�|�M5�4jft j�ohC�%6R��^�2��-�V|2˫�d&mJG���98�{'��O��J^�z	��s=����U����������c{����f�fU`L��� ����5j�Ν���,��7�[�L-�B�x�.ϖ
�s�F�#B}CK��R�@��i!��?�n4+����d�u�`�ZJgQ�m��F��<H!ת�'ʡ询�a�[=��I��SX��ܭF*��k��N\��b�a�c�L)�j,�o$�D��qq�&1Z�.�z�!�BUq�U��x��'Z7���f-s�ͳ�$
��.�7���g1�f�hp*��S�v	�Y�TP' �w��Ď�V�ؽ����s&E���^������	y�Y�e���_Y]����l=��k����ל�1�逡�/1R7���)�gµa�ř�N�E�$�A�l5�w�XK�6��{=�l�!���	��	d*/�x�`�����eD��9D�~>
j����尹�ڤ�~`�@�~� !p�D�n��͆T-�a�נL?� �)I��^�E�mouEH�ϹZ�=>�"BZB�w{��G�g�Eev�KX�	<���$y5hG�L3�����uk׈J�1RW��?oG��V�:�}��O�0a�̯L����J��R���g7��-3��(c#��Η��oz����O7<�f�F��X�f�	iV-�1p��Y�H�X�!X�w�g�-���o8Yx�iX�&4Эo����{�9I�t�֣eK�B��EI�&�z��h�3;V��sKg����ZtNo\w�T���i����ߞ��/v���{���O�ö�(G���K�˜F�Z3R��x�� ���� Q4������s�U�F�H��Ew��ܲ	���F��&�2a�6��iܤȥcR_�0��A��U
%R��3���j�P��C=��X& g/����F�7��1���!�g�ѱaG�|1{���i/p,���k��s�P�tW��	��D�-�H��.��˖EU\V�Nf�:���U�u���T\s�Z��0�xQڨ]k��1�t�]������Z�����[���Y� 1Va^���l�gm��������j����`����>͔�������<�V��w�5LX۵:I0���� 3[-�&0*�����S�i��NOW[�py��+<O/� ���*���=M��wi�4H�rwx�)n�ܢTz�jcp�d����&m�H����(Y��?�/��Rǩ
�2V Jc�n-w�IWִ���^s��u+�qR�W��5��75�%b<��=�W��-��`ҵ����O}wV�ƹע�������4���j�~s|  ��0��7[^U�s)�sG)hmկeZAa��4�H���J0{"��8��Z��c
����wqI:����|�y�����7�(�:F
x����y�l�gO�vp�X�����U4$Tz'�c����u��=�R��8�z�럿�v��́�������31J#B�m��D���	]�H�"���Ep�����[�����"���=��O
�r0�����ύ�\� n�j�6�/���Y��צ�}�"%�u�c-�B,��9�%[���K�a�_��F�-P�Zg�����@<bk�p�o���V$8Y��(�Ox����ł�0�������3X:+�C��;1��3�_ ��vܱܚ�E9[ǯ[���Ae����s�[Ϟ���rͺ��C֎�c�T͏�:�kc�Vf�2k]�vִ�5�?�a[GS��u*�h]?0K��/��_���s�ʅK��U���"��"�Ն�{v�z�o��+J�iD�u����&o�ـ���h���|�Oۘ/�?��ps�"���X��������~���F���϶0�vk��յz�ZU���t���/�.o
o�Q����������>��PM�<��� �FJ�A8�=�v�B�� �Jj�������>��Mѡ��J��]��*ՌR} ��*����=�o��4�[���:jw��t�檩����x2������J_���O[ȿC,�h|�����t�>�]��BL½�@9rb������kP���u!��9Y�9���7N��a����6p)�o�%9/G��ε�������F=�$��F>Ԅ�ֆ�P��PLh,K�"�d"B��{wvF���"�a��A�ٗf���|�=�wc[*0w�h�s��vT>��{�����	V���x�u����hm�l<�2���RsJJא���޴2��eKh:�#m����
�UeL��6V:T�wF����c^�r���Ym/7Q��{q?�H����a�=ڄ]�kj�������cfc6�_�����{���_���%��%���S`>�����}r2�^,�������P;G�~�4��ҵ�f�T9,M� �׃��@�)'MNC��Pz��a���l"����5�Psj�W��6���|�%�����?�󎪤��8͑��w@�+�;�tQzS�E��Ď����M�ؗfM;?~0����qZ�Ǘj���:���yC�4iXUm���F�bX�#�iD�f�vu��e�}&lGU5薏K3M���j�����jPfsOƉ�)��ۢ�IL�I���QkHҮf�(�� L���2�X n��x�:]�5
�R ov������������AO��W_��7�/��mb�a�����p��,X|Y��~��/�@ �@ ��'h� x  