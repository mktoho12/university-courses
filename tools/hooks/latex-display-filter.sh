#!/bin/bash
# MessageDisplay フック：大学の勉強フォルダ（university-courses 配下）でのみ発動。
#
# 目的：アシスタントが地の文にインライン $...$ LaTeX を出しても、
#       *ユーザーの画面に表示される前に* それを Unicode プレーン表記へ変換する。
#       （Stop フックと違い MessageDisplay は「表示の前」に効くので、生 $...$ を一度も見せない。）
#
# 重要：これは display-only。返す displayContent は「画面表示」だけを差し替える。
#       transcript と Claude が見る内容は元のまま＝Claude の内部状態は壊れない
#       （ロール混同・捏造の副作用を増やさない＝最重要(0) を侵さない）。
#
# 方針（ユーザー確定・2026-07-09）：
#   - 変換できるパターン（\circ, ^2, \sin, ', -> など）は Unicode 化する。
#   - Unicode で綺麗に書けない複雑なインライン式（\frac 等を含む）は、
#     その $...$ だけを $$...$$ ディスプレイブロックにフォールバック（ブロックは正しく描画される）。
#   - $$...$$ ブロックは元から正規の用法なので触らない。
#   - バッククォート内のコード断片（`... $x$ ...`）は変換しない（コードはそのまま見せる）。
#
# 入出力：stdin に MessageDisplay の JSON。message 本文を取り、変換後を
#   {"hookSpecificOutput":{"hookEventName":"MessageDisplay","displayContent":"..."}} で返す。
#   変換不要なら何も出力せず exit 0（元の表示のまま）。

set -euo pipefail

input=$(cat)

cwd=$(jq -r '.cwd // empty' <<<"$input")

# --- スコープ判定：university-courses 配下でなければ何もしない ---
case "$cwd" in
  */university-courses/*|*/university-courses) : ;;
  *) exit 0 ;;
esac

# 表示対象のアシスタント本文を取り出す（フィールド名の揺れに備えて複数候補）。
message=$(jq -r '.message // .content // .text // .displayContent // empty' <<<"$input")
[ -n "$message" ] || exit 0

# 本文に「地の文のインライン $...$」が含まれるか安価に判定。無ければ即終了（変換しない）。
# ここでは $$...$$ を除いた後にインライン $...$ が残るかを見る。
probe=$(printf '%s' "$message" | perl -0777 -pe 's/\$\$.*?\$\$//gs' 2>/dev/null || printf '%s' "$message")
if ! printf '%s' "$probe" | grep -qE '\$[\\A-Za-z0-9([{][^$]*\$'; then
  exit 0
fi

# 変換本体は Perl（行またぎの $$ 保護・バッククォート保護・LaTeX→Unicode 変換）。
converted=$(printf '%s' "$message" | perl -0777 -e '
  use strict; use warnings; use utf8;
  binmode(STDIN, ":raw"); binmode(STDOUT, ":raw");
  # STDIN はバイト列。UTF-8 として文字にデコードしてから処理する。
  my $s = do { local $/; <STDIN> };
  utf8::decode($s);

  # 1) 保護：$$...$$ ブロックとバッククォート内コードは触らない。
  #    プレースホルダに退避してから、最後に戻す。
  my @vault;
  my $stash = sub { my ($t)=@_; push @vault, $t; return "\x00V".$#vault."\x00"; };

  # $$...$$ (複数行可)
  $s =~ s/(\$\$.*?\$\$)/$stash->($1)/ges;
  # ```fenced code blocks```
  $s =~ s/(```.*?```)/$stash->($1)/ges;
  # `inline code`
  $s =~ s/(`[^`]*`)/$stash->($1)/ges;

  # 2) インライン $...$ を1個ずつ変換。
  #    中身を Unicode 化して、綺麗に化けたら裸で出す。
  #    化けきらない（\ が残る等）なら $$...$$ ブロックにフォールバック。
  my $conv = sub {
    my ($body) = @_;      # $ を除いた中身
    my $u = $body;

    # よく出る関数名・演算子。TeX のコマンドは直後に空白を1つ置くのが慣習
    # （\circ f など）なので、変換時にその区切り空白を1つ吸収する（\s? 付き）。
    $u =~ s/\\circ\s?/∘/g;
    $u =~ s/\\times\s?/×/g;
    $u =~ s/\\cdot\s?/·/g;
    $u =~ s/\\div\s?/÷/g;
    $u =~ s/\\pm\s?/±/g;
    $u =~ s/\\leq\s?/≤/g; $u =~ s/\\le\s?/≤/g;
    $u =~ s/\\geq\s?/≥/g; $u =~ s/\\ge\s?/≥/g;
    $u =~ s/\\neq\s?/≠/g;
    $u =~ s/\\approx\s?/≈/g;
    $u =~ s/\\to\s?/→/g;
    $u =~ s/->/→/g;
    $u =~ s/\\infty\s?/∞/g;
    $u =~ s/\\pi\s?/π/g;
    $u =~ s/\\theta\s?/θ/g;
    $u =~ s/\\sqrt\s?/√/g;
    $u =~ s/\\int\s?/∫/g;
    $u =~ s/\\sum\s?/Σ/g;
    # 関数名は空白を吸わない（\sin x → sin x のまま。\sin(x) は元々空白なし）。
    for my $fn (qw(sin cos tan exp log arcsin arccos arctan)) {
      $u =~ s/\\$fn\b/$fn/g;
    }
    # \left \right \, \! などの装飾は落とす
    $u =~ s/\\left|\\right//g;
    $u =~ s/\\[,!;: ]//g;
    $u =~ s/\\!//g;

    # 上付き ^{...} / ^x  → Unicode 上付き（対応可能な文字のみ）
    my %sup = (
      "0"=>"⁰","1"=>"¹","2"=>"²","3"=>"³","4"=>"⁴","5"=>"⁵","6"=>"⁶","7"=>"⁷","8"=>"⁸","9"=>"⁹",
      "+"=>"⁺","-"=>"⁻","="=>"⁼","("=>"⁽",")"=>"⁾","n"=>"ⁿ","i"=>"ⁱ",
      "a"=>"ᵃ","b"=>"ᵇ","x"=>"ˣ","h"=>"ʰ",
    );
    my %sub = (
      "0"=>"₀","1"=>"₁","2"=>"₂","3"=>"₃","4"=>"₄","5"=>"₅","6"=>"₆","7"=>"₇","8"=>"₈","9"=>"₉",
      "+"=>"₊","-"=>"₋","="=>"₌","("=>"₍",")"=>"₎","a"=>"ₐ","x"=>"ₓ","n"=>"ₙ",
    );
    my $supify = sub { my($t)=@_; my $o=""; for my $c (split //,$t){ return undef unless exists $sup{$c}; $o.=$sup{$c}; } return $o; };
    my $subify = sub { my($t)=@_; my $o=""; for my $c (split //,$t){ return undef unless exists $sub{$c}; $o.=$sub{$c}; } return $o; };

    # ^{...}
    $u =~ s/\^\{([^{}]*)\}/ my $r=$supify->($1); defined $r ? $r : "^{$1}" /ge;
    # ^x（1文字）
    $u =~ s/\^(\S)/ my $r=$supify->($1); defined $r ? $r : "^$1" /ge;
    # _{...}
    $u =~ s/_\{([^{}]*)\}/ my $r=$subify->($1); defined $r ? $r : "_{$1}" /ge;
    # _x（1文字）
    $u =~ s/_(\S)/ my $r=$subify->($1); defined $r ? $r : "_$1" /ge;

    return ($u);
  };

  # $...$ を走査（$$ は上で退避済みなので、ここに来るのは全部インライン）
  # 区切り文字に ! を使う（{...}{...} だと中身の [{ がブレースと誤解釈されるため）。
  $s =~ s!\$([\\A-Za-z0-9([{][^\$]*)\$!
    my $body = $1;
    my $u = $conv->($body);
    # プライム：f'"'"' → f′（シングルクォートは chr(39) で表す）
    my $q = chr(39);
    $u =~ s/$q/′/g;
    if ($u =~ /\\/ || $u =~ /[\^_]\{/) {
      # 変換しきれない（バックスラッシュや未変換の ^{ が残る）→ $$ ブロックにフォールバック
      qq{\$\$ $body \$\$};
    } else {
      $u;
    }
  !gex;

  # 3) 退避したブロックを戻す
  for my $i (0..$#vault) { $s =~ s/\x00V$i\x00/$vault[$i]/g; }

  # 出力：文字列を UTF-8 バイトにエンコードしてから raw で出す（二重エンコード防止）。
  utf8::encode($s);
  print $s;
' 2>/dev/null || printf '%s' "$message")

# 変換前後が同じなら何も返さない（余計な差し替えをしない）
if [ "$converted" = "$message" ]; then
  exit 0
fi

jq -n --arg c "$converted" '{hookSpecificOutput:{hookEventName:"MessageDisplay",displayContent:$c}}'
exit 0
