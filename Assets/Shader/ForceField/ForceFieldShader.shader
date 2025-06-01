Shader "Roxy/ForceFieldShader"
{
    Properties
    {
        [Header(Base)]
        [HDR]_BaseColor ("Base Color", Color) = (1,1,1,1)
        [HDR]_EdgeColor("Edge Color",Color)=(1,1,1,1)
        _EdgeWidth("edge Width",Float)=0.5

        [Space(20)]
        [Header(Noise)]
        _NoiseParameter("Noise Parameter",Float)=1
        _NoisePow("Noise Pow",Range(0,10))=1
        _NoiseThreshold("Noise Threshold",Range(0,1))=.7

        [HDR]_NoiseColor("Noise Color",Color)=(1,1,1,1)


        [Space(20)]
        _Temp("temp",Float)=0

    }
    SubShader
    {
        Tags
        {
            "RenderType"="Transparent"
            "RenderPipeline" = "UniversalRenderPipeline"
            "Queue" = "Transparent"
        }
        LOD 100
        ZWrite Off
        ZTest LEqual
        // 设置混合模式，实现透明效果
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "ForceFieldMain.hlsl"
            ENDHLSL
        }
        Pass
        {
            Name "DepthOnly"
            Tags
            {
                "LightMode" = "DepthOnly"
            }

            // -------------------------------------
            // Render State Commands
            ZWrite On
            ColorMask R
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }
    }
}