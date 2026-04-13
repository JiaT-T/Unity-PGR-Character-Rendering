Shader "Toon/Body_Fixed_AO"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (1,1,1)

        [Header(Texture)]
        _MainTex("Main Texture", 2D) = "white"{}
        
        [NoScaleOffset] _RampMap("Skin Ramp (Grademap)", 2D) = "white" {}
        
        [Toggle(_USE_AO)] _USE_AO("USE_AO", Range(0, 1)) = 1
        _AOMap("AO Map", 2D) = "white"{}

        [Header(Shadow)]
        // 这里的颜色决定了AO区域最深能有多黑
        _ShadowColor("Shadow Color", Color) = (0.6, 0.6, 0.6) 
        _ShadowSmooth("Shadow Smoothness", Range(0, 0.5)) = 0.05
        _ShadowThreshold("Shadow Threshold", Range(0, 1)) = 0.5

        [Header(Specular)]
        _SpecularColor("Specular Color", Color) = (1.0,1.0,1.0,1.0)
        _Smoothness("Smoothness", float) = 1

        [Header(Outline)]
        _OutlineColor("Outline Color", color) = (0, 0, 0, 1)
        _OutlineWidth("Outline Width", float) = 1
    }

    SubShader
    {
        Tags 
        { 
            "RenderPipeline" = "UniversalRenderPipeline"
            "RenderType"="Opaque" 
        }

        HLSLINCLUDE
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma shader_feature_local _USE_AO

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half3 _BaseColor;
                half3 _ShadowColor;
                float _ShadowSmooth;
                float _ShadowThreshold;
                half4 _SpecularColor;
                float _Smoothness;

                half4 _OutlineColor;
                float _OutlineWidth;
            CBUFFER_END
        ENDHLSL

        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            TEXTURE2D(_MainTex);    SAMPLER(sampler_MainTex);
            TEXTURE2D(_AOMap);      SAMPLER(sampler_AOMap);
            TEXTURE2D(_RampMap);    SAMPLER(sampler_RampMap);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv0 : TEXCOORD0;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv0 : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
                float4 shadowCoord : TEXCOORD3;
            };

            Varyings vert(Attributes v) 
            {
                Varyings o;
                VertexPositionInputs vertexInputs = GetVertexPositionInputs(v.positionOS);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normalOS.xyz);

                o.positionCS = vertexInputs.positionCS;
                o.positionWS = vertexInputs.positionWS;
                o.normalWS = normalInputs.normalWS;
                o.uv0 = v.uv0;
                o.shadowCoord = TransformWorldToShadowCoord(o.positionWS);

                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                half4 baseMap = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv0.xy);
                
                // 获取 AO
                #if _USE_AO
                    half ao = SAMPLE_TEXTURE2D(_AOMap, sampler_AOMap, i.uv0.xy).g;
                #else
                    half ao = 1.0;
                #endif

                Light light = GetMainLight(i.shadowCoord);
                float3 N = normalize(i.normalWS);
                float3 L = normalize(light.direction);
                float3 V = normalize(GetCameraPositionWS() - i.positionWS);
                float3 H = normalize(L + V);

                float NdotL = dot(N, L);
                float halfLambert = NdotL * 0.5 + 0.5;

                // 光照阈值计算
                float rampUV = smoothstep(_ShadowThreshold - _ShadowSmooth, _ShadowThreshold + _ShadowSmooth, halfLambert);

                // 将 AO 合并进光照强度，而不是直接乘颜色
                // combinedShadow 为 0 时：
                // 采样 Ramp 图的最左侧 (阴影色), 混合 _ShadowColor 
                // 即使 AO 是纯黑，最终显示的也是 _ShadowColor，而不是黑色
                float shadowAtten = light.shadowAttenuation * light.distanceAttenuation;
                float combinedShadow = saturate(rampUV * shadowAtten * ao);

                // 颜色合成
                // 采样 Ramp
                half3 rampColor = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(combinedShadow, 0.5)).rgb;

                // 计算 Tint
                half3 shadowTint = lerp(_ShadowColor, half3(1,1,1), combinedShadow);

                // 漫反射 (这里不再乘以 ao)
                half3 diffuse = baseMap.rgb * _BaseColor * rampColor * shadowTint * light.color;

                // 高光
                half specTerm = pow(saturate(dot(N, H)), _Smoothness);
                // 高光依然需要被 ao 遮挡
                half3 specular = specTerm * _SpecularColor.rgb * ao * combinedShadow;

                half3 finalCol = diffuse + specular;

                return half4(finalCol, 1.0);
            }
            ENDHLSL
        }
        UsePass "Toon/Face/SHADOWCASTER"
        UsePass "Toon/Hair/OUTLINE"
    }
}