#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Assets/Shader/Library/Noise.hlsl"

struct vertex
{
    float3 vertex : POSITION;
};

struct v2f
{
    float4 positionCS : SV_POSITION;
    float3 positionWS:TEXCOORD0;
    float4 screenPos : TEXCOORD1;
    float3 positionVS : TEXCOORD2;
};

TEXTURE2D(_CameraDepthTexture);
SAMPLER(sampler_CameraDepthTexture);

half4 _BaseColor;
half4 _EdgeColor;
float _EdgeWidth;

float _NoiseParameter;
float _NoisePow;
float _NoiseThreshold;
half4 _NoiseColor;

float _Temp;

v2f vert(vertex v)
{
    v2f o;
    o.positionCS = TransformObjectToHClip(v.vertex);
    o.positionWS = TransformObjectToWorld(v.vertex);
    o.screenPos = ComputeScreenPos(o.positionCS);
    o.positionVS = TransformWorldToView(o.positionWS);

    return o;
}

half4 frag(v2f i) : SV_Target
{
    float2 uv = i.screenPos.xy / i.screenPos.w;

    // 从 _CameraDepthTexture 采样的 raw 深度
    float rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv);
    float sceneDepth = LinearEyeDepth(rawDepth, _ZBufferParams);
    
    float selfDepth = -i.positionVS.z; // 注意 VS 中 -Z 是朝向摄像机的

    // 为了视觉一致，使用深度比例缩放
    float adaptiveEdgeWidth = _EdgeWidth * selfDepth;

    // 计算深度差异
    float depthDiff = sceneDepth - selfDepth;
    float t = saturate(depthDiff / adaptiveEdgeWidth);

    // 插值颜色（边缘色 -> 基础色）
    half4 finalColor = lerp(_EdgeColor, _BaseColor, t);


    float3 pos = i.positionWS;
    pos.y -= _Time.y;
    float noise = 1 - turbulence3D(pos * _NoiseParameter);
    noise = pow(noise, _NoisePow);

    /////////////////////
    // if (noise > _NoiseThreshold)
    // {
    //     finalColor = _NoiseColor;
    // }
    /////////////////////
    finalColor = lerp(finalColor, _NoiseColor, step(_NoiseThreshold, noise));

    return finalColor;
    return half4(noise, noise, noise, 1);
}
