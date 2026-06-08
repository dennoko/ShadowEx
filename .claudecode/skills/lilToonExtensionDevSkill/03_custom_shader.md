# カスタムシェーダーの作り方

> 公式: https://lilxyzw.github.io/lilToon/ja_JP/dev/custom_shader.html

---

## 基本的な流れ

`Template.zip` を展開して開発を開始します。

### 編集が必要なファイル

| ファイル | 役割 |
|---------|------|
| `Shaders/custom.hlsl` | 変数定義・頂点/ピクセル処理の実装 |
| `Shaders/custom_insert.hlsl` | Unity 関数に依存する処理（パスごとの条件分岐） |
| `Shaders/lilCustomShaderDatas.lilblock` | シェーダー名・エディター名・置換設定 |
| `Shaders/lilCustomShaderProperties.lilblock` | ShaderLab プロパティの追加定義 |
| `Editor/CustomInspector.cs` | カスタム Inspector GUI |
| `Editor/TemplateFull.asmdef` | Assembly Definition（名前変更が必要） |

> バリエーション数が多いため、不要なシェーダーバリエーションは削除推奨。
> ルートフォルダ名は任意に変更可能。

---

## シェーダー名の設定

3箇所の編集が必要です：

| ファイル | 編集箇所 |
|---------|---------|
| `Shaders/lilCustomShaderDatas.lilblock` | `<ShaderName>` タグ内 |
| `Editor/CustomInspector.cs` | `shaderName` 変数 |
| `Editor/TemplateFull.asmdef` | `name` フィールドおよびファイル名 |

---

## マテリアル変数の追加

### 1. プロパティの定義（lilCustomShaderProperties.lilblock）

```hlsl
[lilVec3]       _CustomVertexWaveScale      ("Vertex Wave Scale", Vector) = (10.0,10.0,10.0,0.0)
[lilVec3]       _CustomVertexWaveStrength   ("Vertex Wave Strength", Vector) = (0.0,0.1,0.0,0.0)
                _CustomVertexWaveSpeed      ("Vertex Wave Speed", float) = 10.0
[NoScaleOffset] _CustomVertexWaveMask       ("Vertex Wave Mask", 2D) = "white" {}
```

### 2. HLSL 変数の定義（custom.hlsl）

通常変数とテクスチャは別々のマクロで定義します：

```hlsl
// 通常変数（float, float4 等）
#define LIL_CUSTOM_PROPERTIES \
    float4  _CustomVertexWaveScale;     \
    float4  _CustomVertexWaveStrength;  \
    float   _CustomVertexWaveSpeed;

// テクスチャ
#define LIL_CUSTOM_TEXTURES \
    TEXTURE2D(_CustomVertexWaveMask);
```

---

## 関数・include の追加

Unity 関数に依存する処理は `custom_insert.hlsl` に記述します。
このファイルではパスごとに以下のマクロが定義されているため、
`#if defined(...)` で処理を分岐できます：

| マクロ | 対応パス |
|--------|---------|
| `LIL_PASS_FORWARD` | ForwardBase、UniversalForward 等 |
| `LIL_PASS_FORWARDADD` | ForwardAdd（BRP のみ） |
| `LIL_PASS_SHADOWCASTER` | ShadowCaster |
| `LIL_PASS_DEPTHONLY` | DepthOnly（URP / HDRP のみ） |
| `LIL_PASS_DEPTHNORMALS` | DepthNormals（URP のみ） |
| `LIL_PASS_MOTIONVECTORS` | MotionVectors（HDRP のみ） |
| `LIL_PASS_META` | META |

---

## 頂点シェーダー入力の追加（appdata 構造体）

`custom.hlsl` で `#define` することで対応する入力セマンティクスが有効になります：

| キーワード | 変数名 | セマンティクス |
|-----------|--------|---------------|
| `LIL_REQUIRE_APP_POSITION` | `positionOS` | `POSITION` |
| `LIL_REQUIRE_APP_TEXCOORD0` | `uv` | `TEXCOORD0` |
| `LIL_REQUIRE_APP_TEXCOORD1` | `uv1` | `TEXCOORD1` |
| `LIL_REQUIRE_APP_TEXCOORD2` | `uv2` | `TEXCOORD2` |
| `LIL_REQUIRE_APP_TEXCOORD3` | `uv3` | `TEXCOORD3` |
| `LIL_REQUIRE_APP_TEXCOORD4` | `uv4` | `TEXCOORD4` |
| `LIL_REQUIRE_APP_TEXCOORD5` | `uv5` | `TEXCOORD5` |
| `LIL_REQUIRE_APP_TEXCOORD6` | `uv6` | `TEXCOORD6` |
| `LIL_REQUIRE_APP_TEXCOORD7` | `uv7` | `TEXCOORD7` |
| `LIL_REQUIRE_APP_COLOR` | `color` | `COLOR` |
| `LIL_REQUIRE_APP_NORMAL` | `normalOS` | `NORMAL` |
| `LIL_REQUIRE_APP_TANGENT` | `tangentOS` | `TANGENT` |
| `LIL_REQUIRE_APP_VERTEXID` | `vertexID` | `SV_VertexID` |

---

## 頂点シェーダー出力の追加（v2f 構造体）

`LIL_CUSTOM_V2F_MEMBER` マクロでカスタムメンバーを追加します：

```hlsl
#define LIL_CUSTOM_V2F_MEMBER(id0, id1, id2, id3) \
    float4 customData : TEXCOORD##id0;
```

既存メンバーを強制的に有効にしたい場合は `LIL_V2F_FORCE_*` マクロを使います：

```hlsl
#define LIL_V2F_FORCE_TEXCOORD1   // uv1 を常に v2f に含める
#define LIL_V2F_FORCE_NORMAL      // normalWS を常に v2f に含める
```

---

## 頂点シェーダーへの処理挿入

### LIL_CUSTOM_VERTEX_OS（オブジェクト空間で処理）

positionOS を変形させる場合などに使用します。

```hlsl
#define LIL_CUSTOM_VERTEX_OS \
    positionOS.y += sin(_Time.y * _CustomVertexWaveSpeed + \
        positionOS.x * _CustomVertexWaveScale.x) * _CustomVertexWaveStrength.y;
```

利用可能な変数：

| 変数 | 型 | 説明 |
|------|-----|------|
| `input` | `inout appdata` | 頂点入力データ |
| `uvMain` | `inout float2` | メイン UV |
| `positionOS` | `inout float4` | オブジェクト空間座標 |

### LIL_CUSTOM_VERTEX_WS（ワールド空間で処理）

ワールド座標での変形処理に使用します。

利用可能な変数：

| 変数 | 型 | 説明 |
|------|-----|------|
| `input` | `inout appdata` | 頂点入力データ |
| `uvMain` | `inout float2` | メイン UV |
| `vertexInput` | `inout lilVertexPositionInputs` | 各空間の座標 |
| `vertexNormalInput` | `inout lilVertexNormalInputs` | 法線・タンジェント |

---

## ピクセルシェーダーへの処理挿入

`BEFORE_*` または `OVERRIDE_*` プレフィックスのマクロで処理を挿入・上書きします。

```hlsl
// 例: メインカラー計算の直前に処理を挿入
#define BEFORE_MAIN \
    fd.col.rgb = pow(fd.col.rgb, 2.2);

// 例: エミッションを完全に上書き
#define OVERRIDE_EMISSION_1ST \
    fd.emissionColor = float4(1.0, 0.0, 0.0, 1.0);
```

### 対応キーワード一覧

| キーワード | タイミング |
|-----------|-----------|
| `UNPACK_V2F` | v2f アンパック |
| `ANIMATE_MAIN_UV` | メイン UV アニメーション |
| `ANIMATE_OUTLINE_UV` | アウトライン UV アニメーション |
| `PARALLAX` | 視差マッピング |
| `MAIN` | メインカラー計算 |
| `OUTLINE_COLOR` | アウトラインカラー |
| `FUR` | ファー処理 |
| `ALPHAMASK` | アルファマスク |
| `DISSOLVE` | ディゾルブ |
| `NORMAL_1ST` | 法線マップ（1枚目） |
| `NORMAL_2ND` | 法線マップ（2枚目） |
| `ANISOTROPY` | 異方性反射 |
| `AUDIOLINK` | AudioLink |
| `MAIN2ND` | メインカラー（2枚目） |
| `MAIN3RD` | メインカラー（3枚目） |
| `SHADOW` | シャドウ |
| `BACKLIGHT` | バックライト |
| `REFRACTION` | 屈折 |
| `REFLECTION` | 反射 |
| `MATCAP` | MatCap（1枚目） |
| `MATCAP_2ND` | MatCap（2枚目） |
| `RIMLIGHT` | リムライト |
| `GLITTER` | グリッタ |
| `EMISSION_1ST` | エミッション（1枚目） |
| `EMISSION_2ND` | エミッション（2枚目） |
| `DISSOLVE_ADD` | ディゾルブ加算 |
| `BLEND_EMISSION` | エミッションブレンド |
| `DISTANCE_FADE` | 距離フェード |
| `FOG` | フォグ |
| `OUTPUT` | 最終出力 |

---

## Inspector の拡張

`Editor/CustomInspector.cs` を以下の手順で編集します：

### 1. クラス名と EditorName の変更

```csharp
// クラス名を変更
public class MyCustomInspector : lilToonInspector
{
    // shaderName: lilCustomShaderDatas.lilblock の EditorName タグと一致させる
    public override string shaderName => "MyShader/Custom";
}
```

### 2. MaterialProperty の宣言

```csharp
MaterialProperty _CustomVertexWaveScale;
MaterialProperty _CustomVertexWaveStrength;
MaterialProperty _CustomVertexWaveSpeed;
MaterialProperty _CustomVertexWaveMask;
```

### 3. LoadCustomProperties() のオーバーライド

```csharp
protected override void LoadCustomProperties(MaterialProperty[] props, Material material)
{
    _CustomVertexWaveScale    = FindProperty("_CustomVertexWaveScale", props);
    _CustomVertexWaveStrength = FindProperty("_CustomVertexWaveStrength", props);
    _CustomVertexWaveSpeed    = FindProperty("_CustomVertexWaveSpeed", props);
    _CustomVertexWaveMask     = FindProperty("_CustomVertexWaveMask", props);
}
```

### 4. DrawCustomProperties() で GUI を実装

```csharp
protected override void DrawCustomProperties(Material material)
{
    // 折りたたみ付きセクション
    if (Foldout("Vertex Wave", "vertex_wave", true))
    {
        EditorGUILayout.BeginVertical(boxInner);
        m_MaterialEditor.ShaderProperty(_CustomVertexWaveScale, "Wave Scale");
        m_MaterialEditor.ShaderProperty(_CustomVertexWaveStrength, "Wave Strength");
        m_MaterialEditor.ShaderProperty(_CustomVertexWaveSpeed, "Wave Speed");
        m_MaterialEditor.TexturePropertySingleLine(
            new GUIContent("Wave Mask"), _CustomVertexWaveMask);
        EditorGUILayout.EndVertical();
    }
}
```

### 利用可能な GUIStyle

| スタイル名 | 用途 |
|-----------|------|
| `boxOuter` | 外側ボックス |
| `boxInnerHalf` | 内側ボックス（半幅） |
| `boxInner` | 内側ボックス |
| `customBox` | カスタムボックス |
| `customToggleFont` | トグル用フォント |

### 利用可能なヘルパー関数

| 関数 | 説明 |
|------|------|
| `Foldout(label, key, defaultOpen)` | 折りたたみセクション |
| `DrawLine()` | 区切り線 |
| `DrawWebButton(label, url)` | Web リンクボタン |
| `LoadCustomLanguage(guid)` | 言語ファイルの読み込み |

---

## 作例

公式が提供するジオメトリシェーダー利用例：`lilToonGeometryFX_1.0.2.unitypackage`

ジオメトリシェーダーを使った高度な拡張の参考実装として利用できます。
