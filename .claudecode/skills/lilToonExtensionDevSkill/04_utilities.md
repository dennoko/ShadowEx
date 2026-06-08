# ユーティリティ リファレンス

> 公式: https://lilxyzw.github.io/lilToon/ja_JP/dev/utilities.html

レンダリングパイプライン（BRP / URP / HDRP）やグラフィックス API の差異を吸収するための
マクロ・関数・構造体が用意されています。詳細は各 HLSL ファイルを参照してください。

---

## テクスチャマクロ

| マクロ | 展開内容 |
|--------|---------|
| `TEXTURE2D(_Tex)` | `Texture2D _Tex` |
| `SAMPLER(sampler_Tex)` | `SamplerState sampler_Tex` |
| `LIL_SAMPLE_2D(tex, samp, uv)` | テクスチャサンプリング（パイプライン差吸収） |

---

## 変換行列定数

| 定数 | 意味 |
|------|------|
| `LIL_MATRIX_M` | モデル行列 |
| `LIL_MATRIX_I_M` | モデル行列の逆行列 |
| `LIL_MATRIX_V` | ビュー行列 |
| `LIL_MATRIX_P` | プロジェクション行列 |
| `LIL_MATRIX_VP` | ビュー × プロジェクション行列 |

---

## 座標変換関数

### 位置変換

| 関数 | 説明 |
|------|------|
| `lilTransformOStoWS(float4 positionOS)` | オブジェクト → ワールド空間（float4 版） |
| `lilTransformOStoWS(float3 positionOS)` | オブジェクト → ワールド空間（float3 版） |
| `lilTransformWStoOS(float3 positionWS)` | ワールド → オブジェクト空間 |
| `lilTransformWStoVS(float3 positionWS)` | ワールド → ビュー空間 |
| `lilTransformWStoCS(float3 positionWS)` | ワールド → クリップ空間 |
| `lilTransformVStoCS(float3 positionVS)` | ビュー → クリップ空間 |
| `lilTransformCStoSS(float4 positionCS)` | クリップ → スクリーン空間 |
| `lilTransformCStoSSFrag(float4 positionCS)` | クリップ → スクリーン空間（フラグメント用） |
| `lilToAbsolutePositionWS(float3 positionRWS)` | 相対ワールド → 絶対ワールド空間（HDRP 対応） |
| `lilCStoGrabUV(float4 positionCS)` | クリップ → グラブテクスチャ UV |

### ベクトル・法線変換

| 関数 | 説明 |
|------|------|
| `lilTransformDirOStoWS(float3 directionOS, bool doNormalize)` | ディレクション OS → WS |
| `lilTransformDirWStoOS(float3 directionWS, bool doNormalize)` | ディレクション WS → OS |
| `lilTransformNormalOStoWS(float3 normalOS, bool doNormalize)` | 法線 OS → WS |

### カメラ方向

| 関数 | 説明 |
|------|------|
| `lilViewDirection(float3 positionWS)` | ワールド空間での視線ベクトルを取得 |
| `lilHeadDirection(float3 positionWS)` | ヘッド方向ベクトルを取得（VR 対応） |

---

## 頂点位置入力マクロ（lilVertexPositionInputs）

`LIL_VERTEX_POSITION_INPUTS` で各空間の座標をまとめて取得します：

```hlsl
lilVertexPositionInputs vertexInput;
LIL_VERTEX_POSITION_INPUTS(positionOS, vertexInput);

// 利用可能なメンバー
vertexInput.positionWS  // ワールド空間座標 (float3)
vertexInput.positionVS  // ビュー空間座標 (float3)
vertexInput.positionCS  // クリップ空間座標 (float4)
vertexInput.positionSS  // スクリーン空間座標 (float4)
```

再計算が必要な場合：

```hlsl
LIL_RE_VERTEX_POSITION_INPUTS(vertexInput);
```

---

## 頂点法線・タンジェント入力マクロ（lilVertexNormalInputs）

```hlsl
lilVertexNormalInputs vertexNormalInput;
LIL_VERTEX_NORMAL_TANGENT_INPUTS(normalOS, tangentOS, vertexNormalInput);

// 利用可能なメンバー
vertexNormalInput.tangentWS    // タンジェント（ワールド空間）
vertexNormalInput.bitangentWS  // バイタンジェント（ワールド空間）
vertexNormalInput.normalWS     // 法線（ワールド空間）
```

---

## その他のユーティリティ関数

| 関数 | 説明 |
|------|------|
| `lilCalcUV(float2 uv, float4 tex_ST, float4 tex_ScrollRotate)` | UV 計算（スクロール・回転対応） |
| `lilBlendColor(float3 dstCol, float3 srcCol, float srcA, uint blendMode)` | ブレンドモード適用 |
| `lilUnpackNormalScale(float4 normalTex, float scale)` | 法線マップ展開（スケール付き） |
| `lilTooning(...)` | トゥーン化処理 |

---

## lilFragData 構造体

ピクセルシェーダー全体で使用される共通データ構造体です。
`BEFORE_*` / `OVERRIDE_*` マクロ内で `fd` 変数としてアクセスします。

### 色情報

| メンバー | 型 | 説明 |
|---------|-----|------|
| `fd.col` | `float4` | 現在の色（アルファ含む） |
| `fd.albedo` | `float4` | アルベド色 |
| `fd.emissionColor` | `float4` | エミッションカラー |

### ライティング情報

| メンバー | 型 | 説明 |
|---------|-----|------|
| `fd.lightColor` | `float3` | 直接光の色 |
| `fd.indLightColor` | `float3` | 間接光の色 |
| `fd.addLightColor` | `float3` | 追加ライトの色 |
| `fd.attenuation` | `float` | 光の減衰値 |
| `fd.invLighting` | `float` | 逆ライティング値 |

### UV 座標

| メンバー | 型 | 説明 |
|---------|-----|------|
| `fd.uv0` | `float2` | TEXCOORD0 |
| `fd.uv1` | `float2` | TEXCOORD1 |
| `fd.uv2` | `float2` | TEXCOORD2 |
| `fd.uv3` | `float2` | TEXCOORD3 |
| `fd.uvMain` | `float2` | メイン UV（スクロール・回転適用済み） |
| `fd.uvMat` | `float2` | MatCap UV |
| `fd.uvRim` | `float2` | リムライト UV |
| `fd.uvPanorama` | `float2` | パノラマ UV |
| `fd.uvScn` | `float2` | スクリーン UV |

### 座標データ

| メンバー | 型 | 説明 |
|---------|-----|------|
| `fd.positionOS` | `float3` | オブジェクト空間座標 |
| `fd.positionWS` | `float3` | ワールド空間座標 |
| `fd.positionCS` | `float4` | クリップ空間座標 |
| `fd.positionSS` | `float4` | スクリーン空間座標 |
| `fd.depth` | `float` | 深度値 |

### ベクトル情報

| メンバー | 型 | 説明 |
|---------|-----|------|
| `fd.TBN` | `float3x3` | タンジェント空間行列 |
| `fd.T` | `float3` | タンジェントベクトル（WS） |
| `fd.B` | `float3` | バイタンジェントベクトル（WS） |
| `fd.N` | `float3` | 法線ベクトル（WS） |
| `fd.V` | `float3` | 視線ベクトル（WS） |
| `fd.L` | `float3` | ライトベクトル（WS） |
| `fd.origN` | `float3` | 元の法線（補正前） |
| `fd.origL` | `float3` | 元のライトベクトル |
| `fd.headV` | `float3` | ヘッド方向ベクトル |
| `fd.reflectionN` | `float3` | 反射用法線 |
| `fd.matcapN` | `float3` | MatCap 用法線 |
| `fd.matcap2ndN` | `float3` | MatCap（2枚目）用法線 |

### 内積キャッシュ（計算済み値）

| メンバー | 説明 |
|---------|------|
| `fd.vl` | dot(V, L) |
| `fd.hl` | half vector と L の内積 |
| `fd.ln` | dot(L, N) |
| `fd.nv` | dot(N, V) |
| `fd.nvabs` | abs(dot(N, V)) |

### 物理ベース値

| メンバー | 説明 |
|---------|------|
| `fd.smoothness` | スムースネス |
| `fd.roughness` | ラフネス |
| `fd.perceptualRoughness` | 知覚ラフネス |

### その他

| メンバー | 説明 |
|---------|------|
| `fd.facing` | 表裏判定（`bool` 相当） |
| `fd.isRightHand` | 右手系かどうか |
| `fd.triMask` | トライアングルマスク |
| `fd.parallaxViewDirection` | 視差用視線ベクトル |
| `fd.parallaxOffset` | 視差オフセット |
| `fd.anisotropy` | 異方性値 |
| `fd.shadowmix` | シャドウミックス値 |
| `fd.audioLinkValue` | AudioLink 値 |
| `fd.renderingLayers` | レンダリングレイヤー |
| `fd.featureFlags` | フィーチャーフラグ |
| `fd.tileIndex` | タイルインデックス |
