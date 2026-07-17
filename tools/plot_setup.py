"""plot_setup.py — 図（matplotlib）の日本語フォントを環境非依存で設定する。

使い方（analysis-1 の uv プロジェクトから）:
    from plot_setup import plt, np
    # 以降ふつうに plt.plot(...) 等

なぜ環境非依存にしたか:
    Mac 版はヒラギノ固定だったが、WSL/Linux にヒラギノは無い。多デバイス運用のため
    「その端末にある日本語フォントを自動で選ぶ」方式にした。見つからなければ導入方法を表示する。

注意（フォントの字形欠け）:
    上付き文字 ˣ や ≈ は多くのフォントに無く豆腐(□)になる。図中では ^ や = で代用すること。
"""
import matplotlib
matplotlib.use("Agg")  # 画面なしで PNG を書き出す（WSL/CI 安全）
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
from matplotlib import font_manager  # noqa: E402

# 優先順位（上から探して最初に在ったものを使う）
_CANDIDATES = [
    "Hiragino Sans", "Hiragino Kaku Gothic ProN",  # macOS
    "Noto Sans CJK JP", "Noto Sans JP",            # Linux: sudo apt install fonts-noto-cjk
    "IPAexGothic", "IPAGothic", "TakaoGothic",     # Linux: sudo apt install fonts-ipafont
    "VL Gothic", "Yu Gothic", "Meiryo", "MS Gothic",  # その他/Windows
]
_available = {f.name for f in font_manager.fontManager.ttflist}
_chosen = next((c for c in _CANDIDATES if c in _available), None)

if _chosen:
    plt.rcParams["font.family"] = _chosen
else:
    print(
        "[plot_setup] 警告: 日本語フォントが見つかりません。図の日本語が豆腐になります。\n"
        "  WSL/Ubuntu:  sudo apt update && sudo apt install -y fonts-noto-cjk\n"
        "  その後 matplotlib のキャッシュ削除:  rm -rf ~/.cache/matplotlib"
    )

plt.rcParams["axes.unicode_minus"] = False  # マイナス記号の豆腐防止

__all__ = ["plt", "np"]
