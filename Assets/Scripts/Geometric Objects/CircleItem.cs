using System;
using Unity.Mathematics;
using UnityEditor;
using UnityEngine;

public struct Circle
{
    public Vector3 center;   // 圆心坐标
    public Vector3 normal;   // 平面法线，要求单位化
    public float radius;    // 半径
};

public class CircleItem : MonoBehaviour
{
    [Header("Circle")]
    public float radius;
    
    
    [Header("Gizmos")]
    public bool drawGizmos;

    public Circle GetCircle()
    {
        Circle circle = new Circle();
        circle.radius = radius;
        circle.center = transform.position;
        circle.normal = transform.rotation * Vector3.up;
        return circle;
    }

   public static bool GetPointOnLine(Circle circle, Line l, out float3 pointt)
    {
        pointt = new float3(0, 0, 0);

        float denom = Vector3.Dot(l.dir, circle.normal);

        // 1. 判断线是否与圆所在的平面平行
        if (Mathf.Abs(denom) < 1e-6)
        {
            return false; // 平行或共面，认为无交点
        }

        // 2. 求 t，使得线上的点 P = origin + t * dir 落在圆所在的平面上
        float t = Vector3.Dot(circle.center - l.origin, circle.normal) / denom;

        // 3. 如果是射线，可以加入 t < 0 的剔除（可选）
        if (t < 0)
        {
            return false; // 射线方向上无交点
        }

        // 4. 得到平面上的交点
        float3 p = l.origin + t * l.dir;

        // 5. 判断该交点是否在圆的范围内（在圆的半径之内）
        if (Vector3.Distance(p, circle.center) <= circle.radius)
        {
            pointt = p;
            return true;
        }

        return false; // 落在圆所在的平面上但不在圆内
    }

    private void OnDrawGizmos()
    {
        if (!drawGizmos || radius <= 0f) return;

        // 画圆：法线方向 = transform.up
        Handles.color = Color.yellow;
        Handles.DrawWireDisc(transform.position, transform.up, radius);

        // 画法线：从圆心指向法线方向
        Gizmos.color = Color.cyan;
        Gizmos.DrawLine(transform.position, transform.position + transform.up * radius);
    }
}