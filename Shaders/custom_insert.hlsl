// このファイルは Unity ライブラリの #include 直後に挿入される（lilSubShaderInsert）
// パスごとに以下のマクロが定義されているので #if defined(...) で分岐できる
//
//   LIL_PASS_FORWARD       : ForwardBase (BRP) / UniversalForward (URP) / Forward (HDRP)
//   LIL_PASS_FORWARDADD    : ForwardAdd (BRP のみ)
//   LIL_PASS_SHADOWCASTER  : ShadowCaster
//   LIL_PASS_DEPTHONLY     : DepthOnly (URP / HDRP のみ)
//   LIL_PASS_DEPTHNORMALS  : DepthNormals (URP のみ)
//   LIL_PASS_MOTIONVECTORS : MotionVectors (HDRP のみ)
//   LIL_PASS_META          : META (ライトマップベイク用)
//
// ジオメトリシェーダーの定義は vert() より後に挿入が必要なため
// lilSubShaderInsertPost を使い custom_insert_post.hlsl に書く

//----------------------------------------------------------------------------------------------------------------------
// 画面空間疑似影（SSAO + Contact Shadow）
//
// 設計方針（Docs/Impl/requirements.md 準拠）:
//   - _CameraDepthTexture を利用し GrabPass を使わない軽量実装。
//   - VRChat（Built-in Render Pipeline）向け。Unity 標準関数のみを使用する。
//   - このファイルは Unity ライブラリ #include 直後（lilToon ヘルパー定義より前）に
//     挿入されるため、lilTransform* 等の lilToon 関数は使わず Unity 標準関数で実装する。
//   - 関数の呼び出しは custom.hlsl の BEFORE_OUTPUT マクロから行う（fd はそこで有効）。
//   - 深度テクスチャが無いワールドでは sampleDepth が遠方値になり影が出ない（自然なフォールバック）。
//----------------------------------------------------------------------------------------------------------------------
#if defined(LIL_PASS_FORWARD)

// VRChat / BRP では _CameraDepthTexture が供給される。
// lilToon 本体は forward パスで _CameraDepthTexture を宣言しないため、ここで宣言する。
UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
float4 _CameraDepthTexture_TexelSize;

// 指定スクリーン UV の深度バッファをリニア（アイ）深度で取得する。
float lilSSSceneEyeDepth(float2 uv)
{
    float raw = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
    return LinearEyeDepth(raw);
}

// ワールド座標 → スクリーン UV（ComputeScreenPos 準拠：深度テクスチャと同じ座標系）。
float2 lilSSWorldToScreenUV(float3 positionWS)
{
    float4 cs = UnityWorldToClipPos(positionWS);
    float4 ss = ComputeScreenPos(cs);
    return ss.xy / max(ss.w, 1e-5);
}

// ワールド座標のリニア（アイ）深度。ビュー空間 z は手前で負のため符号反転して正にする。
float lilSSWorldToEyeDepth(float3 positionWS)
{
    return -mul(UNITY_MATRIX_V, float4(positionWS, 1.0)).z;
}

// Interleaved Gradient Noise によるディザ値 [0,1)。バンディング低減用。
float lilSSDither(float2 screenPixel)
{
    float3 magic = float3(0.06711056, 0.00583715, 52.9829189);
    return frac(magic.z * frac(dot(screenPixel, magic.xy)));
}

// SSAO: 画面空間で円状にサンプリングし、手前の深度による遮蔽量を求める。
// 戻り値は 0(完全に影) 〜 1(日向) の係数。
float lilSSCalcSSAO(float2 uv, float currentDepth, float dither)
{
    int samples = (int)max(_SSAO_Samples, 1.0);
    float occlusion = 0.0;
    float angStep = 6.2831853 / samples;
    float ang = dither * 6.2831853; // ディザでカーネル全体を回転させ、少サンプルでもノイズを分散

    [loop]
    for(int i = 0; i < samples; i++)
    {
        float2 dir = float2(cos(ang), sin(ang));
        ang += angStep;

        float2 sampleUV = uv + dir * _SSAO_Radius * _CameraDepthTexture_TexelSize.xy;
        float sampleDepth = lilSSSceneEyeDepth(sampleUV);

        // サンプル点が自身より手前にある（遮蔽している）か。_SSAO_Bias で自己遮蔽を防止。
        if(sampleDepth + _SSAO_Bias < currentDepth)
        {
            // 深度差が大きすぎる無関係なオブジェクトによるアーティファクトを減衰。
            float rangeCheck = smoothstep(0.0, 1.0, _SSAO_Radius / max(abs(currentDepth - sampleDepth), 1e-4));
            occlusion += rangeCheck;
        }
    }

    occlusion = (occlusion / samples) * _SSAO_Intensity;
    return saturate(1.0 - occlusion);
}

// Contact Shadow: メインライト方向へ画面空間レイマーチングし、遮蔽物に当たれば影と判定。
// 戻り値は影なし=1.0、影あり=1.0 - _ContactShadow_Intensity。
float lilSSCalcContactShadow(float2 startUV, float currentDepth, float3 positionWS, float3 lightDirWS, float dither)
{
    int steps = (int)max(_ContactShadow_Steps, 1.0);
    float3 L = normalize(lightDirWS);

    // ライト方向へ伸ばしたレイの終点をスクリーン UV / リニア深度に変換。
    float3 endWS = positionWS + L * _ContactShadow_Length;
    float2 endUV = lilSSWorldToScreenUV(endWS);
    float endDepth = lilSSWorldToEyeDepth(endWS);

    float2 stepUV = (endUV - startUV) / steps;
    float stepDepth = (endDepth - currentDepth) / steps;

    float shadow = 1.0;

    [loop]
    for(int i = 1; i <= steps; i++)
    {
        // ディザでステップ位置をずらしバンディングを低減。
        float t = (i - 1.0) + dither;
        float2 sampleUV = startUV + stepUV * t;
        float testDepth = currentDepth + stepDepth * t;

        // 画面外に出たら終了。
        if(sampleUV.x < 0.0 || sampleUV.x > 1.0 || sampleUV.y < 0.0 || sampleUV.y > 1.0) break;

        float sceneDepth = lilSSSceneEyeDepth(sampleUV);

        // レイの仮想深度よりも実オブジェクトが手前にあるか。
        if(sceneDepth + _SSAO_Bias < testDepth)
        {
            // 厚みの閾値で、遥か手前の背景による誤判定（不正な影）を防ぐ。
            if(testDepth - sceneDepth < _ContactShadow_Thickness)
            {
                shadow = 1.0 - _ContactShadow_Intensity; // 遮蔽物を検知（影確定）
                break;                                    // 早期終了
            }
        }
    }

    return shadow;
}

#endif // LIL_PASS_FORWARD

// 画面空間影を fd.col に適用する。BEFORE_OUTPUT から呼ばれる。
// lilFragData を引数に取らない（このファイル挿入時点では未定義のため）。
// 本体は forward パスのみ。それ以外のパス（ForwardAdd 等で BEFORE_OUTPUT が展開されても）では何もしない。
void lilApplyScreenSpaceShadow(inout float4 col, float3 positionWS, float3 lightDirWS, float2 screenPixel)
{
#if defined(LIL_PASS_FORWARD)
    float2 uv = lilSSWorldToScreenUV(positionWS);

    // 画面外に投影される場合（ミラー・特殊カメラ等）は何もしない。
    if(uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return;

    float currentDepth = lilSSWorldToEyeDepth(positionWS);
    float dither = lilSSDither(screenPixel);

    float shadow = 1.0;
    if(_SSAO_Enable > 0.5)
        shadow *= lilSSCalcSSAO(uv, currentDepth, dither);
    if(_ContactShadow_Enable > 0.5)
        shadow *= lilSSCalcContactShadow(uv, currentDepth, positionWS, lightDirWS, dither);

    col.rgb *= shadow;
#endif
}
