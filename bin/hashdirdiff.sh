#!/bin/sh
set -eu

######################################################################
# 設定
######################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
	Usage   : ${0##*/} -t<ディレクトリT> [ディレクトリM]
	Options : -ot -om

	2つのディレクトリ内のファイルをハッシュ値で比較し、
	対応が存在するファイルのリストを出力する。

	-tオプションでディレクトリTを指定する。
	-otオプションでディレクトリTにのみ存在するファイルのリストを出力する。
	-omオプションでディレクトリMにのみ存在するファイルのリストを出力する。
	※-otと-omが両方指定された場合は-otが優先される
	USAGE
  exit 1
}

######################################################################
# パラメータ
######################################################################

# 変数を初期化
opr=''
opt_t=''
opt_ot='no'
opt_om='no'

# 引数をパース
i=1
for arg in ${1+"$@"}
do
  case "$arg" in
    -h|--help|--version) print_usage_and_exit ;;
    -t*)                 opt_t=${arg#-t}      ;;
    -ot)                 opt_ot='yes'         ;;
    -om)                 opt_om='yes'         ;;
    *)
      if [ $i -eq $# ] && [ -z "$opr" ]; then
        opr=$arg
      else
        echo "${0##*/}: invalid args" 1>&2
        exit 11
      fi
      ;;
  esac

  i=$((i + 1))
done

# ディレクトリであるか判定
if [ ! -d "$opr" ]; then
  echo "${0##*/}: a transaction directory must be specified" 1>&2
  exit 21
fi

# ディレクトリであるか判定
if [ ! -d "$opt_t" ]; then
  echo "${0##*/}: a master directory must be specified" 1>&2
  exit 31
fi

# パラメータを決定
mdir=$opr
tdir=$opt_t
isonlyt=$opt_ot
isonlym=$opt_om

######################################################################
# 事前準備
######################################################################

tmpfile=$(mktemp ${TMPDIR:-/tmp}/${0##*/}.$(date +'%Y%m%d%H%M%S').XXXXXX)
trap 'rm "$tmpfile"' EXIT

######################################################################
# 本体処理
######################################################################

# ディレクトリTに対して<ハッシュ値>と<ファイル名>を保存
find "$tdir" -type f -print0                                         |
xargs -0 md5sum                                                      |
gawk '{ buf=$2;for(i=3;i<=NF;i++){buf = buf "_" $i;} print $1,buf;}' |
sort -k1,1                                                           |
cat > "$tmpfile"

# ディレクトリMに対して<ハッシュ値>と<ファイル名>を保存
find "$mdir" -type f -print0                                         |
xargs -0 md5sum                                                      |
gawk '{ buf=$2;for(i=3;i<=NF;i++){buf = buf "_" $i;} print $1,buf;}' |
sort -k1,1                                                           |

# 2つのファイル群を結合
if   [ "$isonlyt" == 'yes' ]; then
  # ディレクトリTのみに存在するリストを出力
  join -1 1 -2 1 -v 1 "$tmpfile" - | awk '{print $2}'
elif [ "$isonlym" == 'yes' ]; then
  # ディレクトリMのみに存在するリストを出力
  join -1 1 -2 1 -v 2 "$tmpfile" - | awk '{print $2}'
else
  # 両方のディレクトリに存在するリストを出力
  join -1 1 -2 1 -o 1.2,2.2 "$tmpfile" -
fi                                                                   |

# 出力
cat
