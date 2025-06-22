Shader "Roxy/GrayEffectShader"
{
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "RenderPipeline" = "UniversalRenderPipeline"
        }
        Pass
        {
            ZTest Always Cull Off ZWrite Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                uint vertexID : SV_VertexID;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);

            float _Intensity;

            Varyings vert(Attributes input)
            {
                float4 pos = GetFullScreenTriangleVertexPosition(input.vertexID);
                float2 uv = GetFullScreenTriangleTexCoord(input.vertexID);
                Varyings o;
                o.uv = uv;
                o.positionCS = pos;
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                half3 col = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, i.uv).rgb;
                half gray = dot(col, half3(0.3, 0.59, 0.11)) * _Intensity;

                // return half4(1,1,1,1);
                return half4(gray, gray, gray, 1);
            }
            ENDHLSL
        }
    }
}