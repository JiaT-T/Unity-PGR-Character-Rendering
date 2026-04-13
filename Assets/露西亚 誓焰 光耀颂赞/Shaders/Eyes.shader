Shader "Custom/Eyes_Enhanced"{
    Properties{
        _BaseColor("Base Color", color) = (1, 1, 1, 1)
        [Header(Texture)]
        _MainTex("Main Texture", 2D) = "white" {}
        
        [Header(Parallax Refraction)]
        _ParallaxStrength("Refraction Strength", Range(0, 0.5)) = 0.1 
        _IrisDepth("Iris Cone Depth", Range(0, 1)) = 0.5

        [Header(Iris Details)]
        _LimbusWidth("Limbus Width", Range(0, 1)) = 0.2
        _LimbusDarkness("Limbus Darkness", Range(0, 1)) = 0.5

        [Header(Specular)]
        _SpecularColor("Specular Color", color) = (1, 1, 1)
        _SpecularPower("Specular Power", float) = 20
     
        _SpecularIntensity("Specular Intensity", float) = 1.0
    }
    SubShader{
        Tags{
            "RenderPipeline"="UniversalRenderPipeline"
            "RenderType"="Opaque"
        }

        HLSLINCLUDE

            #pragma multi_compile _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _MAIN_LIGHT_SHADOWS_CASCADE
     
       #pragma multi_compile _MAIN_LIGHT_SHADOWS_SCREEN

            #pragma multi_compile_fragment _LIGHT_LAYERS
            #pragma multi_compile_fragment _LIGHT_COOKIES
            #pragma multi_compile_fragment _SCREEN_SPACE_DCCLUSION
            #pragma multi_compile_fragment _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _SHADOWS_SOFT

         
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)

            half4 _BaseColor;
            float _ParallaxStrength;

            float _IrisDepth;
            float _LimbusWidth;
            float _LimbusDarkness;

            half3 _SpecularColor;
            float _SpecularPower;
            float _SpecularIntensity;

            CBUFFER_END

        ENDHLSL

        Pass{
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            struct Attributes{
                float4 positionOS : POSITION;
                float2 uv: TEXCOORD0;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };
            struct Varyings{
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 tangentWS : TEXCOORD2;
                float3 viewDirWS : TEXCOORD3;
                float3 biTangentWS : TEXCOORD4;
};

            Varyings vert(Attributes v){
                Varyings o;
                VertexPositionInputs pos = GetVertexPositionInputs(v.positionOS);
                VertexNormalInputs nor = GetVertexNormalInputs(v.normalOS, v.tangentOS);
                
                o.positionCS = pos.positionCS;
                o.uv = v.uv;
                o.normalWS = nor.normalWS;
                o.viewDirWS = GetCameraPositionWS() - pos.positionWS;

                o.tangentWS = float4(nor.tangentWS, v.tangentOS.w);
                o.biTangentWS = nor.bitangentWS;

                return o;
}

            half4 frag(Varyings i) : SV_Target{
                Light light = GetMainLight();
                
                float3 T = normalize(i.tangentWS);
                float3 B = normalize(i.biTangentWS) * i.tangentWS.w;
                float3 N = normalize(i.normalWS);
                float3 V = normalize(i.viewDirWS);
                float3 L = normalize(light.direction);
                float3 H = normalize(L + V);


                float3x3 worldToTangent = float3x3(T, B, N); 
                float3 viewDirTS = mul(worldToTangent, V);





                float2 centeredUV = i.uv - 0.5;
                float distFromCenter = length(centeredUV);



                float fakeHeight = clamp(distFromCenter * _IrisDepth, 0, 1);
                


                float2 parallaxOffset = viewDirTS.xy * fakeHeight * _ParallaxStrength;
                float2 finalUV = i.uv + parallaxOffset;




                half4 baseMap = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, finalUV);
                




                float newDist = length(finalUV - 0.5);
                


                float limbusThreshold = 0.5 - _LimbusWidth * 0.5; 
                float limbusMask = smoothstep(0.5, limbusThreshold, newDist);

                limbusMask = lerp(1.0 - _LimbusDarkness, 1.0, limbusMask);


                half3 albedo = baseMap.rgb * _BaseColor.rgb * limbusMask;




                float NdotH = saturate(dot(N, H));
                float spec = pow(NdotH, _SpecularPower);
                half3 specularColor = spec * _SpecularColor * _SpecularIntensity;


                half3 finalCol = albedo + specularColor;
                return half4(finalCol, 1);
            }
            ENDHLSL
        }
    }
}
