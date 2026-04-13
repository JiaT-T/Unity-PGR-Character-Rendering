Shader"Clothes"
{
	Properties{
		_MainTex("Main Texture", 2D) =  "whitte"{}
		_Normal("Normal Map", 2D) = "bump"{}
		_AO("Ao Map", 2D) = "white"{}
		_PBR("PBR Map", 2D) = "white"{}
		_Toon("Toon MAp", 2D) = "white"{}
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
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			CBUFFER_START(UnityPerMaterial)
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

			Varyings vert(Attributes v) 
			{
				Varyings o;
				VertexPositionInputs positionInputs = GetVertexPositionInputs(v.positionOS.xyz);
				o.positionCS = positionInputs.positionCS;
				o.positionWS = positionInputs.positionWS;

				VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normalOS.xyz);
				o.normalWS = normalInputs.normalWS;
				o.tangentWS = normalInputs.tangentWS;
				o.biTangentWS = cross(o.normalWS, o.tangentWS) * v.tangentOS.w;

				o.viewDirWS = GetWorldSpaceViewDir(o.positionWS);	

				return o;
			}

			half4 frag(Varyings i) : SV_TARGET
			{
				half4 baseMap = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv0);
				half3 normalMap = SAMPLE_TEXTURE2D(_Normal, sampler_Normal, i.uv0).xyz * 2 - 1;
				half aoMap = SAMPLE_TEXTURE2D(_AO, sampler_AO, i.uv0).r;
				half3 pbrMap = SAMPLE_TEXTURE2D(_PBR, sampler_PBR, i.uv0).rgb;


				float3 T = normalize(i.tangentWS.xyz);
				float3 B = normalize(i.biTangentWS.xyz);
				float3 N = normalize(i.normalWS);
				float3x3 TBN = float3x3(T, B, N);
				float3 normal = normalize(mul(normalMap, TBN));

				float metallic = pbrMap.g;
				float smoothness = 1 - pbrMap.r;
				float occlusion = pbrMap.b;

				Light light = GetMainLight();
				float3 lightDirWS = light.direction;
				half3 lightColor = light.color;
				float3 viewDirWS = normalize(i.viewDirWS);
				float3 L = normalize(lightDirWS);
				float3 V = normalize(viewDirWS);
				float3 halfDir = normalize(L + V);

				float halfLambert = dot(normal, L) * 0.5 + 0.5;
				halfLambert = smoothstep(0.0, 1.0, halfLambert);
				half3 diffuse = baseMap.rgb * lightColor * halfLambert;	

				return half4(diffuse, baseMap.a);
			}
			ENDHLSL
		}
	}
}