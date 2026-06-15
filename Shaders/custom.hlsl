//----------------------------------------------------------------------------------------------------------------------
// Macro

// Custom variables
// float・float4 等の通常変数はここに定義する（行末のバックスラッシュを忘れずに）
// 対応する ShaderLab プロパティは lilCustomShaderProperties.lilblock に記述する
// 画面空間疑似影（SSAO / Contact Shadow）用パラメーター
#define LIL_CUSTOM_PROPERTIES            \
    float _SSAO_Enable;                 \
    float _SSAO_Radius;                 \
    float _SSAO_Samples;                \
    float _SSAO_Intensity;              \
    float _SSAO_Bias;                   \
    float _ContactShadow_Enable;        \
    float _ContactShadow_Steps;         \
    float _ContactShadow_Length;        \
    float _ContactShadow_Thickness;     \
    float _ContactShadow_Intensity;     \
    float4 _ShadowEx_ShadowColor;       \
    float _ShadowEx_ColorBlend;         \
    float _ShadowEx_ShadowLift;         \
    float _ShadowEx_FadeStart;          \
    float _ShadowEx_FadeEnd;

// Custom textures
// TEXTURE2D はここに定義する（SAMPLER は sampler_linear_repeat 等の共有サンプラーを流用可能）
// 例: TEXTURE2D(_CustomTex); SAMPLER(sampler_CustomTex);
#define LIL_CUSTOM_TEXTURES

// Add vertex shader input
//#define LIL_REQUIRE_APP_POSITION
//#define LIL_REQUIRE_APP_TEXCOORD0
//#define LIL_REQUIRE_APP_TEXCOORD1
//#define LIL_REQUIRE_APP_TEXCOORD2
//#define LIL_REQUIRE_APP_TEXCOORD3
//#define LIL_REQUIRE_APP_TEXCOORD4
//#define LIL_REQUIRE_APP_TEXCOORD5
//#define LIL_REQUIRE_APP_TEXCOORD6
//#define LIL_REQUIRE_APP_TEXCOORD7
//#define LIL_REQUIRE_APP_COLOR
//#define LIL_REQUIRE_APP_NORMAL
//#define LIL_REQUIRE_APP_TANGENT
//#define LIL_REQUIRE_APP_VERTEXID

// Add vertex shader output
//#define LIL_V2F_FORCE_TEXCOORD0
//#define LIL_V2F_FORCE_TEXCOORD1
//#define LIL_V2F_FORCE_POSITION_OS
// 画面空間影の計算にワールド座標が必須なので強制的に v2f へ含める
#define LIL_V2F_FORCE_POSITION_WS
//#define LIL_V2F_FORCE_POSITION_SS
//#define LIL_V2F_FORCE_NORMAL
//#define LIL_V2F_FORCE_TANGENT
//#define LIL_V2F_FORCE_BITANGENT
//#define LIL_CUSTOM_V2F_MEMBER(id0,id1,id2,id3,id4,id5,id6,id7)

// Add vertex copy
// ジオメトリシェーダーを使う場合に定義する
// appdataCopy 型と appdataOriginalToCopy() 関数が生成され、
// vertCustom() / geomCustom() を custom_insert_post.hlsl で定義できるようになる
// 不要な場合はコメントアウト: //#define LIL_CUSTOM_VERT_COPY
#define LIL_CUSTOM_VERT_COPY

// Inserting a process into the vertex shader
// LIL_CUSTOM_VERTEX_OS: オブジェクト空間で処理する（positionOS の変形など）
//   使用可能な変数: inout appdata input, inout float2 uvMain, inout float4 positionOS
// LIL_CUSTOM_VERTEX_WS: ワールド空間で処理する
//   使用可能な変数: inout appdata input, inout float2 uvMain,
//                  inout lilVertexPositionInputs vertexInput,
//                  inout lilVertexNormalInputs vertexNormalInput
//#define LIL_CUSTOM_VERTEX_OS
//#define LIL_CUSTOM_VERTEX_WS

// Inserting a process into pixel shader
// BEFORE_xx : 指定処理の直前に割り込む  例: #define BEFORE_EMISSION_1ST fd.emissionColor.rgb *= 2.0;
// OVERRIDE_xx: 指定処理を完全に上書きする  例: #define OVERRIDE_OUTPUT return float4(fd.col.rgb, 1.0);
// xx に入るキーワード（処理順）:
//   UNPACK_V2F / ANIMATE_MAIN_UV / ANIMATE_OUTLINE_UV / PARALLAX / MAIN / OUTLINE_COLOR /
//   FUR / ALPHAMASK / DISSOLVE / NORMAL_1ST / NORMAL_2ND / ANISOTROPY / AUDIOLINK /
//   MAIN2ND / MAIN3RD / SHADOW / BACKLIGHT / REFRACTION / REFLECTION /
//   MATCAP / MATCAP_2ND / RIMLIGHT / GLITTER / EMISSION_1ST / EMISSION_2ND /
//   DISSOLVE_ADD / BLEND_EMISSION / DISTANCE_FADE / FOG / OUTPUT
// ピクセルシェーダー内では lilFragData fd のメンバーを読み書きする（下記リファレンス参照）
//#define BEFORE_xx
//#define OVERRIDE_xx

// 最終出力の直前に画面空間疑似影（SSAO + Contact Shadow）を乗算する。
// lilApplyScreenSpaceShadow() の実体は custom_insert.hlsl（Unity 関数依存のため）。
// OUTPUT 直前は機能トグルに依存せず必ず実行されるため、確実に影を適用できる。
// 注意: この時点で fd.col にはエミッションも加算済みのため、エミッション部もわずかに減衰する。
//       エミッションを減衰させたくない場合は BEFORE_EMISSION_1ST に変更する
//       （ただしエミッション機能が無効なマテリアルでは挿入点ごと消える点に注意）。
#define BEFORE_OUTPUT lilApplyScreenSpaceShadow(fd.col, fd.albedo, fd.positionWS, fd.N, fd.origL, fd.uvScn * _ScreenParams.xy);

//----------------------------------------------------------------------------------------------------------------------
// Information about variables
//----------------------------------------------------------------------------------------------------------------------

//----------------------------------------------------------------------------------------------------------------------
// Vertex shader inputs (appdata structure)
//
// Type     Name                    Description
// -------- ----------------------- --------------------------------------------------------------------
// float4   input.positionOS        POSITION
// float2   input.uv0               TEXCOORD0
// float2   input.uv1               TEXCOORD1
// float2   input.uv2               TEXCOORD2
// float2   input.uv3               TEXCOORD3
// float2   input.uv4               TEXCOORD4
// float2   input.uv5               TEXCOORD5
// float2   input.uv6               TEXCOORD6
// float2   input.uv7               TEXCOORD7
// float4   input.color             COLOR
// float3   input.normalOS          NORMAL
// float4   input.tangentOS         TANGENT
// uint     vertexID                SV_VertexID

//----------------------------------------------------------------------------------------------------------------------
// Vertex shader outputs or pixel shader inputs (v2f structure)
//
// The structure depends on the pass.
// Please check lil_pass_xx.hlsl for details.
//
// Type     Name                    Description
// -------- ----------------------- --------------------------------------------------------------------
// float4   output.positionCS       SV_POSITION
// float2   output.uv01             TEXCOORD0 TEXCOORD1
// float2   output.uv23             TEXCOORD2 TEXCOORD3
// float3   output.positionOS       object space position
// float3   output.positionWS       world space position
// float3   output.normalWS         world space normal
// float4   output.tangentWS        world space tangent

//----------------------------------------------------------------------------------------------------------------------
// Variables commonly used in the forward pass
//
// These are members of `lilFragData fd`
//
// Type     Name                    Description
// -------- ----------------------- --------------------------------------------------------------------
// float4   col                     lit color
// float3   albedo                  unlit color
// float3   emissionColor           color of emission
// -------- ----------------------- --------------------------------------------------------------------
// float3   lightColor              color of light
// float3   indLightColor           color of indirectional light
// float3   addLightColor           color of additional light
// float    attenuation             attenuation of light
// float3   invLighting             saturate((1.0 - lightColor) * sqrt(lightColor));
// -------- ----------------------- --------------------------------------------------------------------
// float2   uv0                     TEXCOORD0
// float2   uv1                     TEXCOORD1
// float2   uv2                     TEXCOORD2
// float2   uv3                     TEXCOORD3
// float2   uvMain                  Main UV
// float2   uvMat                   MatCap UV
// float2   uvRim                   Rim Light UV
// float2   uvPanorama              Panorama UV
// float2   uvScn                   Screen UV
// bool     isRightHand             input.tangentWS.w > 0.0;
// -------- ----------------------- --------------------------------------------------------------------
// float3   positionOS              object space position
// float3   positionWS              world space position
// float4   positionCS              clip space position
// float4   positionSS              screen space position
// float    depth                   distance from camera
// -------- ----------------------- --------------------------------------------------------------------
// float3x3 TBN                     tangent / bitangent / normal matrix
// float3   T                       tangent direction
// float3   B                       bitangent direction
// float3   N                       normal direction
// float3   V                       view direction
// float3   L                       light direction
// float3   origN                   normal direction without normal map
// float3   origL                   light direction without sh light
// float3   headV                   middle view direction of 2 cameras
// float3   reflectionN             normal direction for reflection
// float3   matcapN                 normal direction for reflection for MatCap
// float3   matcap2ndN              normal direction for reflection for MatCap 2nd
// float    facing                  VFACE
// -------- ----------------------- --------------------------------------------------------------------
// float    vl                      dot(viewDirection, lightDirection);
// float    hl                      dot(headDirection, lightDirection);
// float    ln                      dot(lightDirection, normalDirection);
// float    nv                      saturate(dot(normalDirection, viewDirection));
// float    nvabs                   abs(dot(normalDirection, viewDirection));
// -------- ----------------------- --------------------------------------------------------------------
// float4   triMask                 TriMask (for lite version)
// float3   parallaxViewDirection   mul(tbnWS, viewDirection);
// float2   parallaxOffset          parallaxViewDirection.xy / (parallaxViewDirection.z+0.5);
// float    anisotropy              strength of anisotropy
// float    smoothness              smoothness
// float    roughness               roughness
// float    perceptualRoughness     perceptual roughness
// float    shadowmix               this variable is 0 in the shadow area
// float    audioLinkValue          volume acquired by AudioLink
// -------- ----------------------- --------------------------------------------------------------------
// uint     renderingLayers         light layer of object (for URP / HDRP)
// uint     featureFlags            feature flags (for HDRP)
// uint2    tileIndex               tile index (for HDRP)