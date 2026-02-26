Shader "Custom/SDFTree"
{
    Properties
    {
        // _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        // // _BaseMap("Base Map", 2D) = "white" {}
        // _ShadowColor("Shadow Color", Color) = (0.05, 0.05, 0.05, 1)
        // _Threshold("Threshold", Range(0, 1)) = 0.5
        // _Smoothness("Band Smoothness", Range(0.001, 0.2)) = 0.02
        // _BranchCount("Branch Count", Range(1, 256)) = 256

        // CIRCLE SHAPE TESTING
        _Color("Color", Color) = (0, 1, 0, 1)
        _Center("Center (XY)", Vector) = (0, 0, 0, 0)
        _Radius("Radius", Float) = 1.0
        _Edge("Edge", Float) = 0.01
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            // Blend One Zero
            // ZWrite On
            // ZTest LEqual

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                // float3 normalOS : NORMAL;
                // float4 color : COLOR;
                // float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                // float3 positionOS : TEXCOORD0;
                float3 positionWS : TEXCOORD0;
                // float3 normalWS : TEXCOORD1;
                // float2 uv : TEXCOORD2;
                // float4 color : COLOR;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float4 _Center;
                float _Radius;
                float _Edge;
                float _BranchCount;
            
                // half4 _BaseColor;
                // float4 _ShadowColor;
                // float _Threshold;
                // float _Smoothness;
            CBUFFER_END
            
            float4 _BranchDataA[512]; // xy = start, zw = end
            float4 _BranchDataB[512]; // x = radius

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                // OUT.positionOS = IN.positionOS.xyz;
                OUT.positionHCS = TransformWorldToHClip(IN.positionOS.xyz);
                // OUT.positionHCS = TransformObjectToHClip(OUT.positionWS);
                // OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                // OUT.uv = IN.uv;
                // OUT.color = IN.color;

                return OUT;
            }

            float sdCircle(float2 pos, float2 center, float radius)
            {
                return length(pos - center) - radius;
            }

            float sdCapsule(float2 pos, float2 a, float2 b, float radius)
            {
                float2 pa = pos - a; // Vector from point to a
                float2 ba = b - a; // Vector along capsule
                float height = saturate(dot(pa, ba) / dot(ba, ba)); // Project point onto capsule line and clamp to [0, 1]
                return length(pa - ba * height) - radius; // Distance from point to capsule surface
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float2 p = IN.positionWS.xy;
                // p *= 4.0;
                // p.y += 0.5;

                float minDist = 1e5;

                float2 start;
                float2 end;
                float radius;

                for(int i = 0; i < (int)_BranchCount; i++)
                {
                    start = _BranchDataA[i].xy;
                    end = _BranchDataA[i].zw;
                    radius = _BranchDataB[i].x;

                    float d = sdCapsule(p, start, end, radius);
                    minDist = min(minDist, d);
                }

                // float d = sdCircle(p, _Center.xy, _Radius);

                float mask = 1.0 - smoothstep(0.0, _Edge, minDist);

                // if(mask <= 0.001)
                // {
                //     discard;
                // }

                return float4(_Color.rgb * mask, 1);

                // Debug draw
                // return float4(_BranchCount / 256.0, 0, 0, 1);

                // // CEL SHADING
                // float3 normal = normalize(IN.normalWS);
                // float3 lightDirection = normalize(float3(0, 1, 0));

                // float NdotL = saturate(dot(normal, lightDirection));
                // float band = smoothstep(_Threshold - _Smoothness, _Threshold + _Smoothness, NdotL);

                // float3 color = lerp(_ShadowColor.rgb, _BaseColor.rgb, band);

                // // Optional height gradient
                // float heightFactor = saturate(IN.positionWS.y * 0.1);
                // color *= lerp(0.8, 1.2, heightFactor);

                // return float4(color, 1);

            }
            ENDHLSL
        }
    }
}
