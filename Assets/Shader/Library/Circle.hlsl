struct Circle
{
    float3 center;   // 圆心坐标
    float3 normal;   // 平面法线，要求单位化
    float radius;    // 半径
};

Circle CreateCircle(float3 center, float3 normal, float radius)
{
    Circle c;
    c.center = center;
    c.normal = normalize(normal);
    c.radius = radius;
    return c;
}

//圆画在纸上，如果平面法线从纸内射朝纸外，逆时针
//pointOnCircle：起始点
float3 GetPointOnCircle(Circle circle, float3 pointOnCircle, float arcLength)
{
    float3 u = normalize(pointOnCircle - circle.center);
    float3 t = normalize(cross(circle.normal, u));
    float theta = arcLength / circle.radius;
    float3 p2 = circle.center + circle.radius * (cos(theta) * u + sin(theta) * t);
    return p2;
}

#include "Assets/Shader/Library/Line.hlsl"

bool GetPointOnLine(Circle circle, Line l, out float3 pointt)
{
    pointt = float3(0, 0, 0);

    float denom = dot(l.dir, circle.normal);

    // 1. 判断线是否与圆所在的平面平行
    if (abs(denom) < 1e-6)
    {
        return false; // 平行或共面，认为无交点
    }

    // 2. 求 t，使得线上的点 P = origin + t * dir 落在圆所在的平面上
    float t = dot(circle.center - l.origin, circle.normal) / denom;

    // 3. 如果是射线，可以加入 t < 0 的剔除（可选）
    if (t < 0)
    {
        return false; // 射线方向上无交点
    }

    // 4. 得到平面上的交点
    float3 p = l.origin + t * l.dir;

    // 5. 判断该交点是否在圆的范围内（在圆的半径之内）
    if (distance(p, circle.center) <= circle.radius)
    {
        pointt = p;
        return true;
    }

    return false; // 落在圆所在的平面上但不在圆内
}
