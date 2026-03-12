using UnityEngine;
using System.Collections.Generic;

// Plain data class representing a single branch in the tree structure
public class TreeBranch
{
    public TreeBranch parentBranch;
    public List<TreeBranch> childBranches = new List<TreeBranch>();
    public List<Vector2> leafOffsets = new List<Vector2>();

    public Vector2 start;

    public float baseAngle;
    public float currentAngle;
    public float angularVelocity; // How quickly the branch swings back and forth, for spring-like motion
    public float angleOffset; // Random offset to make each branch swing differently, for spring-like motion

    public float length;
    public float depth;

    // Calculate end point based on start, angle, and length
    public Vector2 end => start + new Vector2(Mathf.Cos(currentAngle), Mathf.Sin(currentAngle)) * length;

}
