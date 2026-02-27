Shader "Custom/SDFTree"
{
    Properties
    {
        _TreeScale("Tree Scale", Float) = 1.0
        _LeafScale("Leaf Scale", Float) = 1.0
        _MainTexture("Tree Texture", 2D) = "white" {}
        _LeafTexture("Leaf Texture", 2D) = "white" {}
        _Color("Tree Color", Color) = (0, 0.5, 0, 1)
        _LeafColor("Leaf Color", Color) = (0.8, 0.6, 0.6, 1)
        _ShadowColor("Shadow Color", Color) = (0.05, 0.05, 0.05, 1)
        _LightDirection("Light Direction", Vector) = (0.3, 0.8, 0.0, 0)
        _Bands("Cel Shading Bands", Float) = 3.0
        _Edge("Edge", Float) = 0.01

        // CIRCLE SHAPE TESTING
        // _Center("Center (XY)", Vector) = (0, 0, 0, 0)
        // _Radius("Radius", Float) = 1.0
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Blend One Zero
            ZWrite On
            ZTest LEqual

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
                float3 positionWS : TEXCOORD0;
                float3 positionOS : TEXCOORD1;
                // float2 uv : TEXCOORD2;
                // float4 color : COLOR;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTexture_ST;
                float4 _LeafTexture_ST;
                float4 _Color;
                float4 _ShadowColor;
                float4 _LeafColor;
                float _Bands;
                float _Edge;
                int _BranchCount;
                int _LeafCount;
                float _TreeScale;
                float _LeafScale;
                float3 _LightDirection;

            CBUFFER_END
            
            float4 _LeafPositions[512]; // xy = pos, z = radius, w unused
            float4 _BranchDataA[512]; // xy = start, zw = end
            float4 _BranchDataB[512]; // x = radius

            TEXTURE2D(_MainTexture);
            SAMPLER(sampler_MainTexture);
            TEXTURE2D(_LeafTexture);
            SAMPLER(sampler_LeafTexture);

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz); 
                OUT.positionWS = positionWS;
                OUT.positionOS = IN.positionOS.xyz;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);

                return OUT;
            }

            float sdCapsule(float2 pos, float2 a, float2 b, float radius)
            {
                float2 pa = pos - a; // Vector from point to a
                float2 ba = b - a; // Vector along capsule
                float height = saturate(dot(pa, ba) / dot(ba, ba)); // Project point onto capsule line and clamp to [0, 1]
                return length(pa - ba * height) - radius; // Distance from point to capsule surface
            }

            float sdTree(float2 pos)
            {
                float minDist = 1e5;

                float2 start;
                float2 end;
                float radius;

                for(int i = 0; i < _BranchCount; i++)
                {
                    start = _BranchDataA[i].xy;
                    end = _BranchDataA[i].zw;
                    radius = _BranchDataB[i].x;

                    float d = sdCapsule(pos, start, end, radius);
                    minDist = min(minDist, d);
                }

                return minDist;
            }

            float sdLeaf(float2 pos)
            {
                float leafDist = 1e5;
                for (int i = 0; i < _LeafCount; i++)
                {
                    float2 leafPos = _LeafPositions[i].xy;
                    float leafRadius = _LeafPositions[i].z * _LeafScale;
                    leafDist = min(leafDist, length(pos - leafPos) - leafRadius);
                }

                return leafDist;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float2 p = IN.positionOS.xy * _TreeScale; // Scale the tree in 2D object space

                float2 uv = IN.positionOS.xy * 0.5 + 0.5;

                float branchDist = sdTree(p);
                float leafDist = sdLeaf(p); // Scale leaf distance separately

                // Combine branch and leaf SDFs
                float combinedDist = min(branchDist, leafDist);

                // Branch edge mask
                float edgeWidth = fwidth(combinedDist) * _Edge;
                float mask = 1.0 - smoothstep(-edgeWidth, edgeWidth, combinedDist);

                if(mask <= 0.001)
                {
                    discard;
                }

                float eps = fwidth(combinedDist); // Epsilon - Small offset for gradient estimation

                // Sample SDFs around current point
                float dx = min(sdTree(p + float2(eps, 0)), sdLeaf(p + float2(eps, 0))) - combinedDist;
                float dy = min(sdTree(p + float2(0, eps)), sdLeaf(p + float2(0, eps))) - combinedDist;

                // Surface normal is the gradient of the SDF
                float2 normal2D = normalize(float2(dx, dy));

                // Convert normal to 3D
                float3 normalWS = normalize(float3(normal2D, 0));

                // CEL SHADING
                float ndotl = saturate(dot(normalWS, _LightDirection));
                float cel = floor(ndotl * _Bands) / _Bands;

                float3 shadowColor = _ShadowColor.rgb;
                float3 litColor = _Color.rgb;

                float3 celColor = lerp(shadowColor, litColor, cel);

                // Leaves
                float leafRegion = step(leafDist, branchDist); // 1 in leaf region, 0 in branch region
                // float leafPulse = 1.0 + 0.5 * sin(_Time.y * 0.5); // Pulsating effect based on time and position

                // Sample texture(s)
                float4 texColor = SAMPLE_TEXTURE2D(_MainTexture, sampler_MainTexture, uv); // Adjust UV scale as needed
                float3 branchColor = texColor.rgb * _Color.rgb * celColor;

                float3 finalColor = lerp(branchColor, _LeafColor /** leafPulse */, leafRegion);

                return float4(finalColor, 1);

                // Debug draw
                // return float4(_LeafPositions[0].xy * 0.5 + 0.5, 0, 1);
            }
            ENDHLSL
        }
    }
}
