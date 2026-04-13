Shader "Upper"
{
	Properties{
		_MainTex("Main Texture", 2D) =  "white"{}
		_BaseColor("Base Color", Color) = (1.0, 1.0, 1.0, 1)
		_Normal("Normal Map", 2D) = "bump"{}
		_AO("Ao Map", 2D) = "white"{}
		_PBR("PBR Map (R:Rough G:Metal B:AO)", 2D) = "white"{}
		_Toon("Toon Map (Ramp)", 2D) = "white"{} 

		_SpecularColor("Specular Color", Color) = (1,1,1,1)
		_SpecualrSmoothness("Specular Smoothness", float) = 32.0

		_ShadowColor("Shadow Color", Color) = (0.55, 0.55, 0.55, 1)
		_ShadowThreshold("Shadow Threshold", Range(0, 1)) = 0.25
		_ShadowSmooth("Shadow Smoothness", Range(0, 1)) = 0.065
		_ShadowContrast("Shadow Contrast", Range(0.5, 3)) = 1.35
		_IndirectIntensity("Indirect Intensity", Range(0, 1)) = 0.45

		_RimColor("Rim Color", Color) = (1, 1, 1, 1)
		_RimWidth("Rim Width", Range(0, 1)) = 0.4
		_RimIntensity("Rim Intensity", Range(0, 5)) = 0.7

		[Header(Outline)]
        _OutlineColor("Outline Color", color) = (0, 0, 0, 1)
        _OutlineWidth("Outline Width", float) = 0.05
	}
	SubShader
	{
        Tags
        {
            "RenderPipeline"="UniversalRenderPipeline"
            "RenderType"="Opaque"
        }

		HLSLINCLUDE
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
			#pragma multi_compile_fragment _ _SHADOWS_SOFT
			#pragma multi_compile_fragment _ _LIGHT_LAYERS
			#pragma shader_feature_local _IS_METAL
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			CBUFFER_START(UnityPerMaterial)
				half3 _BaseColor;
				half3 _SpecularColor;
				float _SpecualrSmoothness;
				half3 _ShadowColor;
				float _ShadowThreshold;
				float _ShadowSmooth;
				float _ShadowContrast;
				float _IndirectIntensity;
				half3 _RimColor;
				float _RimWidth;
				float _RimIntensity;
				float4 _MainTex_ST;
				float4 _OutlineColor;
				float _OutlineWidth;
			CBUFFER_END
		ENDHLSL
		
		Pass
		{
            Tags { "LightMode"="UniversalForward" }
            Cull Off

			HLSLPROGRAM

			#pragma vertex vert
			#pragma fragment frag
			#pragma target 4.5

			TEXTURE2D(_MainTex);	SAMPLER(sampler_MainTex);
			TEXTURE2D(_Normal);		SAMPLER(sampler_Normal);
			TEXTURE2D(_AO);			SAMPLER(sampler_AO);
			TEXTURE2D(_PBR);		SAMPLER(sampler_PBR);
			TEXTURE2D(_Toon);		SAMPLER(sampler_Toon);

			struct Attributes
			{
				float4 positionOS : POSITION;
				float3 normalOS : NORMAL;
				float4 tangentOS : TANGENT;
				float2 uv0 : TEXCOORD0;	
			};

			struct Varyings 
			{
				float4 positionCS : SV_POSITION;
				float3 normalWS : TEXCOORD0;
				float3 tangentWS : TEXCOORD1;
				float3 biTangentWS : TEXCOORD2;
				float3 positionWS : TEXCOORD3;
				float3 viewDirWS : TEXCOORD5;
				float2 uv0 : TEXCOORD6;
			};


			float DistributionGGX(float NdotH, float roughness)
			{
				float a2 = roughness * roughness;
				float NdotH2 = NdotH * NdotH;
				float nom = a2;
				float denom = (NdotH2 * (a2 - 1.0) + 1.0);
				denom = 3.1415926 * denom * denom;
				return nom / max(denom, 0.00001);
			}


			float GeometrySchlickGGX(float NdotV, float roughness)
			{
				float r = roughness + 1.0;
				float k = (r * r) / 8.0;
				float nom = NdotV;
				float denom = NdotV * (1 - k) + k;

				return nom / max(denom, 0.00001);
			}
			float GeometrySmith(float NdotV, float NdotL, float roughness)
			{
				float Gnv = GeometrySchlickGGX(NdotV, roughness);
				float Gnl = GeometrySchlickGGX(NdotL, roughness);

				return Gnv * Gnl;
			}




			float3 FresnelSchlick(float cosTheta, float3 F0)
			{
				float3 F = F0 + (1.0 - F0) * pow(max((1.0 - cosTheta), 0.0), 5.0);
				return F;
			}


			float3 IndirFresnel(float NdotV, float roughness, float3 F0)
			{
				float fre = 1.0 - roughness;
				return F0 + (max(float3(fre, fre, fre), F0) - F0) * pow(max(1.0 - NdotV, 0.0), 5.0);
			}


			float3 IndirectLight(float3 positionWS, float3 N, float3 V, half4 baseMap, float3 F0, float NdotV, float roughness, float metallic, float occlusion)
			{

				float3 SHColor = SampleSH(N);
				float3 indirKs = IndirFresnel(NdotV, roughness, F0);
				float3 indirKd = (1.0 - indirKs) * (1.0 - metallic);
				float3 indirDiffColor = indirKd * baseMap.rgb * occlusion * SHColor;


				float3 reflectDir = reflect(-V, N);
				float3 indirectSpecular = GlossyEnvironmentReflection(reflectDir, positionWS, roughness, occlusion);
				indirectSpecular *= indirKs;

				return indirDiffColor + indirectSpecular;
			}

			Varyings vert(Attributes v) 
			{
				Varyings o;
				VertexPositionInputs positionInputs = GetVertexPositionInputs(v.positionOS.xyz);
				o.positionCS = positionInputs.positionCS;
				o.positionWS = positionInputs.positionWS;

				VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normalOS.xyz);
				o.normalWS = normalInputs.normalWS;
				o.tangentWS = normalInputs.tangentWS;
				o.biTangentWS = cross(o.normalWS, o.tangentWS) * v.tangentOS.w * GetOddNegativeScale();

				o.viewDirWS = GetWorldSpaceViewDir(o.positionWS);	
				o.uv0 = v.uv0;

				return o;
			} 

			half4 frag(Varyings i) : SV_TARGET
			{
				half4      baseMap = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv0);

				half4 packedNormal = SAMPLE_TEXTURE2D(_Normal, sampler_Normal, i.uv0);
				float3   normalMap = UnpackNormal(packedNormal);

				half            ao = SAMPLE_TEXTURE2D(_AO, sampler_AO, i.uv0).r;

				half4       pbrMap = SAMPLE_TEXTURE2D(_PBR, sampler_PBR, i.uv0);
				 
				float3      T = normalize(i.tangentWS.xyz);
				float3      B = normalize(i.biTangentWS.xyz);
				float3  N_Geo = normalize(i.normalWS);
				float3x3 TBN  = float3x3(T, B, N_Geo);
				

				float3 N = normalize(mul(normalMap, TBN));
				float metallic  = pbrMap.g;

				float roughness = clamp(1.0 - pbrMap.r, 0.05, 1.0);

				float   occlusion = pbrMap.b; 
				float     pbrMask = pbrMap.a;
				Light       light = GetMainLight();
				float3 lightDirWS = light.direction;
				half3  lightColor = light.color;
				float3  viewDirWS = normalize(i.viewDirWS);
				float3 L = normalize(lightDirWS);
				float3 V = normalize(viewDirWS);
				

				float NdotV = max(saturate(dot(N,V)), 0.00001);
				float NdotL = max(saturate(dot(N,L)), 0.00001);



				float halfLambert = dot(N, L) * 0.5 + 0.5;
				

				float rampUV = smoothstep(_ShadowThreshold - _ShadowSmooth, _ShadowThreshold + _ShadowSmooth, halfLambert);
				float shadowAtten = light.shadowAttenuation * light.distanceAttenuation;
				float lightShadowMask = saturate(rampUV * shadowAtten); 


				float stylizedShadow = pow(max(combinedShadow, 0.0001), _ShadowContrast);


				half3 rampColor = SAMPLE_TEXTURE2D(_Toon, sampler_Toon, float2(stylizedShadow, 0.5)).rgb;
				

				half3 shadowTint = lerp(_ShadowColor, half3(1,1,1), stylizedShadow);




				half3 rimColor = step(1 - _RimWidth, (1 - NdotV) * _RimIntensity) * _RimColor;
				rimColor       = max(0.0, rimColor) * stylizedShadow; 



				float3 halfDir = normalize(L + V);
				float3 H       = halfDir;
				float  NdotH   = max(saturate(dot(N,H)), 0.000001);

				float3 F0 = lerp(float3(0.04, 0.04, 0.04), baseMap.rgb, metallic);

				float D = DistributionGGX(NdotH, roughness);
				float G = GeometrySmith(NdotV, NdotL, roughness);
				float3 F = FresnelSchlick(max(dot(halfDir, V), 0.0), F0);


				float3 numerator   = D * G * F;
				float  denominator = 4.0 * NdotV + 0.0001; 
				float3 BRDFSpec    = numerator / denominator;

				float3 kS = F;
				float3 kD = (1.0 - metallic) * (1.0 - kS);





				float3 finalSpecular = BRDFSpec * lightColor * _SpecularColor.rgb * shadowAtten * occlusion * specShadowMask;



				float3 indirColor = IndirectLight(i.positionWS, N, V, baseMap, F0, NdotV, roughness, metallic, occlusion);
				indirColor *= _IndirectIntensity;
				indirColor *= lerp(0.1, 1.0, stylizedShadow);


				half3 finCol = finalDiffuse + finalSpecular + indirColor + rimColor;

				return half4(finCol, 1);
			}
			ENDHLSL
		}
		UsePass"Toon/Face/SHADOWCASTER"
		UsePass"Toon/Face/Outline"
	}
}
