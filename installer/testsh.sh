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
� ��"Q�TS���C�ХWC��@��K�E%��{�"HS�*]ED:�i�Ҕ.��Ǚqf����o����}�_�]'��s����sn�ν�`�qQQ��R�R@H�� A!AAQAQQ������ $
�/���C���sA�a�=`�04���v�������3;~+��,��q@x�����9��������D�D~�_@DHP���b�� �������caS�O?���?_� zJr��J�>�D }?V��Xw�]J@<�r
B�z���:M�g�*��v���EW�Q:����[i�_>{G�dt�> �	��8�11{]Z~�T\�
�0������壮g6��>.>��Ƅ�@j�ՑWfW��Ɇ]����3�p1�$9�����آf�>�q�������C�T6�m�X�ۻ-�˦�囖�-�uSz�K�$Z_,,X�
2�ˏ�#�,���u���,4,�kF�U�:��=��*�>M,��l���t=��G�k4^�I�D 4���>�ڸ��d=[�t�o8rש[_��2�
ʙ�Cw��hE��� ��}Y�v�3m6�\��M�R��+�A]�"+v|墕�g�%�.�lP>�'9Ex׾(���|/��k��8�h��E�k㑍���!�����������*A�K%�-�I�;X��d��������ӡ�+&�dG@V@�$���Ɂ�+E�	�� Zް�oе�T1ܶ�7�^���+�Uܰ�!`�j&��r��PS؍��Sj�x�x,������K
v�� �x�%c:�5�)<�h�؜a�^b����eࡿ/���Pm-��s��e^����br*�_��J��y�rȔ�1�XZ�@ ���E1�5��T���Ϟ�tǐ��&q9}�Hr��#�#�G ����:wL~���gv��W���y��*��:�����a��Q�g�D�dU�)��%W1�Z��Z~���w����1��;�Ԥ�0/�^fL�Njt�/9�@Sٳ[�8H�O��87������l��*a{��`��'�왇�_�?��y0n-�I3^
J���s?N�~O�"�#ȴ �C��V5���L��Y
�"����]y��cGq2`| i�L�֫cA�x���;D�6[ZP��4�Z7ҊZ�)�7�|�7+
�XY;�Y�J���I���l�Z 9�!�R�f�/�������}�]뭲�{A&�iߗם�_e�c/-o��7��,��=)T-	D���0J]-^8�=����� ��1~=bT�2e?�ǑK�q�녗���|1��Z&���}�v�э@E�A��pT��I�Kd�"¯4a��*u�i�p����	�QK�eo���ު�>�v��.���OJm!Fnh�{��Z�q$ɢ�
cn�J�Y_;T�g�U�2�,duz'�7e��4:���D��|Kx�"W�t7W`�4�,�f�U��Eh4�n��6�}l��k1P���mVi�A�}zJ��
9p���M&�-��k�q:�9�Z�D����;�Wn����C��j
;��iTqKN��c�P�M� X�������T&�H��"e��,
%1����etK|���`��3�f�4�qJR����φ������Z�9��Ţ���Wq��T��-��WPʑD(&}K�vM�R�@�>�77F���$�r�5�a��w���A� l6W�42���MV7G�RO$M۾��?��y� �Y�VGw��=R�V� �C���E(��1y֓�;ьEc
%5� �m0cJ���M�+�P{~I_��T�ғhS}p4����&����n�]H{�"�
G~жq�}��K����"��,�8�۽��z�������t@��� CɑoÉ~��*_b�Jq��KiK^C署b��4�^�<��q`�b������#9� m��G�m����{�jÒ@���L;(5?;{�����0�Xt����xq�*���N�}�(����xb׈v�g^��
TH�J��(�K����k��=�Fޒ7�
gD���sC�L�e�����s��5�q4��5L^mV��`�*��.�$AAU��Zu�*�Cnh�:����vU�
1��M�ODc!��i� �-�m1��D��}m]O� 3S����;Y�š4vc�,���Yτ�յ�)
P�X�pV��TW4<��>�U8:�c���A(U>��H��8ĵ��E�|�'�h��q���f�)XR��~�g�g�vut�Y\ݡꊔ�lӡ��%<�T�����1P�¯Nˑ��emt��^� ޣ }�5?���e�o$_��D')�`?�S
�TG��D��1�m�	h��x�c&��2�� �AH�-bJ�c�%2=˻�0��d�������X�a�}Q�
��#�t���k<��9ʜl[�S��]o�g�^
�r�ع�x}s�
�T�j�E=JM�uL�<�.��vj�*zv��p�!���e�<��IB�N��f������4�(���D�N%����Ԁ2�h̀�`��ݔd�W����#$`ݐ�9]���)�!*��^�	�)��ɯw|���&Ԁ��K���t������Ɵ�f3�-$�.�3��N\5���U8�:��>fH�8�u�@l��[K�Z����D�"5��.=ū�A[�k2�"�K�P6�K|��RO���T��]�e�0��ȴ�����^y9X�Ԥ��e�	?n~���m��� D�v]�E2���˩nJ:-��m��	v �*H7��!�hyҥ�����4�'n�'�G�=�
���(D�G�y.��܈���`&]�����E_���#Pf�h/eQ]�����'���Z���i�$�D}��u�ܒݴ��դ���M�_���x�yK�k���{6�v��7v"�,�:��W*��6�	�V���SRuj��q�YqQn5Y8s3	��i3>�h*���z�k�rNrƖx�Hʯ��e�.Q�L� 8&$�O����s!�'���J<���2'*����.Z!�/��]��(M�h��t>ZZ����)�1/NoƗ�M�����SV��Ƥ�ES���"�uJ��#��e�ɌES�Gܡ[��8kj�<�2��d�(:`~�_�8�	�G���yiP<����ѕ@����!�I��.O�@����9���>��B.l��(g��kZ�zud���vӭ���%ܵ��p������&+�#^�aC�
p��N�1���[�����#9�KėxFF/su�)�gK�0�8Z�Q��b��C��yh�[��+�z���^s6�|��skOV]� H�	7M�v�ѓ#y-�?�C���t�D#
��������b�"�����+�P�0 M�
��PBڠlH�ӋPe>��������Dp�b���w�����b�����Bb������[��
����/�@����@{¥@�(��M
�E~�es���}��̀�ގ�L|-�A\��*~�*�:��8�T�5��ට�@�gz�aH[4
ab�;��q�H8�T18��� �C�&�מ���11����a�_7G؁�@|�
�څd�F��"�Ry�wW��Xp�SK�U�_�B���x�о�~����(�������Nv�oɏu��X����
=�Ŀ����_Z���IJ��5�����Nm����{��K�t�>]��Sq��(~����0�-
	]�l�_t=�~W���g�Q�v��h�5�A�?A�s�9�s�9�s�9�s�9�s�9�s�9�s�9�s�9�s��!�x7�K P  