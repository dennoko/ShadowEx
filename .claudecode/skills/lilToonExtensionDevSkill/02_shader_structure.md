# シェーダー構造

> 公式: https://lilxyzw.github.io/lilToon/ja_JP/dev/shader_structure.html

lilToon シェーダーの内部設計・パス構成・Include 構造を説明します。

---

## シェーダーバリエーションの設計方針

基本的に `ltspass_xx.shader` がシェーダーパスの実体で、
各バリエーションシェーダーは **UsePass** でそれらを呼び出す設計になっています。

```
lts.shader (通常版)
  └─ UsePass "ltspass_opaque/FORWARD"
  └─ UsePass "ltspass_opaque/SHADOW_CASTER"
  └─ ...
```

### UsePass を使わず独自パスを持つシェーダー

以下のシェーダーは UsePass ではなく独自パスを実装しています：

| シェーダー | 理由 |
|-----------|------|
| `lts_fakeshadow.shader` | 特殊なシャドウ描画が必要 |
| `lts_fur.shader` / `lts_fur_cutout.shader` | ジオメトリシェーダーを使用 |
| `lts_gem.shader` | マルチパスの特殊な宝石描画 |
| `lts_ref.shader` / `lts_ref_blur.shader` | 屈折処理 |
| `ltsmulti_*.shader` | マルチコンパイルバリアント |

---

## パス構成

各シェーダーには複数のパスが存在し、シェーダー冒頭の `HLSLINCLUDE` ブロックでマクロを宣言し、
`#include` 内でそのマクロによる分岐を実現しています。

### 主なパス一覧

| パス名 | 用途 |
|--------|------|
| `FORWARD` | 通常の前向きレンダリング (BRP: ForwardBase) |
| `FORWARD_DELTA` | 追加ライト (BRP: ForwardAdd) |
| `SHADOW_CASTER` | シャドウマップ生成 |
| `DepthOnly` | 深度のみ描画 (URP / HDRP) |
| `DepthNormals` | 深度+法線描画 (URP) |
| `MotionVectors` | モーションベクター (HDRP) |
| `META` | ライトマップ焼き付け用 |

---

## Include 構造

各パスの `.hlsl` ファイルは以下の統一構造を採用しています：

```
lil_pass_forward.hlsl
  ├── lil_common.hlsl           ← 設定・マクロ・入力・共通関数
  │     ├── lil_common_appdata.hlsl   ← appdata 構造体
  │     ├── (v2f 構造体宣言)
  │     ├── lil_common_vert.hlsl      ← 頂点シェーダー共通処理
  │     └── lil_common_frag.hlsl      ← ピクセルシェーダー共通処理
  └── (パス固有のピクセルシェーダー実装)
```

`lil_common.hlsl` が中心的なハブで、設定・マクロ・入力・関数の大半を担います。

---

## マルチパイプライン対応

lilToon は BRP / URP / HDRP の3パイプラインに対応しています。
パイプライン差分は `lil_pipeline_*.hlsl` で吸収されており、
カスタムシェーダー開発者はパイプラインを意識せずに実装できます。

```
lil_pipeline_brp.hlsl   ← Built-in RP 固有マクロ・関数
lil_pipeline_urp.hlsl   ← URP 固有マクロ・関数
lil_pipeline_hdrp.hlsl  ← HDRP 固有マクロ・関数
```

---

## シェーダーキーワード（ltsmulti 系）

`ltsmulti_*.shader` は 30 個以上のシェーダーキーワードを使用する多機能バリアントです。

- Built-in シェーダーに合わせてキーワード名を選定し、**キーワード枯渇を回避**
- VRCSDK が警告するキーワードを使わないよう考慮されている

> 通常の拡張シェーダー開発では ltsmulti 系を直接編集する機会は少ないですが、
> キーワード設計の参考になります。

---

## パス冒頭のマクロ宣言パターン

各パスのシェーダーは `HLSLINCLUDE` ブロックでパスを識別するマクロを宣言します：

```hlsl
HLSLINCLUDE
    #define LIL_PASS_FORWARD   // このパスが ForwardBase であることを示す
    #include "lil_pass_forward.hlsl"
ENDHLSL
```

`lil_pass_forward.hlsl` 内では `#if defined(LIL_PASS_FORWARD)` のような条件分岐で
パス固有の処理を実装しています。
