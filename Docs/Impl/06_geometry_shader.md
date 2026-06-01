# ジオメトリシェーダーの挿入

> 参考実装: `lilToonGeometryFX_1.0.2.unitypackage`

通常の `BEFORE_*` / `OVERRIDE_*` マクロはピクセルシェーダーへの挿入のみ対応しています。
ジオメトリシェーダーを追加する場合は、別の仕組みを使います。

---

## 全体の仕組み

ジオメトリシェーダー追加に必要な操作は2つです：

1. **`#pragma geometry geomCustom` を差し込む** — `lilCustomShaderDatas.lilblock` の `Replace` でプラグマ行を置換
2. **ジオメトリシェーダー本体を定義する** — `custom_insert_post.hlsl` に実装し、`lilSubShaderInsertPost` で注入

```
lilCustomShaderDatas.lilblock
  └─ Replace で "#pragma vertex vert" → "#pragma vertex vertCustom + #pragma geometry geomCustom"

ltspass_opaque.lilcontainer
  ├─ lilSubShaderInsert    "lilCustomShaderInsert.lilblock"     ← Unity ライブラリ include 直後
  └─ lilSubShaderInsertPost "lilCustomShaderInsertPost.lilblock" ← vert() 定義の後
         └─ #include "custom_insert_post.hlsl"
                └─ vertCustom() / geomCustom() の定義
```

---

## ステップ 1: `#pragma` 行を置換する

`lilCustomShaderDatas.lilblock` の `Replace` タグで、自動生成されるプラグマ行を書き換えます。

### 通常シェーダー（テッセレーションなし）

```
Replace "            #pragma vertex vert\r\n            #pragma fragment frag\r\n" \
        "            #pragma vertex vertCustom\r\n            #pragma geometry geomCustom\r\n            #pragma fragment frag\r\n            #pragma require geometry\r\n"
```

| 置換前 | 置換後 |
|--------|--------|
| `#pragma vertex vert` | `#pragma vertex vertCustom` |
| `#pragma fragment frag` | `#pragma geometry geomCustom` + `#pragma fragment frag` + `#pragma require geometry` |

### テッセレーション付きシェーダー

```
Replace "            #pragma vertex vertTess\r\n            #pragma fragment frag\r\n            #pragma hull hull\r\n            #pragma domain domain\r\n            #pragma require tesshw tessellation\r\n" \
        "            #pragma vertex vertTess\r\n            #pragma fragment frag\r\n            #pragma hull hull\r\n            #pragma domain domainCustom\r\n            #pragma geometry geomCustom\r\n            #pragma require tesshw tessellation geometry\r\n"
```

テッセレーションありの場合は `domain` → `domainCustom` にも置換し、
`domainCustom` から頂点をジオメトリシェーダーに渡す形にします。

> **注意**: `Replace` の文字列はインデント（スペース12個）・改行コード（`\r\n`）を含む完全一致です。
> lilToon が生成するプラグマ行のインデントと正確に合わせる必要があります。

---

## ステップ 2: `.lilcontainer` に挿入フックを追加

`ltspass_*.lilcontainer` に `lilSubShaderInsertPost` を追加します：

```hlsl
Shader "Hidden/*LIL_SHADER_NAME*/ltspass_opaque"
{
    HLSLINCLUDE
        #define LIL_RENDER 0
        #include "custom.hlsl"
    ENDHLSL

    lilSubShaderInsert     "lilCustomShaderInsert.lilblock"      // Unity ライブラリ直後
    lilSubShaderInsertPost "lilCustomShaderInsertPost.lilblock"  // vert() 定義の後
    lilSubShaderBRP "Default"
    lilSubShaderURP "Default"
    lilSubShaderHDRP "Default"

    CustomEditor "*LIL_EDITOR_NAME*"
}
```

### lilSubShaderInsert vs lilSubShaderInsertPost

| キーワード | 挿入タイミング |
|-----------|--------------|
| `lilSubShaderInsert` | Unity ライブラリの `#include` 直後 |
| `lilSubShaderInsertPost` | `vert()` 関数定義の**後**（ジオメトリシェーダー定義に最適） |

---

## ステップ 3: `custom.hlsl` の設定

ジオメトリシェーダーに頂点データを渡すために `LIL_CUSTOM_VERT_COPY` を定義します：

```hlsl
// appdata を appdataCopy にコピーする処理を有効化
#define LIL_CUSTOM_VERT_COPY

// 必要な入力セマンティクス
#define LIL_REQUIRE_APP_POSITION
#define LIL_REQUIRE_APP_TEXCOORD0
#define LIL_REQUIRE_APP_TEXCOORD1
#define LIL_REQUIRE_APP_NORMAL
#define LIL_REQUIRE_APP_TANGENT

// カスタム変数
#define LIL_CUSTOM_PROPERTIES \
    uint   _CustomGeometryMode;        \
    float4 _CustomGeometryVector;      \
    float  _CustomGeometrySpeed;       \
    float  _CustomGeometryRandomize;   \
    float  _CustomGeometryMin;         \
    float  _CustomGeometryMax;         \
    // ... 他の変数

// カスタムテクスチャ
#define LIL_CUSTOM_TEXTURES \
    TEXTURE2D(_CustomGeometryMask);    \
    TEXTURE2D(_CustomGeometryNormalMap);
```

### LIL_CUSTOM_VERT_COPY とは

このマクロを定義すると lilToon が `appdataCopy` 型と `appdataOriginalToCopy()` 関数を生成します。

| 型/関数 | 説明 |
|---------|------|
| `appdataCopy` | ジオメトリシェーダーへの入力型（`appdata` と同じ内容） |
| `appdataOriginalToCopy(appdata i)` | `appdata` → `appdataCopy` に変換する関数 |
| `vertCustom(appdata i)` | ジオメトリシェーダー用の頂点シェーダー（`appdataCopy` を返す） |

---

## ステップ 4: `custom_insert_post.hlsl` にシェーダーを実装

`lilSubShaderInsertPost` で読み込まれるファイルに、頂点・ドメイン・ジオメトリシェーダーを定義します。

### 頂点シェーダーラッパー

```hlsl
// ジオメトリシェーダーに渡すための頂点シェーダー
// appdataCopy を返すことでジオメトリシェーダーが加工できる
appdataCopy vertCustom(appdata i)
{
    return appdataOriginalToCopy(i);
}
```

### ジオメトリシェーダーの基本構造

```hlsl
[maxvertexcount(15)]  // 最大出力頂点数（生成する三角形数 × 3）
void geomCustom(
    triangle appdataCopy ic[3],           // 入力: 1 トライアングル（3頂点）
    uint primitiveID : SV_PrimitiveID,    // プリミティブID（ランダム化に使用）
    inout TriangleStream<v2f> outStream   // 出力ストリーム
)
{
    if(_Invisible) return;

    // appdataCopy → appdata に変換して処理
    appdata i[3] = {
        appdataOriginalToCopy(ic[0]),
        appdataOriginalToCopy(ic[1]),
        appdataOriginalToCopy(ic[2])
    };
    LIL_SETUP_INSTANCE_ID(i[0]);

    // --- ここでトライアングルを加工 ---
    appdata i_o[3] = i;
    i_o[0].positionOS.xyz += someOffset;
    i_o[1].positionOS.xyz += someOffset;
    i_o[2].positionOS.xyz += someOffset;

    // 加工後の頂点を vert() で v2f に変換して出力
    v2f base_o[3] = {vert(i_o[0]), vert(i_o[1]), vert(i_o[2])};

    outStream.Append(base_o[0]);
    outStream.Append(base_o[1]);
    outStream.Append(base_o[2]);
    outStream.RestartStrip();
}
```

### GeometryFX の完全実装例

GeometryFX が実装しているジオメトリシェーダーのポイント：

```hlsl
// ファーパスでは不要（ファーは独自のジオメトリシェーダーを持つ）
#if !defined(LIL_PASS_FORWARD_FUR_INCLUDED)

// トップ面（変形後の三角形）を出力するヘルパー
void GenerateTop(appdata i_o[3], v2f base_o[3], float3 triNormal, float3 quadNormal, inout TriangleStream<v2f> outStream)
{
    #if defined(LIL_V2F_NORMAL_WS)
        // シェーディング法線を三角形法線またはクワッド法線に上書き
        if(_CustomGeometryShadingNormal)
        {
            float3 flatNormal = _CustomGeometryShadingNormal == 2 ? quadNormal : triNormal;
            LIL_VERTEX_NORMAL_INPUTS(flatNormal, vertexNormalInput);
            base_o[0].normalWS = vertexNormalInput.normalWS;
            base_o[1].normalWS = vertexNormalInput.normalWS;
            base_o[2].normalWS = vertexNormalInput.normalWS;
        }
    #endif
    outStream.Append(base_o[0]);
    outStream.Append(base_o[1]);
    outStream.Append(base_o[2]);
    outStream.RestartStrip();
}

// サイド面（元の三角形と変形後の三角形の間の壁）を出力するヘルパー
void GenerateSide(appdata i0, appdata i1, appdata i2, appdata i3, v2f base0, v2f base1, v2f base2, v2f base3, inout TriangleStream<v2f> outStream)
{
    #if defined(LIL_V2F_NORMAL_WS)
        // サイドの法線 = サイドの辺から計算
        float3 sideNormal = normalize(cross(
            i1.positionOS.xyz - i0.positionOS.xyz,
            i3.positionOS.xyz - i1.positionOS.xyz
        ));
        LIL_VERTEX_NORMAL_INPUTS(sideNormal, vertexNormalInput);
        base0.normalWS = vertexNormalInput.normalWS;
        base1.normalWS = vertexNormalInput.normalWS;
        base2.normalWS = vertexNormalInput.normalWS;
        base3.normalWS = vertexNormalInput.normalWS;
    #endif
    outStream.Append(base0);
    outStream.Append(base1);
    outStream.Append(base2);
    outStream.Append(base3);
    outStream.RestartStrip();
}

[maxvertexcount(15)]
void geomCustom(triangle appdataCopy ic[3], uint primitiveID : SV_PrimitiveID, inout TriangleStream<v2f> outStream)
{
    if(_Invisible) return;

    appdata i[3] = {appdataOriginalToCopy(ic[0]), appdataOriginalToCopy(ic[1]), appdataOriginalToCopy(ic[2])};
    LIL_SETUP_INSTANCE_ID(i[0]);

    // 三角形の重心・法線・TBN を計算
    float3 triNormal  = normalize(i[0].normalOS  + i[1].normalOS  + i[2].normalOS);
    float3 quadNormal = normalize(cross(i[1].positionOS.xyz - i[0].positionOS.xyz,
                                        i[2].positionOS.xyz - i[0].positionOS.xyz));
    float3 normalOS   = _CustomGeometryMotionNormal ? quadNormal : triNormal;
    float3 tangentOS  = normalize(i[0].tangentOS.xyz + i[1].tangentOS.xyz + i[2].tangentOS.xyz);
    float3 bitangentOS = normalize(cross(normalOS, tangentOS) * i[0].tangentOS.w);
    float3x3 tbnOS    = float3x3(tangentOS, bitangentOS, normalOS);
    float3 positionOS = (i[0].positionOS.xyz + i[1].positionOS.xyz + i[2].positionOS.xyz) * 0.333333;
    float2 uv0        = (i[0].uv0 + i[1].uv0 + i[2].uv0) * 0.333333;

    // マスクテクスチャをサンプリング（ジオメトリシェーダーでは LOD 指定が必須）
    float4 geometryMask = LIL_SAMPLE_2D_LOD(_CustomGeometryMask, sampler_linear_repeat, uv0, 0);

    // アニメーション値を計算（sin波 + ランダムオフセット）
    float animationScale = sin(
        LIL_TIME * _CustomGeometrySpeed +
        dot(animation, _CustomGeometryVector.xyz) +
        _CustomGeometryVector.w +
        frac(sin(primitiveID * 12.9898) * 43758.5453123) * LIL_TWO_PI * _CustomGeometryRandomize
    );
    animationScale = clamp(animationScale, _CustomGeometryMin, _CustomGeometryMax);
    animationScale *= geometryMask.a;

    // オフセット計算（法線・ローカル・ワールド方向）
    float3 commonMotion = 0.0;
    float3 normalVector = lilUnpackNormalScale(
        LIL_SAMPLE_2D_LOD(_CustomGeometryNormalMap, sampler_linear_repeat, uv0, 0),
        _CustomGeometryNormalMapScale) * _CustomGeometryNormalMapStrength;
    normalVector += _CustomGeometryNormalOffset.xyz;
    commonMotion += mul(normalVector, tbnOS) * (animationScale + _CustomGeometryNormalOffset.w);
    commonMotion += _CustomGeometryLocalOffset.xyz * (animationScale + _CustomGeometryLocalOffset.w);
    commonMotion += lilTransformDirWStoOS(_CustomGeometryWorldOffset.xyz, false) * (animationScale + _CustomGeometryWorldOffset.w);

    // 各頂点のシュリンク（三角形を中心に向かって縮小）
    float3 motion[3] = {commonMotion, commonMotion, commonMotion};
    motion[0] += (positionOS - i[0].positionOS.xyz) * (animationScale * _CustomGeometryShrinkStrength + _CustomGeometryShrinkOffset);
    motion[1] += (positionOS - i[1].positionOS.xyz) * (animationScale * _CustomGeometryShrinkStrength + _CustomGeometryShrinkOffset);
    motion[2] += (positionOS - i[2].positionOS.xyz) * (animationScale * _CustomGeometryShrinkStrength + _CustomGeometryShrinkOffset);

    // 変形後の頂点を計算
    appdata i_o[3] = i;
    i_o[0].positionOS.xyz += motion[0];
    i_o[1].positionOS.xyz += motion[1];
    i_o[2].positionOS.xyz += motion[2];

    v2f base_o[3] = {vert(i_o[0]), vert(i_o[1]), vert(i_o[2])};

    // トップ面を出力
    GenerateTop(i_o, base_o, triNormal, quadNormal, outStream);

    // サイド面を出力（オプション）
    if(_CustomGeometryGenerateSide)
    {
        v2f base[3] = {vert(i[0]), vert(i[1]), vert(i[2])};
        GenerateSide(i_o[0], i[0], i_o[1], i[1], base_o[0], base[0], base_o[1], base[1], outStream);
        GenerateSide(i_o[1], i[1], i_o[2], i[2], base_o[1], base[1], base_o[2], base[2], outStream);
        GenerateSide(i_o[2], i[2], i_o[0], i[0], base_o[2], base[2], base_o[0], base[0], outStream);
    }
}
#endif  // LIL_PASS_FORWARD_FUR_INCLUDED
```

---

## テッセレーション + ジオメトリシェーダー

テッセレーション有効時はドメインシェーダーもカスタムにする必要があります。

```hlsl
#if defined(LIL_TESSELLATION_INCLUDED)
[domain("tri")]
appdataCopy domainCustom(
    lilTessellationFactors hsConst,
    const OutputPatch<appdata, 3> input,
    float3 bary : SV_DomainLocation)
{
    appdata output;
    LIL_INITIALIZE_STRUCT(appdata, output);
    LIL_TRANSFER_INSTANCE_ID(input[0], output);

    // 各属性をベアリセントリック補間
    #if defined(LIL_APP_POSITION)
        LIL_TRI_INTERPOLATION(input, output, bary, positionOS);
    #endif
    #if defined(LIL_APP_NORMAL)
        LIL_TRI_INTERPOLATION(input, output, bary, normalOS);
    #endif
    #if defined(LIL_APP_TANGENT)
        LIL_TRI_INTERPOLATION(input, output, bary, tangentOS);
    #endif
    // ... 他の属性も同様に補間

    output.normalOS = normalize(output.normalOS);
    return appdataOriginalToCopy(output);
}
#endif
```

---

## ジオメトリシェーダー内で使えるユーティリティ

| 関数 / マクロ | 説明 |
|--------------|------|
| `vert(appdata i)` | 頂点シェーダーを呼び出して `v2f` を返す |
| `LIL_SAMPLE_2D_LOD(tex, samp, uv, lod)` | テクスチャサンプリング（LOD 指定必須） |
| `LIL_TIME` | シェーダー時間 |
| `LIL_TWO_PI` | 2π定数 |
| `lilTransformOStoWS(pos)` | オブジェクト → ワールド変換 |
| `lilTransformDirWStoOS(dir, normalize)` | ワールド → オブジェクト方向変換 |
| `lilUnpackNormalScale(tex, scale)` | 法線マップ展開 |
| `LIL_VERTEX_NORMAL_INPUTS(normal, out)` | 法線のワールド空間変換 |
| `LIL_INITIALIZE_STRUCT(type, var)` | 構造体をゼロ初期化 |
| `LIL_TRANSFER_INSTANCE_ID(src, dst)` | GPU インスタンシング ID 転送 |
| `LIL_TRI_INTERPOLATION(in, out, bary, member)` | 3頂点のベアリセントリック補間 |

---

## maxvertexcount の計算

`[maxvertexcount(N)]` の N は出力できる最大頂点数です：

| 構成 | 頂点数の計算 |
|------|-------------|
| トップ面のみ | `3`（三角形1枚） |
| トップ + サイド3面（四角形） | `3 + 4×3 = 15` |
| トップ + ボトム | `3 + 3 = 6` |

GPUによっては上限があるため、できるだけ小さく設定します。

---

## ファイル構成まとめ

| ファイル | 役割 |
|---------|------|
| `custom.hlsl` | `LIL_CUSTOM_VERT_COPY`・変数定義・`LIL_REQUIRE_APP_*` |
| `custom_insert.hlsl` | Unity ライブラリ直後に挿入（空でも可） |
| `custom_insert_post.hlsl` | `vertCustom()` / `domainCustom()` / `geomCustom()` の定義 |
| `lilCustomShaderInsert.lilblock` | `#include "custom_insert.hlsl"` の1行のみ |
| `lilCustomShaderInsertPost.lilblock` | `#include "custom_insert_post.hlsl"` の1行のみ |
| `lilCustomShaderDatas.lilblock` | `Replace` でプラグマを書き換え |
| `ltspass_*.lilcontainer` | `lilSubShaderInsertPost` を追加 |
