Shader "Custom/SDFTree"
{
    Properties
    {
        _TreeScale("Tree Scale", Float) = 1.0
        _LeafScale("Leaf Scale", Float) = 1.0
        _MainTexture("Tree Texture", 2D) = "white" {}
        _LeafTexture("Leaf Texture", 2D) = "white" {}
        _BranchColor("Tree Color", Color) = (0, 0.5, 0, 1)
        _LeafColor("Leaf Color", Color) = (0.8, 0.6, 0.6, 1)
        _ShadowColor("Shadow Color", Color) = (0.05, 0.05, 0.05, 1)
        _LightDirection("Light Direction", Vector) = (0.4, 0.8, 0.0, 0)
        _LightColor("Light Color", Color) = (1, 1, 1, 1)
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
                float4 _BranchColor;
                float4 _ShadowColor;
                float3 _LightColor;
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
                float minDist = 1e5; // Start with a large distance, will be reduced by checking each branch

                float2 start;
                float2 end;
                float radius;

                // Loop through all branches and find the minimum distance to any branch
                for(int i = 0; i < _BranchCount; i++)
                {
                    start = _BranchDataA[i].xy;
                    end = _BranchDataA[i].zw;
                    radius = _BranchDataB[i].x;

                    float d = sdCapsule(pos, start, end, radius); // Distance from point to current branch
                    minDist = min(minDist, d); // Update minimum distance if this branch is closer
                }

                return minDist;
            }

            float sdLeaf(float2 pos)
            {
                float leafDist = 1e5; // Start with a large distance
                // Loop through all leaves and find the minimum distance to any leaf
                for (int i = 0; i < _LeafCount; i++)
                {
                    float2 leafPos = _LeafPositions[i].xy;
                    float leafRadius = _LeafPositions[i].z * _LeafScale;
                    leafDist = min(leafDist, length(pos - leafPos) - leafRadius); // Distance from point to current leaf (circle) and update minimum distance
                }

                return leafDist;
            }

            struct SDFResult
            {
                float dist;
                int type; // 0 = branch, 1 = leaf
                int index; // Which branch / leaf
            };

            SDFResult EvaluateTree(float2 p)
            {
                SDFResult res;
                res.dist = 1e5;
                res.type = 0;
                res.index = 0;

                // Branches
                for (int i = 0; i < _BranchCount; i++)
                {
                    float2 start = _BranchDataA[i].xy;
                    float2 end = _BranchDataA[i].zw;
                    float radius = _BranchDataB[i].x;
                    
                    float d = sdCapsule(p, start, end, radius);

                    if (d < res.dist)
                    {
                        res.dist = d;
                        res.type = 0;
                        res.index = i;
                    }
                }

                // Leaves
                for (int i = 0; i < _LeafCount; i++)
                {
                    float2 leafPos = _LeafPositions[i].xy;
                    float leafRadius = _LeafPositions[i].z * _LeafScale;

                    float d = length(p - leafPos) - leafRadius;

                    if (d < res.dist)
                    {
                        res.dist = d;
                        res.type = 1;
                        res.index = i;
                    }
                }

                return res;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float2 p = IN.positionOS.xy * _TreeScale; // Scale the tree in 2D object space

                // float branchDist = sdTree(p);
                // float leafDist = sdLeaf(p); // Scale leaf distance separately

                SDFResult tree = EvaluateTree(p);
                float combinedDist = tree.dist;

                // Combine branch and leaf SDFs
                // float combinedDist = min(branchDist, leafDist);

                // Branch edge mask
                float edgeWidth = 0.01 * _Edge;
                float mask = 1.0 - smoothstep(-edgeWidth, edgeWidth, combinedDist);

                if (mask < 0.01)
                {
                    discard;
                }

                float eps = 0.001; // fwidth(combinedDist); // Epsilon - Small offset for gradient estimation

                // Sample SDFs around current point
                float dx = EvaluateTree(p + float2(eps, 0)).dist - combinedDist;
                float dy = EvaluateTree(p + float2(0, eps)).dist - combinedDist;

                // float dx = min(sdTree(p + float2(eps, 0)), sdLeaf(p + float2(eps, 0))) - combinedDist;
                // float dy = min(sdTree(p + float2(0, eps)), sdLeaf(p + float2(0, eps))) - combinedDist;

                // Surface normal is the gradient of the SDF
                float2 normal2D = normalize(float2(dx, dy) + 1e-5);

                // Convert normal to 3D
                float3 normalWS = normalize(float3(normal2D, 1));

                // CEL SHADING
                float ndotl = saturate(dot(normalWS, _LightDirection)); // Lambertian diffuse term
                ndotl = max(ndotl, 0.0);
                float cel = floor(ndotl * _Bands) / _Bands; // Quantize bands

                cel = smoothstep(-0.02, 0.02, ndotl); // Soften edges between bands

                float3 lighting = lerp(_ShadowColor.rgb, _LightColor.rgb, cel); // Interpolate between shadow and light color based on cel shading

                float3 treeColor = (0, 0, 0);

                if (tree.type == 0) // branch
                {
                    int i = tree.index;

                    float2 start = _BranchDataA[i].xy;
                    float2 end   = _BranchDataA[i].zw;
                    float radius = _BranchDataB[i].x;

                    float2 branchVector = end - start;
                    float branchLength = length(branchVector);

                    float2 dir = branchVector / branchLength;
                    float2 normal = float2(-dir.y, dir.x);

                    float2 relPos = p - start;

                    float u = dot(relPos, dir);
                    float v = dot(relPos, normal);

                    float2 uv;
                    uv.x = u / branchLength;
                    uv.y = v / radius * 0.5 + 0.5;
                    uv = saturate(uv);

                    float4 tex = SAMPLE_TEXTURE2D(_MainTexture, sampler_MainTexture, uv);
                    treeColor = tex.rgb * _BranchColor.rgb;
                }

                else if (tree.type == 1) // Leaf
                {
                    int i = tree.index;

                    float2 leafPos = _LeafPositions[i].xy;
                    float leafRadius = _LeafPositions[i].z * _LeafScale;

                    float2 offset = p - leafPos;
                    float2 uv = offset / leafRadius * 0.5 + 0.5;
                    uv = saturate(uv);

                    float4 tex = SAMPLE_TEXTURE2D(_LeafTexture, sampler_LeafTexture, uv);
                    treeColor = tex.rgb * _LeafColor.rgb;
                }

                float3 finalColor = treeColor * lighting;
                
                return float4(finalColor, mask);

                /* OLD CODE */
                // Loop through branches, check if they influence this pixel, and compute UVs
                // for (int i = 0; i < _BranchCount; i++)
                // {
                //     float2 start = _BranchDataA[i].xy;
                //     float2 end = _BranchDataA[i].zw;
                //     float radius = _BranchDataB[i].x;

                //     float2 branchVector = end - start;
                //     float branchLength = length(branchVector);

                //     float2 branchDirection = branchVector / branchLength; // Normalize to get direction
                //     float2 branchNormal = float2(-branchDirection.y, branchDirection.x); // Perpendicular to branch direction

                //     float2 relPos = p - start;

                //     float u = dot(relPos, branchDirection); // Along branch
                //     float v = dot(relPos, branchNormal); // Across branch

                //     float d = sdCapsule(p, start, end, radius);

                //     if (d <= 0) // Check if we're within the branch capsule
                //     { 
                //         float2 branchUV;

                //         branchUV.x = u / branchLength; // Normalize u to [0, 1] along the branch
                //         branchUV.y = v / radius * 0.5 + 0.5; 

                //         branchUV = saturate(branchUV);

                //         float4 branchTexColor = SAMPLE_TEXTURE2D(_MainTexture, sampler_MainTexture, branchUV); // Adjust UV scale as needed

                //         // float alpha = 1.0;
                //         branchColor = branchTexColor.rgb * _BranchColor.rgb * lighting;
                //     }
                // }

                // // Leaves
                // float leafRegion = step(leafDist, branchDist); // 1 in leaf region, 0 in branch region
                
                // // Loop through leaves, check if they influence this pixel, and compute UVs
                // float3 leafColor = (0, 0, 0);
                // for(int i = 0; i < _LeafCount; i++)
                // {
                //     float2 leafPos = _LeafPositions[i].xy;
                //     float leafRadius = _LeafPositions[i].z * _LeafScale;

                //     float2 offset = p - leafPos;

                //     float d = length(offset) - leafRadius;

                //     // Check if we're in the region of this leaf
                //     if(d <= 0.0)
                //     {
                //         // Sample leaf texture with UVs based on distance to leaf center
                //         float2 leafUV = offset / leafRadius * 0.5 + 0.5; // Scale UVs to fit the leaf

                //         leafUV = saturate(leafUV);

                //         float4 leafTex = SAMPLE_TEXTURE2D(_LeafTexture, sampler_LeafTexture, leafUV);

                //         // float alpha = 1.0;
                //         leafColor = leafTex.rgb * _LeafColor.rgb * lighting;
                //     }
                // }

                // float3 finalColor = lerp(branchColor, leafColor, leafRegion);


                // Debug draw
                // return float4(_LeafPositions[0].xy * 0.5 + 0.5, 0, 1);
            }
            ENDHLSL
        }
    }
}
