Shader "Toon/Face"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (1,1,1,1)

        [Header(Texture)]
        [Toggle(_IS_EYESBROW)] _IS_EYESBROW("_IS_EYESBROW", Range(0,1)) = 1
        _MainTex("Main Texture", 2D) = "white" {}
        
        [Toggle(_USE_Ramp)] _USE_Ramp("USE_Ramp", Range(0,1)) = 1
        [NoScaleOffset] _RampMap("Skin Ramp (Grademap)", 2D) = "white" {}
        
        [Toggle(_USE_AO)] _USE_AO("USE_AO", Range(0,1)) = 1
        _AOMap("AO Map", 2D) = "white" {}

        [Header(Face Blush)]
        [Toggle(_USE_Blush)] _USE_Blush("USE_Blush", Range(0,1)) = 1
        _FaceBlushMap("Face Blush Map",2D) = "white"{}
        _FaceBlushColor("Face Blush Color", color) = (1, 1, 1)
        _FaceBlushIntensity("Face Blush Intensity", Range(0, 1)) = 0


        [HideInInspector] _HeadForward("Head Forward", Vector) = (0,0,1,0)
        [HideInInspector] _HeadRight("Head Right", Vector) = (1,0,0,0)
        [HideInInspector] _HeadUp("Head Up", Vector) = (0,1,0,0)

        [Header(Shadow)]
        _ShadowColor("Shadow Color", Color) = (0.6, 0.6, 0.6, 1) 
        _ShadowSmooth("Shadow Smoothness", Range(0,1)) = 0.01

        [Header(Specular)]
        _SpecularColor("Specular Color", Color) = (1,1,1,1)
        _SpecularSmoothness("Smoothness", Float) = 32
        _SpecularIntensity("Specular Intensity", Float) = 0.4

        [Header(Outline)]
        _OutlineColor("Outline Color", color) = (0, 0, 0, 1)
        _OutlineWidth("Outline Width", float) = 1

        [Header(Hair Shadow)]
        [Toggle(_IS_FACE)] _IS_FACE("IS_FACE", Range(0,1)) = 1
        _HairShadowDistance("Hair Shadow Distance", float) = 0.1

        [Header(Rim)]
        [Toggle(_USE_RIM)] _USE_RIM("USE_Rim", Range(0,1)) = 1
        _RimColor("Rim Color", color) = (0.8, 0.8, 0.8)
        _RimOffset("Rim Offset", float) = 1
        _RimThreshold("Rim Threshold", Range(0.5, 1)) = 0.8
        _RimIntensity("Rim Intensity", float) = 1
    }

    SubShader
    {
        Tags
        {
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
            #pragma multi_compile_fragment _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _REFLECTION_PROBE_BOX_PROJECTION

            #pragma shader_feature_local _IS_EYESBROW
            #pragma shader_feature_local _USE_AO
            #pragma shader_feature_local _USE_Ramp
            #pragma shader_feature_local _USE_Blush
            #pragma shader_feature_local _IS_FACE
            #pragma shader_feature_local _USE_RIM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half3 _ShadowColor;
                float _ShadowSmooth;

                float3 _HeadForward;
                float3 _HeadRight;
                float3 _HeadUp;

                half4 _SpecularColor;
                float _SpecularSmoothness;
                float _SpecularIntensity;

                half3 _FaceBlushColor;
                float _FaceBlushIntensity;

                half4 _OutlineColor;
                float _OutlineWidth;
                float _HairShadowDistance;

                half3 _RimColor ;
                float _RimOffset;
                float _RimThreshold;
                float _RimIntensity;
            CBUFFER_END

        ENDHLSL

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" "Queue" = "Transparent + 20"}
            Cull Off

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma target 4.5

            TEXTURE2D(_MainTex);            SAMPLER(sampler_MainTex);
            TEXTURE2D(_AOMap);              SAMPLER(sampler_AOMap);
            TEXTURE2D(_FaceBlushMap);       SAMPLER(sampler_FaceBlushMap);
            TEXTURE2D(_RampMap);            SAMPLER(sampler_RampMap);
            TEXTURE2D(_HairSolidColor);     SAMPLER(sampler_HairSolidColor);
            TEXTURE2D(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 viewDirWS : TEXCOORD2;
                float4 positionNDC : TEXCOORD3;
                float3 positionVS : TEXCOORD4;
                float3 normalVS : TEXCOORD5;
                #if _IS_FACE
                    float4 positionSS : TEXCOORD6;
                #endif
            };

            float4 TransformHClipToViewPortPos(float4 positionCS)
            {
                float4 o = positionCS * 0.5f;

                o.xy = float2(o.x, o.y * _ProjectionParams.x) + o.w;
                o.zw = positionCS.zw;
                return o / positionCS.w; 
            }


            half ComputeRim(float4 positionNDC, float3 positionVS, float3 normalVS)
            {

                half2 screenUV = positionNDC.xy / positionNDC.w;
                half depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV).r;
                half linearEyeDepth = LinearEyeDepth(depth, _ZBufferParams);


                normalVS = normalize(normalVS);

                half3 offsetVS = float3(positionVS.xy + normalVS.xy * _RimOffset * 0.01, positionVS.z);
                half4 offsetCS = TransformWViewToHClip(offsetVS);
                half4 offsetVP = TransformHClipToViewPortPos(offsetCS);
    

                half offsetDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, offsetVP.xy).r;

                half offsetLinearEyeDepth;

                if (offsetDepth <= 0.0001) 
                {
                    offsetLinearEyeDepth = 100000.0;
                }
                else 
                {
                    offsetLinearEyeDepth = LinearEyeDepth(offsetDepth, _ZBufferParams);
                }



                half rim = smoothstep(0, _RimThreshold, offsetLinearEyeDepth - linearEyeDepth) * _RimIntensity;

                return rim;
            }


            Varyings vert (Attributes v)
            {
                Varyings o;
                VertexPositionInputs pos = GetVertexPositionInputs(v.positionOS);
                VertexNormalInputs nor = GetVertexNormalInputs(v.normalOS);

                o.positionCS = pos.positionCS;
                o.viewDirWS = GetCameraPositionWS() - pos.positionWS;
                o.uv = v.uv;
                o.positionNDC = pos.positionNDC;
                o.positionVS = pos.positionVS;

                o.normalWS = nor.normalWS;
                o.normalVS = TransformWorldToViewDir(nor.normalWS);

                #if _IS_FACE
                    o.positionSS = ComputeScreenPos(o.positionCS);
                #endif
                return o;
            }

            half4 frag (Varyings i) : SV_Target
            {
                half4 baseMap = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                

                #if _USE_AO
                    half shadowMask = SAMPLE_TEXTURE2D(_AOMap, sampler_AOMap, i.uv).g;
                #else
                    half shadowMask = 1.0;
                #endif

                half4 faceBlushMap = SAMPLE_TEXTURE2D(_FaceBlushMap, sampler_FaceBlushMap, i.uv);
                
                float3 forwardDir = normalize(_HeadForward);
                float3 rightDir   = normalize(_HeadRight);
                float3 upDir      = normalize(_HeadUp);

                Light light = GetMainLight();
                float3 L = normalize(light.direction); 
                float3 N = normalize(i.normalWS);
                float3 V = normalize(i.viewDirWS);
                float3 H = normalize(L + V);
                
                half shadowAtten = light.shadowAttenuation * light.distanceAttenuation;


                float3 LpU = dot(L, upDir) * upDir;
                float3 LvFace = normalize(L - LpU);

                half faceLightDot = dot(LvFace, forwardDir);
                half faceLightMap = faceLightDot * 0.5 + 0.5;

                half RightorLeft = step(0.0, dot(LvFace, rightDir));
                half    sdfRight = SAMPLE_TEXTURE2D(_AOMap, sampler_AOMap, i.uv).b;
                half     sdfLeft = SAMPLE_TEXTURE2D(_AOMap, sampler_AOMap, float2(i.uv.x - 1.0, i.uv.y)).b;
                half      mixSdf = lerp(sdfRight, sdfLeft, RightorLeft);


                half sdf = smoothstep(mixSdf + _ShadowSmooth, mixSdf - _ShadowSmooth, faceLightMap);

                sdf *= shadowMask;

                half combinedShadow = min(sdf, shadowAtten); 


                float hairShadowFactor = 1.0;

                #if _IS_FACE
                    float2 scrPos = i.positionSS.xy / i.positionSS.w;

                    float3 viewLightDir = normalize(TransformWorldToViewDir(L));
                    float2 sampledPoint = scrPos + viewLightDir.xy * _HairShadowDistance;

                    hairShadowFactor = 1.0 - SAMPLE_TEXTURE2D(_HairSolidColor, sampler_HairSolidColor, sampledPoint).r;

                #endif


                combinedShadow = min(combinedShadow, hairShadowFactor);


                #if _USE_RIM
                    half rim = ComputeRim(i.positionNDC, i.positionVS, i.normalVS);
                    half fresnel = 1.0 - saturate(dot(N, V));

                    half rimAngleMask = smoothstep(_RimThreshold, 1.0, fresnel);
                    rim *= shadowMask;
                    half3 rimColor = rim * rimAngleMask * _RimColor * _RimIntensity;
                #else
                    half3 rimColor = half3(0, 0, 0);
                #endif


                


                half3 rampColor = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(combinedShadow, 0.5)).rgb;
                


                half3 shadowTint = lerp(_ShadowColor, half3(1,1,1), combinedShadow);
                

                half3 diffuse = baseMap.rgb * _BaseColor.rgb * rampColor * shadowTint * light.color;


                half spec = pow(saturate(dot(N, H)), _SpecularSmoothness);

                half3 specular = spec * _SpecularColor.rgb * _SpecularIntensity * SAMPLE_TEXTURE2D(_AOMap, sampler_AOMap, float2(1 - i.uv.x, i.uv.y)).r * combinedShadow;



                half3 finalCol = diffuse + specular + rimColor;


                half3 blushTint = _FaceBlushColor.rgb * _FaceBlushIntensity;
                finalCol = lerp(finalCol, finalCol + blushTint * faceBlushMap.rgb, faceBlushMap.a * _FaceBlushIntensity);

                return half4(finalCol, 1.0);
            }
            ENDHLSL
        }
          Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Off

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5



            #pragma multi_compile_instancing
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex ShadowVert
            #pragma fragment ShadowFrag


            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            float4 GetShadowPositionHClip(Attributes input)
            {
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

                #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
                #else
                    float3 lightDirectionWS = GetMainLight().direction;
                #endif


                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

                #if UNITY_REVERSED_Z
                    positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #else
                    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #endif

                return positionCS;
            }

            Varyings ShadowVert(Attributes v)
            {
                Varyings o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);

                o.positionCS = GetShadowPositionHClip(v);
                return o;
            }

            half4 ShadowFrag(Varyings i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                return 0;
            }
            ENDHLSL
        }




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

            Varyings OutlineVert(Attributes v)
            {
                Varyings o;


                float3 smoothNormalOS = v.normalOS;
                

                float colorLen = length(v.color.rgb);
                if (colorLen > 0.1 && colorLen < 1.7) 
                {

                    smoothNormalOS = v.color.xyz * 2.0 - 1.0;
                }
                

                smoothNormalOS = normalize(smoothNormalOS);



                float width = _OutlineWidth;


                float3 positionOS = v.positionOS.xyz + smoothNormalOS * width * 0.01;


                o.positionCS = TransformObjectToHClip(positionOS);



                float depthOffset = 0.00005 * o.positionCS.w; 
                
                #if defined(UNITY_REVERSED_Z)
                    o.positionCS.z -= depthOffset;
                #else
                    o.positionCS.z += depthOffset;
                #endif

                return o;
            }

            half4 OutlineFrag(Varyings i) : SV_Target
            {
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
