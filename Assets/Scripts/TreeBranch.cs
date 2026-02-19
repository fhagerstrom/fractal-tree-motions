using UnityEngine;
using System.Collections.Generic;

// Plain data class representing a single branch in the tree structure
public class TreeBranch
{
    public TreeBranch parentBranch;
    public List<TreeBranch> childBranches = new List<TreeBranch>();

    public Vector2 start;

    public float baseAngle;
    public float currentAngle;

    public float length;
    public float depth;

    // Calculate end point based on start, angle, and length
    public Vector2 end => start + new Vector2(Mathf.Cos(currentAngle), Mathf.Sin(currentAngle)) * length;

}
