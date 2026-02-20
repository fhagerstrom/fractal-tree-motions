using UnityEngine;
using System.Collections.Generic;
using UnityEditor;
using Unity.VisualScripting;
public enum WindModel
{
    None,
    Sinusoidal,
    NoiseField,
    VectorField
}

[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public class FractalTree : MonoBehaviour
{
    [Header("Components")]
    public TreeBranch root;
    private MeshFilter meshFilter;
    private MeshRenderer meshRenderer;
    private Mesh treeMesh;
    public WindModel currentWindModel = WindModel.None; // Default wind model flag, can be switched in inspector

    // Parameters for tree generation
    [Header("Tree Generation")]
    public int maxDepth = 8;
    public float initialLength = 2f;
    public float lengthScale = 0.7f;
    public float branchAngle = 25f;
    public float branchWidth = 0.05f;
    public float widthScaleByDepth = 0.75f; // Multiplies width per depth

    [Header("Tree Noise")]
    public int seed = 0;
    public bool randomizeSeed = false; // Bool for randomizing seed if wanted
    public float angleNoiseScale = 20f;
    public float lengthNoiseScale = 0.2f;
    public float noiseFrequency = 1.0f;

    // Sway animation parameters (degrees and units)
    [Header("Sinusoidal Sway")]
    [HideInInspector] public float sineAmplitude = 5f; // Maximum angle offset at depth 0
    [HideInInspector] public float swayFrequency = 0.1f; // Oscillations per second
    [HideInInspector] public float depthAmplitudeScale = 0.8f; // How amplitude decreases per depth

    [Header("Scalar Noise Fields")]
    [HideInInspector] public Vector2 windDirection = new Vector2(1f, 0f); // Direction of the noise field "wind"
    [HideInInspector] public float noiseAmplitude = 2f; // Base amplitude of the noise effect on angles
    [HideInInspector] public float scalarWindDepthScale = 0.8f; // Decrease per depth
    [HideInInspector] public float windSpatialFrequency = 0.5f; // How quickly the noise changes across space
    [HideInInspector] public float windSpeed = 0.5f; // How quickly the noise field changes over time
    [HideInInspector] public float windStrength = 5f; // How strongly the noise field affects branch angles

    [Header("Vector Fields")]
    [HideInInspector] public float vectorWindAmplitude = 1f; // Base amplitude
    [HideInInspector] public float vectorWindDepthScale = 0.8f; // Decrease per depth
    [HideInInspector] public float vectorWindSpatialFrequency = 0.5f; // How quickly the noise changes across space
    [HideInInspector] public float vectorWindSpeed = 0.5f; // How quickly the noise changes across space


    void Start()
    {
        // lineRenderer = GetComponent<LineRenderer>();
        meshFilter = GetComponent<MeshFilter>();    
        meshRenderer = GetComponent<MeshRenderer>();

        treeMesh = GetComponent<Mesh>();

        treeMesh = new Mesh();

        treeMesh.name = "FractalTreeMesh";
        meshFilter.mesh = treeMesh;

        if (randomizeSeed == true)
            seed = Random.Range(0, 10000); // Randomize seed for different tree shapes each run

        root = GenerateBranch(null, new Vector2(0, -2), Mathf.PI / 2f, 0); // Start with a vertical trunk
    }

    // Update is called once per frame
    void Update()
    {
        // Switch between different wind models based on wind model enum
        switch (currentWindModel)
        {
            case WindModel.None:
                // No animation, just build the fractal tree as it is defined
                break;

            case WindModel.Sinusoidal:
                SinusoidalAnimation(root); // Sinusoidal sway
                break;

            case WindModel.NoiseField:
                ScalarNoiseWindAnimation(root); // Noise field propagation
                DebugScalarWind(root, 0.5f);
                break;

            case WindModel.VectorField:
                VectorWindAnimation(root);
                DebugVectorWind(root, 0.5f);
                break;
        }

        //// Animate branch angles before building the mesh so geometry follows the motion
        //SinusoidalAnimation(root);
        //NoiseWindAnimation(root);

        BuildTreeMesh(root);
        DebugDrawBranch(root); // Debug draw the tree for visualization
    }


    void BuildTreeMesh(TreeBranch root)
    {
        List<Vector3> vertices = new List<Vector3>();
        List<Vector3> normals = new List<Vector3>();
        List<int> triangles = new List<int>();
        List<Vector2> uvs = new List<Vector2>();

        vertices.Clear();
        triangles.Clear();
        uvs.Clear();

        // Add branch segments recursively (fills vertices and triangle indices)
        AddBranchRecursive(root, vertices, triangles, uvs, normals);

        treeMesh.Clear();
        treeMesh.SetVertices(vertices);
        treeMesh.SetTriangles(triangles, 0);
        treeMesh.SetUVs(0, uvs);
        treeMesh.SetNormals(normals);
        treeMesh.RecalculateBounds();
    }

    void AddBranchRecursive(TreeBranch branch, List<Vector3> vertices, List<int> triangles, List<Vector2> uvs, List<Vector3> normals)
    { 
        if (branch == null) 
            return;

        // Define the quad vertices for the current branch segment
        Vector2 start = branch.start;
        Vector2 end = branch.end;

        Vector2 direction = (end - start).normalized;
        Vector2 normal2D = new Vector2(-direction.y, direction.x); // Perpendicular to the branch direction

        float width = branchWidth * Mathf.Pow(widthScaleByDepth, branch.depth); // Decrease width with depth
        width = Mathf.Max(width, 0.01f); // Define minimum width to prevent infinite tapering

        Vector2 offset = normal2D * width; // Offset for the quad vertices on either side of the branch centerline

        int vertexIndex = vertices.Count;

        vertices.Add(start + offset); // Left vertex at start
        vertices.Add(start - offset); // Right vertex at start
        vertices.Add(end + offset); // Left vertex at end
        vertices.Add(end - offset); // Right vertex at end

        normals.Add(normal2D);
        normals.Add(normal2D);
        normals.Add(normal2D);
        normals.Add(normal2D);

        // Form a quad with two triangles: (v0, v2, v1) and (v2, v3, v1)
        triangles.Add(vertexIndex + 0);
        triangles.Add(vertexIndex + 2);
        triangles.Add(vertexIndex + 1);

        triangles.Add(vertexIndex + 1);
        triangles.Add(vertexIndex + 2);
        triangles.Add(vertexIndex + 3);

        uvs.Add(new Vector2(0, 0));
        uvs.Add(new Vector2(1, 0));
        uvs.Add(new Vector2(0, 1));
        uvs.Add(new Vector2(1, 1));

        foreach (var child in branch.childBranches)
        {
            AddBranchRecursive(child, vertices, triangles, uvs, normals);
        }
    }

    // Recursive function to generate the tree branches
    TreeBranch GenerateBranch(TreeBranch parent, Vector2 start, float angle, int depth)
    {
        // Length noise
        float baseLength = initialLength * Mathf.Pow(lengthScale, depth);

        float lengthNoise = Mathf.PerlinNoise((depth * seed) * noiseFrequency, 0f);

        float lengthVariation = 1f + (lengthNoise - 0.5f) * 2f * lengthNoiseScale;
        float length = baseLength * lengthVariation;

        // Angle noise
        float angleNoise = Mathf.PerlinNoise((start.x + seed) * noiseFrequency, (start.y + seed) * noiseFrequency);

        float angleVariation = (angleNoise - 0.5f) * 2f * angleNoiseScale * Mathf.Deg2Rad;

        float finalAngle = angle + angleVariation;

        // Create the current branch
        TreeBranch branch = new TreeBranch
        {
            parentBranch = parent,
            start = start,
            baseAngle = angle,
            currentAngle = finalAngle,
            length = length,
            depth = depth,
        };

        if (depth < maxDepth) // As long as we haven't reached the maximum depth, recursively create child branches
        {
            float offset = branchAngle * Mathf.Deg2Rad;

            TreeBranch left = GenerateBranch(branch, branch.end, finalAngle + offset, depth + 1);
            TreeBranch right = GenerateBranch(branch, branch.end, finalAngle - offset, depth + 1);

            branch.childBranches.Add(left);
            branch.childBranches.Add(right);
        }

        return branch;

    }

    // Apply a simple sinusoidal sway to each branch and update child start positions
    void SinusoidalAnimation(TreeBranch branch)
    {
        if (branch == null)
            return;

        // amplitude decreases with depth
        float ampRadius = sineAmplitude * Mathf.Pow(depthAmplitudeScale, branch.depth) * Mathf.Deg2Rad;
        // phase can vary by depth to produce cascading motion
        float phase = branch.depth * 0.3f;
        float offset = ampRadius * Mathf.Sin(Time.time * swayFrequency * 2f * Mathf.PI + phase);

        // Add stiffness to trunk
        float stiffness = Mathf.InverseLerp(0, 2, branch.depth);
        offset *= stiffness;

        branch.currentAngle = branch.baseAngle + offset;

        // Update children start positions and animate them
        foreach (var child in branch.childBranches)
        {
            child.start = branch.end;
            SinusoidalAnimation(child);
        }
    }

    void ScalarNoiseWindAnimation(TreeBranch branch)
    {
        if (branch == null)
            return;

        float offset = 0f;

        float ampRadius = noiseAmplitude * Mathf.Pow(scalarWindDepthScale, branch.depth) * Mathf.Deg2Rad; // Base amplitude scaled by depth

        // 1D noise based on branch position projected onto wind direction
        Vector2 direction = windDirection.normalized; // Normalize the wind direction, ensure it's a unit vector
        float projection = Vector2.Dot(branch.start, direction); // Project the branch's start position onto wind direction
        float coordinates = projection * windSpatialFrequency - Time.time * windSpeed; // Use projected coordinate to sample noise, time for animation
        float noiseValue = Mathf.PerlinNoise(coordinates, 0);

        float centered = noiseValue * 2f - 1f; // Center around 0

        // Add stiffness to trunk
        float stiffness = Mathf.InverseLerp(0, 2, branch.depth);

        offset = centered * ampRadius * windStrength;
        offset *= stiffness;

        branch.currentAngle = branch.baseAngle + offset;

        foreach (var child in branch.childBranches)
        {
            child.start = branch.end;
            ScalarNoiseWindAnimation(child);
        }
    }

    void VectorWindAnimation(TreeBranch branch)
    {
        if (branch == null)
            return;

        float offset = 0f;

        float ampRadius = vectorWindAmplitude * Mathf.Pow(vectorWindDepthScale, branch.depth) * Mathf.Deg2Rad; // Base amplitude scaled by depth

        Vector2 branchDirection = (branch.end - branch.start).normalized; // Define direction
        Vector2 branchNormal = new Vector2(-branchDirection.y, branchDirection.x); // Make sure it's perpendicular

        // Sample vector wind field at branch position
        Vector2 vectorWind = SampleVectorWind(branch.start);

        // Project wind onto normal for bending
        float bend = Vector2.Dot(vectorWind, branchNormal);

        // Add stiffness to trunk
        float stiffness = Mathf.InverseLerp(0, 2, branch.depth);

        offset = bend * ampRadius;
        offset *= stiffness;

        branch.currentAngle = branch.baseAngle + offset;

        foreach (var child in branch.childBranches)
        {
            child.start = branch.end;
            VectorWindAnimation(child);
        }
    }

    Vector2 SampleVectorWind(Vector2 pos)
    {
        float t = Time.time * vectorWindSpeed;

        // Noise for both axes
        float noiseX = Mathf.PerlinNoise(pos.x * vectorWindSpatialFrequency + t, pos.y + vectorWindSpatialFrequency);
        float noiseY = Mathf.PerlinNoise(pos.x * vectorWindSpatialFrequency, pos.y + vectorWindSpatialFrequency + t);

        // Center around 0
        Vector2 centered = new Vector2(noiseX * 2f - 1f, noiseY * 2f - 1f);

        return centered;
    }


    // DEBUG DRAW FOR TESTING

    void DebugDrawBranch(TreeBranch branch)
    {
        if (branch == null) 
            return;

        Debug.DrawLine(branch.start, branch.end, Color.white);

        foreach(var child in branch.childBranches)
        {
            DebugDrawBranch(child);
        }
    }

    void DebugVectorWind(TreeBranch branch, float scale)
    {
        if (branch == null) return;

        // Sample the vector wind
        Vector2 wind = SampleVectorWind(branch.start);

        // Draw a line from branch start in wind direction
        Debug.DrawLine(branch.start, branch.start + wind * scale, Color.yellow);

        // Recursively draw children
        foreach (var child in branch.childBranches)
        {
            DebugVectorWind(child, scale);
        }
    }

    void DebugScalarWind(TreeBranch branch, float scale)
    {
        if (branch == null)
            return;

        // Recompute the same scalar noise value
        float noiseValue = Mathf.PerlinNoise(branch.start.x * windSpatialFrequency + Time.time * windSpeed, branch.start.y * windSpatialFrequency);

        float centered = noiseValue * 2f - 1f;

        // Get branch direction & normal
        Vector2 branchDir = (branch.end - branch.start).normalized;
        Vector2 branchNormal = new Vector2(-branchDir.y, branchDir.x);

        // Draw along branch normal scaled by noise value
        Vector2 debugOffset = branchNormal * centered * scale;

        Debug.DrawLine(branch.start, branch.start + debugOffset, Color.red);

        foreach (var child in branch.childBranches)
        {
            DebugScalarWind(child, scale);
        }
    }


}


// Cstom editor to show / hide parameters based on the selected wind model in the inspector
#if UNITY_EDITOR
[CustomEditor(typeof(FractalTree))]
public class TreeEditor : Editor
{

    SerializedProperty windModelProp;

    void OnEnable()
    {
        windModelProp = serializedObject.FindProperty("currentWindModel");
    }

    public override void OnInspectorGUI()
    {
        serializedObject.Update();

        // Draw everything EXCEPT wind-related fields
        DrawPropertiesExcluding(serializedObject,
            "currentWindModel",
            "sineAmplitude",
            "swayFrequency",
            "depthAmplitudeScale",
            "noiseAmplitude",
            "windSpeed",
            "windStrength",
            "windSpatialFrequency",
            "windDirection"
        );

        EditorGUILayout.Space();

        EditorGUILayout.PropertyField(windModelProp);

        WindModel model = (WindModel)windModelProp.enumValueIndex;

        // Switch statement on enum flags
        switch (model)
        {
            case WindModel.None:
                // No additional parameters to show
                EditorGUILayout.HelpBox("No wind model selected. Select a wind model to expose parameters!", MessageType.Info);
                break;

            case WindModel.Sinusoidal:
                EditorGUILayout.PropertyField(serializedObject.FindProperty("sineAmplitude"));
                EditorGUILayout.PropertyField(serializedObject.FindProperty("swayFrequency"));
                EditorGUILayout.PropertyField(serializedObject.FindProperty("depthAmplitudeScale"));
                break;

            case WindModel.NoiseField:
                EditorGUILayout.PropertyField(serializedObject.FindProperty("windDirection"));
                EditorGUILayout.PropertyField(serializedObject.FindProperty("noiseAmplitude"));
                EditorGUILayout.PropertyField(serializedObject.FindProperty("depthAmplitudeScale"));
                EditorGUILayout.PropertyField(serializedObject.FindProperty("windSpeed"));
                EditorGUILayout.PropertyField(serializedObject.FindProperty("windStrength"));
                EditorGUILayout.PropertyField(serializedObject.FindProperty("windSpatialFrequency"));
                break;

            case WindModel.VectorField:
                EditorGUILayout.PropertyField(serializedObject.FindProperty("vectorWindAmplitude"));
                EditorGUILayout.PropertyField(serializedObject.FindProperty("vectorWindDepthScale"));
                EditorGUILayout.PropertyField(serializedObject.FindProperty("vectorWindSpatialFrequency"));
                EditorGUILayout.PropertyField(serializedObject.FindProperty("vectorWindSpeed"));
                break;
        }

        serializedObject.ApplyModifiedProperties();

    }

}
#endif