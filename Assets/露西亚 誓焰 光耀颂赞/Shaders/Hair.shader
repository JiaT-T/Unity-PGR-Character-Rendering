Shader "Toon/Hair"
{
    Properties
    {
        [Header(Base)]
        _BaseColor("Base Color", Color) = (1,1,1,1)
        _MainTex("Main Texture", 2D) = "white"{}
        
        [Header(Ramp)]
        [NoScaleOffset] _RampMap("Ramp Map (Lighting)", 2D) = "white"{}

        [Header(Shadow)]
        _ShadowColor("Shadow Color", Color) = (0.6, 0.6, 0.6, 1)
        _ShadowSmooth("Shadow Smoothness", Range(0, 10)) = 1
        _ShadowThreshold("Shadow Threshold", Range(0, 1)) = 0.5

        [Header(Specular)]
        _SpecularMap("Specular Map (Mask)", 2D) = "white"{}
        _SpecularColor("Specular Color", Color) = (1, 1, 1, 1)
        _SpecularThreshold("Specular Threshold", Range(0, 1)) = 0.5
        _SpecularIntensity("Specular Intensity", Range(0, 2)) = 1

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
            #pragma multi_compile _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _MAIN_LIGHT_SHADOWS_SCREEN

            #pragma multi_compile_fragment _LIGHT_LAYERS
            #pragma multi_compile_fragment _LIGHT_COOKIES
            #pragma multi_compile_fragment _SCREEN_SPACE_DCCLUSION
            #pragma multi_compile_fragment _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _SHADOWS_SOFT
            #pragma multi_compile_fragment _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _REFLECTION_PROBE_BOX_PROJECTION

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
             
                half3 _ShadowColor;
                float _ShadowSmooth;
                float _ShadowThreshold;

                half4 _SpecularColor;
                float _SpecularThreshold;
                float _SpecularIntensity;

                half4 _OutlineColor;
                float _OutlineWidth;
            CBUFFER_END
        ENDHLSL

        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}
            Cull Off 

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
                float3 viewDirWS : TEXCOORD3;
                float4 shadowCoord : TEXCOORD4;
            };

            TEXTURE2D(_MainTex);            SAMPLER(sampler_MainTex);
            TEXTURE2D(_SpecularMap);        SAMPLER(sampler_SpecularMap);
            TEXTURE2D(_RampMap);            SAMPLER(sampler_RampMap);
        
            Varyings vert(Attributes v)
            {
                Varyings o;
                VertexPositionInputs vertexInputs = GetVertexPositionInputs(v.positionOS);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normalOS.xyz);

                o.positionCS = vertexInputs.positionCS;
                o.positionWS = vertexInputs.positionWS;
                o.normalWS = normalInputs.normalWS;
                o.uv = v.uv;
                o.viewDirWS = GetCameraPositionWS() - vertexInputs.positionWS;
                o.shadowCoord = TransformWorldToShadowCoord(o.positionWS);

                return o;
            }

            half4 frag(Varyings i) : SV_Target
            { 

                half4 baseMap = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv) * _BaseColor;


                Light light = GetMainLight(i.shadowCoord);
                float3 L = normalize(light.direction);
                float3 N = normalize(i.normalWS);
                float3 V = normalize(i.viewDirWS);
                float3 H = normalize(L + V);


                float halfLambert = dot(N, L) * 0.5 + 0.5;
                

                half shadowAtten = light.shadowAttenuation * light.distanceAttenuation;
                

                float rampParam = smoothstep(_ShadowThreshold - _ShadowSmooth, _ShadowThreshold + _ShadowSmooth, halfLambert);
                

                float combinedShadow = saturate(rampParam * shadowAtten);


                half3 rampColor = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(combinedShadow, 0.5)).rgb;
                half3 shadowTint = lerp(_ShadowColor, half3(1,1,1), combinedShadow);
                half3 diffuse = baseMap.rgb * rampColor * shadowTint * light.color;


                half4 specMapValue = SAMPLE_TEXTURE2D(_SpecularMap, sampler_SpecularMap, i.uv);
                float NdotLV = dot(N, normalize(L + V));
                float spec1 = saturate(NdotLV * saturate(specMapValue.r)) * halfLambert;
                float spec2 = step(spec1, _SpecularThreshold) * specMapValue.r * specMapValue.b; 


                half3 specular = spec2 * _SpecularColor.rgb * _SpecularIntensity * baseMap.rgb;


                half3 finalCol = diffuse + specular;
                return half4(finalCol, 1);
            }
            ENDHLSL
        }

        UsePass "Toon/Face/SHADOWCASTER"

        Pass
        {
            Name "Outline"
            Tags { "LightMode" = "SRPDefaultUnlit" }

            Cull Front
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM
            #pragma vertex OutlineVert
            #pragma fragment OutlineFrag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 color : COLOR; 
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

            CBUFFER_START(UnityPerMaterial)


            CBUFFER_END

            Varyings OutlineVert(Attributes v)
            {
                Varyings o;


                float3 normalOS = v.normalOS;
                

                float widthControl = v.color.a; 



                float3 offsetDir = normalize(normalOS);
                float3 positionOS = v.positionOS.xyz + offsetDir * (_OutlineWidth * 0.001 * widthControl);


                o.positionCS = TransformObjectToHClip(positionOS);




                #if defined(UNITY_REVERSED_Z)
                o.positionCS.z -= 0.0005;
                #else
                o.positionCS.z += 0.0005;
                #endif

                return o;
            }

            half4 OutlineFrag(Varyings i) : SV_Target {
                return _OutlineColor;
            }
            ENDHLSL
        }

        Pass
        {
            Name "BangsIdentifier"
    
            Tags { "LightMode" = "BangsShadow" }
    

            ColorMask 0
            ZWrite Off
    
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    
            struct Attributes { float4 positionOS : POSITION; };
            struct Varyings { float4 positionCS : SV_POSITION; };
    
            Varyings vert(Attributes v) {
                Varyings o;
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                return o;
            }
    
            half4 frag(Varyings i) : SV_Target {
                return 0;
            }
            ENDHLSL
        }
    }
}
