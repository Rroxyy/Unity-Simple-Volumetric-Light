Shader "Roxy/VolumetricEffect"
{
    Properties
    {
        [Header(Base)]
        _StepTime("_StepTime",Float)=20
        _Intensity("_Intensity",Float)=0.1
        _Contrast("Contrast",Float)=10
        _RandomNumber("_RandomNumber",Float)=123

        [Header(Light)]
        [HDR]_LightColor("Light Color",Color)=(1,1,1,1)
        _LightPos("Light Position",Vector)=(0,0,0,0)
        _IncomingLoss("_IncomingLoss",Range(0,10))=0
        _LightCosHalfAngle("_LightCosHalfAngle",Float)=0
        _MaxDistance("Max Distance",Float)=0

        [Header(Phase)]
        _Phase("Phase",Float)=0

        [Header(Blur)]
        _BlurStrength("_BlurStrength",Float)=0
        _BlurTex("Blur Texture",2D)="White"{}
        _BlurScale("Blur Scale",Float)=1


        [Header(Test)]
        _Test("Test",Float)=0
    }
    SubShader
    {


        Pass
        {
            Tags
            {
                "RenderType"="Opaque"
                "Queue"="Geometry"
                "RenderPipeline" = "UniversalRenderPipeline"
            }
            Name "Volumetric Base"
            ZTest Always
            Cull Back
            ZWrite Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #define MAIN_LIGHT_CALCULATE_SHADOWS  //定义阴影采样
            #define _MAIN_LIGHT_SHADOWS_CASCADE //启用级联阴影
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Assets/Shader/Noise.hlsl"

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE


            struct Attributes
            {
                uint vertexID : SV_VertexID;
            };

            struct Varyings
            {
                float4 position : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            //渲染图像
            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);

            TEXTURE2D(_BlurTex);
            SAMPLER(sampler_BlurTex);

            float _RandomNumber;
            float _Intensity;
            float _Contrast;
            float _StepTime;

            float4 _LightColor;
            float4 _LightPos;
            float _IncomingLoss;
            float _LightCosHalfAngle;
            float _MaxDistance;

            float _Phase;

            float _BlurScale;

            float _Test;

            Varyings vert(Attributes input)
            {
                float4 pos = GetFullScreenTriangleVertexPosition(input.vertexID);
                float2 uv = GetFullScreenTriangleTexCoord(input.vertexID);


                Varyings o;
                o.uv = uv;
                o.position = pos;

                return o;
            }


            float shadowAt(float3 position)
            {
                float4 shadowPos = TransformWorldToShadowCoord(position); //把采样点的世界坐标转到阴影空间
                float intensity = MainLightRealtimeShadow(shadowPos); //进行shadow map采样
                return intensity;
            }

            // pos 处对光线的衰减率,包括介质对光线的吸收和向外散射
            float3 ExtinctionAt(float3 worldPos)
            {
                return 0.65;
                float2 projectedUV = (worldPos.xz+worldPos.y) * _BlurScale; // 沿 Y 轴投影
                projectedUV = frac(projectedUV); // 保证在 0~1 范围内

                float3 blur = SAMPLE_TEXTURE2D(_BlurTex, sampler_BlurTex, projectedUV).rgb;
                return blur * 0.65;
            }


            //透光率
            float GetTransmittance(float len, float3 pos)
            {
                return exp(-len * ExtinctionAt(pos) * (_IncomingLoss / 100));;
            }

            //描述在宏观上光线在介质中经过散射到各方向上的概率分布
            float Phase(float3 lightDir, float3 viewDir)
            {
                float g = _Phase;
                float cosTheta = dot(normalize(lightDir), normalize(viewDir));
                return (1 - g * g) / (4 * PI * pow(1 + g * g - 2 * g * cosTheta, 1.5));
            }


            float3 lightAt(float3 pos)
            {
                float len = length(_LightPos - pos);
                float transmittance = GetTransmittance(len, pos);

                float3 posToLight = normalize(_LightPos - pos);

                return 1
                    * GetMainLight().color
                    * transmittance
                    * step(_LightCosHalfAngle, dot(GetMainLight().direction, posToLight))
                    * ExtinctionAt(pos);
            }


            float3 scattering(float3 ray, float near, float far)
            {
                float3 totalLight = 0;
                float3 totalShadow = 0;
                float stepSize = (far - near) / _StepTime;
                float transmittance = 1;

                for (int i = 0; i < _StepTime; i++)
                {
                    float3 pos = _WorldSpaceCameraPos + ray * (near + stepSize * i);
                    //从视点到介质中x处的透射率，采用累乘避免多次积分
                    transmittance *= GetTransmittance(stepSize, pos);

                    //散射光线=从介质中x处到视点的透射（光）率*从光源到介质中x处的散射光线*步进权重*从介质中x处到视点的Phase function（粒子直径对散射方向的影响）
                    totalLight +=
                        1
                        * lightAt(pos)
                        * transmittance
                        * stepSize
                        * Phase(GetMainLight().direction, ray)
                        * ExtinctionAt(pos);


                    totalShadow +=
                        1
                        * shadowAt(pos);
                }
                totalLight = totalLight / _StepTime;
                totalLight = pow(totalLight, _Intensity / 10);

                totalShadow = totalShadow / _StepTime;
                totalShadow = pow(totalShadow, _Contrast / 10);

                totalLight *= totalShadow;

                return totalLight;
            }


            half4 frag(Varyings i) : SV_Target
            {
                _StepTime = max(1, _StepTime);
                _StepTime = min(60, _StepTime);

                _LightCosHalfAngle/=100.0f;;

                half3 base = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, i.uv).rgb;

                half d = SampleSceneDepth(i.uv); //(0,1)
                // float3 positionWS = ComputeWorldSpacePosition(i.uv, d, UNITY_MATRIX_I_VP);
                float4 positionCS = float4(i.uv * 2.0 - 1.0, d, 1.0);

                positionCS.y = -positionCS.y;

                float4 hpositionWS = mul(UNITY_MATRIX_I_VP, positionCS);
                half3 positionWS = (half3)hpositionWS.xyz / hpositionWS.w;

                float3 cameraPos = GetCameraPositionWS();


                float3 dir = normalize(positionWS - cameraPos); //视线方向 
                float rayLength = length(positionWS - cameraPos);

                rayLength = min(rayLength, _MaxDistance);

                float3 volumetricLight = scattering(dir, 0.3, rayLength);

                float3 finalColor = base + (volumetricLight);
                // finalColor = finalColor / (finalColor + 1.0);
                // return half4(finalColor, 1);
                return half4(volumetricLight, 1);
                // return half4(base, 1);
                // return half4( _LightPos.xyz,1);
                // return half4(GetMainLight().direction, 1);
                // return half4(cameraPos, 1);
                // return half4(positionWS, 1);
                // return half4(float3(1, 1, 1) * shadowAt(positionWS + dir * _Test), 1);
                // return half4(float3(1, 1, 1) * shadowAt(positionWS), 1);
            }
            ENDHLSL
        }
        Pass
        {
            Name "Blur1"
            Tags
            {
                "RenderType"="Opaque"
                "Queue"="Geometry"
                "RenderPipeline" = "UniversalRenderPipeline"
            }

            ZTest Always
            Cull Back
            ZWrite Off

            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #pragma vertex vert
            #pragma fragment frag

            //渲染图像
            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);

            TEXTURE2D(_BlitTexture);
            SAMPLER(sampler_BlitTexture);

            struct Attributes
            {
                uint vertexID : SV_VertexID;
            };

            struct Varyings
            {
                float4 position : SV_POSITION;
                float2 uv : TEXCOORD0;
            };


            float _Test;
            float _BlurStrength;

            Varyings vert(Attributes input)
            {
                float4 pos = GetFullScreenTriangleVertexPosition(input.vertexID);
                float2 uv = GetFullScreenTriangleTexCoord(input.vertexID);


                Varyings o;
                o.uv = uv;
                o.position = pos;

                return o;
            }

            float3 BlurHorizontal(float2 uv, float blurScale)
            {
                float2 texelSize = 1.0 / _ScreenParams.xy;
                float3 color = float3(0, 0, 0);

                float weights[5] = {0.204164, 0.304005, 0.093913, 0.010381, 0.000336}; // 高斯权重镜像
                color += SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, uv).rgb * weights[0];

                for (int i = 1; i < 5; i++)
                {
                    float2 offset = float2(i, 0) * texelSize * blurScale;
                    color += SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, uv + offset).rgb * weights[
                        i];
                    color += SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, uv - offset).rgb * weights[
                        i];
                }

                return color;
            }


            half4 frag(Varyings i) : SV_Target
            {
                half3 baseTex = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, i.uv).rgb;
                half3 volumetricTex = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, i.uv).rgb;

                half3 bulrValue = BlurHorizontal(i.uv, _BlurStrength);

                return half4(bulrValue, 1);
                return half4(baseTex, 1);
            }
            ENDHLSL
        }
        Pass
        {
            Name "Blur2"
            Tags
            {
                "RenderType"="Opaque"
                "Queue"="Geometry"
                "RenderPipeline" = "UniversalRenderPipeline"
            }

            ZTest Always
            Cull Back
            ZWrite Off

            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #pragma vertex vert
            #pragma fragment frag

            //渲染图像
            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);

            TEXTURE2D(_BlitTexture);
            SAMPLER(sampler_BlitTexture);

            struct Attributes
            {
                uint vertexID : SV_VertexID;
            };

            struct Varyings
            {
                float4 position : SV_POSITION;
                float2 uv : TEXCOORD0;
            };


            float _Test;
            float _BlurStrength;
            float4 _LightColor;

            Varyings vert(Attributes input)
            {
                float4 pos = GetFullScreenTriangleVertexPosition(input.vertexID);
                float2 uv = GetFullScreenTriangleTexCoord(input.vertexID);


                Varyings o;
                o.uv = uv;
                o.position = pos;

                return o;
            }

            float3 BlurVertical(float2 uv, float blurScale)
            {
                float2 texelSize = 1.0 / _ScreenParams.xy;
                float3 color = float3(0, 0, 0);

                float weights[5] = {0.204164, 0.304005, 0.093913, 0.010381, 0.000336};
                color += SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, uv).rgb * weights[0];

                for (int i = 1; i < 5; i++)
                {
                    float2 offset = float2(0, i) * texelSize * blurScale;
                    color += SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, uv + offset).rgb * weights[
                        i];
                    color += SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, uv - offset).rgb * weights[
                        i];
                }

                return color;
            }


            half4 frag(Varyings i) : SV_Target
            {
                half3 baseTex = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, i.uv).rgb;

                half3 bulrValue = BlurVertical(i.uv, _BlurStrength);

                half4 finalColor = half4(baseTex + bulrValue*_LightColor, 1);

                return finalColor;
                return half4(bulrValue, 1);
                return half4(baseTex, 1);
            }
            ENDHLSL
        }
    }
}