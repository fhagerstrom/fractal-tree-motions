using UnityEngine;
using System.Collections.Generic;

public class FractalTreeTest : MonoBehaviour
{
    // Parameters for tree generation
    public int maxDepth = 5;
    public float initialLength = 2f;
    public float lengthScale = 0.7f;
    public float branchAngle = 25f;

    private TreeBranch root;
    void Start()
    {
        root = GenerateBranch(null, Vector2.zero, Mathf.PI / 2f, 0); // Start with a vertical trunk
    }

    // Update is called once per frame
    void Update()
    {
        DrawBranch(root); // Debug draw the tree for visualization
    }

    // Recursive function to generate the tree branches
    TreeBranch GenerateBranch(TreeBranch parent, Vector2 start, float angle, int depth)
    {
        float length = initialLength * Mathf.Pow(lengthScale, depth);

        // Create the current branch
        TreeBranch branch = new TreeBranch
        {
            parentBranch = parent,
            start = start,
            baseAngle = angle,
            currentAngle = angle,
            length = length,
            depth = depth,
        };

        if (depth < maxDepth) // As long as we haven't reached the maximum depth, recursively create child branches
        {
            float offset = branchAngle * Mathf.Deg2Rad;

            TreeBranch left = GenerateBranch(branch, branch.End, angle + offset, depth + 1);
            TreeBranch right = GenerateBranch(branch, branch.End, angle - offset, depth + 1);

            branch.childBranches.Add(left);
            branch.childBranches.Add(right);
        }

        return branch;

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
