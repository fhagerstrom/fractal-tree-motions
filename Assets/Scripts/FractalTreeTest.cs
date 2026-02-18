using UnityEngine;
using System.Collections.Generic;
using UnityEngine.UIElements;

[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public class FractalTreeTest : MonoBehaviour
{

    [Header("Components")]
    private TreeBranch root;
    private MeshFilter meshFilter;
    private MeshRenderer meshRenderer;
    private Mesh treeMesh;

    // Parameters for tree generation
    [Header("Tree Generation")]
    public int maxDepth = 5;
    public float initialLength = 2f;
    public float lengthScale = 0.7f;
    public float branchAngle = 25f;
    public float branchWidth = 0.05f;
    public float widthScaleByDepth = 0.75f; // Multiplies width per depth

    [Header("Noise")]
    public float angleNoiseScale = 20f;
    public float lengthNoiseScale = 0.2f;
    public float noiseFrequency = 1.0f;
    public int seed = 0; // Randomized at start. Set for reproducability

    // Sway animation parameters (degrees and units)
    [Header("Sinusoidal Sway")]
    public float swayAmplitude = 5f; // Maximum angle offset at depth 0
    public float swayFrequency = 0.1f; // Oscillations per second
    public float depthAmplitudeScale = 0.8f; // How amplitude decreases per depth

    void Start()
    {
        // lineRenderer = GetComponent<LineRenderer>();
        meshFilter = GetComponent<MeshFilter>();    
        meshRenderer = GetComponent<MeshRenderer>();

        treeMesh = GetComponent<Mesh>();

        treeMesh = new Mesh();

        treeMesh.name = "FractalTreeMesh";
        meshFilter.mesh = treeMesh;

        seed = Random.Range(0, 65536);

        root = GenerateBranch(null, new Vector2(0, -2), Mathf.PI / 2f, 0); // Start with a vertical trunk
    }

    // Update is called once per frame
    void Update()
    {
        // Animate branch angles before building the mesh so geometry follows the motion
        SinusoidalAnimation(root);

        BuildTreeMesh(root);

        DrawBranch(root); // Debug draw the tree for visualization
    }


    void BuildTreeMesh(TreeBranch root)
    {
        List<Vector3> vertices = new List<Vector3>();
        List<int> triangles = new List<int>();

        // Add branch segments recursively (fills vertices and triangle indices)
        AddBranchRecursive(root, vertices, triangles);
        treeMesh.Clear();
        treeMesh.SetVertices(vertices);
        treeMesh.SetTriangles(triangles, 0);
        treeMesh.RecalculateBounds();
        treeMesh.RecalculateNormals();
    }

    void AddBranchRecursive(TreeBranch branch, List<Vector3> vertices, List<int> triangles)
    { 
        if (branch == null) 
            return;

        // Define the quad vertices for the current branch segment
        Vector2 start = branch.start;
        Vector2 end = branch.End;

        Vector2 direction = (end - start).normalized;
        Vector2 normal = new Vector2(-direction.y, direction.x); // Perpendicular to the branch direction

        float width = branchWidth * Mathf.Pow(widthScaleByDepth, branch.depth); // Decrease width with depth
        width = Mathf.Max(width, 0.01f); // Define minimum width to prevent infinite tapering

        Vector2 offset = normal * width; // Offset for the quad vertices on either side of the branch centerline

        int vertexIndex = vertices.Count;

        vertices.Add(start + offset); // Left vertex at start
        vertices.Add(start - offset); // Right vertex at start
        vertices.Add(end + offset); // Left vertex at end
        vertices.Add(end - offset); // Right vertex at end

        // Form a quad with two triangles: (v0, v2, v1) and (v2, v3, v1)
        triangles.Add(vertexIndex + 0);
        triangles.Add(vertexIndex + 2);
        triangles.Add(vertexIndex + 1);

        triangles.Add(vertexIndex + 1);
        triangles.Add(vertexIndex + 2);
        triangles.Add(vertexIndex + 3);

        foreach (var child in branch.childBranches)
        {
            AddBranchRecursive(child, vertices, triangles);
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

            TreeBranch left = GenerateBranch(branch, branch.End, finalAngle + offset, depth + 1);
            TreeBranch right = GenerateBranch(branch, branch.End, finalAngle - offset, depth + 1);

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
        float ampRad = swayAmplitude * Mathf.Pow(depthAmplitudeScale, branch.depth) * Mathf.Deg2Rad;
        // phase can vary by depth to produce cascading motion
        float phase = branch.depth * 0.3f;
        float offset = ampRad * Mathf.Sin(Time.time * swayFrequency * 2f * Mathf.PI + phase);

        branch.currentAngle = branch.baseAngle + offset;

        // Update children start positions and animate them
        foreach (var child in branch.childBranches)
        {
            child.start = branch.End;
            SinusoidalAnimation(child);
        }
    }

    // DEBUG DRAW FOR TESTING

    void DrawBranch(TreeBranch branch)
    {
        if (branch == null) 
            return;

        Debug.DrawLine(branch.start, branch.End, Color.white);

        foreach(var child in branch.childBranches)
        {
            DrawBranch(child);
        }
    }
}
