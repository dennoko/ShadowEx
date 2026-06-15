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

// 1 ピクセルあたりの UV 幅（深度テクスチャは全画面解像度なので画面解像度の逆数と一致）。
#define LIL_SS_TEXEL_SIZE (1.0 / _ScreenParams.xy)

// 深度テクスチャ用のサンプラー（専用名で重複宣言を回避）。
// Unity はサンプラー名に含まれる linear / clamp 等のキーワードからステートを推定する。
SamplerState lilSSDepth_linear_clamp;

// 指定スクリーン UV の深度バッファをリニア（アイ）深度で取得する。
// VR Single Pass Instanced (SPI) 環境に対応するため、テクスチャ配列からのサンプリングを分岐処理する。
float lilSSSceneEyeDepth(float2 uv)
{
    #if defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED)
        // VR (Single Pass Instanced) 時は現在の目に対応したスライスからサンプリング
        float raw = _CameraDepthTexture.SampleLevel(lilSSDepth_linear_clamp, float3(uv, unity_StereoEyeIndex), 0).r;
    #else
        // 通常のシングルパス・マルチパス環境
        float raw = _CameraDepthTexture.SampleLevel(lilSSDepth_linear_clamp, uv, 0).r;
    #endif
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

    // ループ外で三角関数を計算し、回転行列の定数を求める
    float sinStep, cosStep;
    sincos(angStep, sinStep, cosStep);

    float sinAng, cosAng;
    sincos(ang, sinAng, cosAng);
    float2 dir = float2(cosAng, sinAng);

    [loop]
    for(int i = 0; i < samples; i++)
    {
        float2 sampleUV = uv + dir * _SSAO_Radius * LIL_SS_TEXEL_SIZE;
        float sampleDepth = lilSSSceneEyeDepth(sampleUV);

        float depthDiff = currentDepth - sampleDepth;
        // サンプル点が自身より手前にある（遮蔽している）か。_SSAO_Bias で自己遮蔽を防止。
        if(depthDiff > _SSAO_Bias)
        {
            // 物理的な距離ベースのしきい値（maxDepthDiff）を深度から動的に求めてアーティファクト（背景からの影の回り込み）を減衰。
            float maxDepthDiff = _SSAO_Radius * LIL_SS_TEXEL_SIZE.y * currentDepth * 2.0;
            float rangeCheck = smoothstep(0.0, 1.0, maxDepthDiff / max(depthDiff, 1e-4));
            occlusion += rangeCheck;
        }

        // 2D回転行列を用いてベクトルを回転（cos/sinの再呼び出しを回避）
        dir = float2(dir.x * cosStep - dir.y * sinStep, dir.x * sinStep + dir.y * cosStep);
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

        // 画面外に出たら終了 (ベクトル化した高速チェック)
        if(any(sampleUV != saturate(sampleUV))) break;

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
    // 機能が無効化されている場合は、UV変換や深度サンプリングを行う前に早期リターンしてGPU負荷を削減する
    if(_SSAO_Enable <= 0.5 && _ContactShadow_Enable <= 0.5) return;

    float2 uv = lilSSWorldToScreenUV(positionWS);

    // 画面外に投影される場合（ミラー・特殊カメラ等）は何もしない。 (高速なベクトル化チェック)
    if(any(uv != saturate(uv))) return;

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
