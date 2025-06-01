struct Cone
{
    float3 apex;         // 顶点位置
    float3 axis;         // 方向单位向量（从顶点指向底面中心）
    float bottomRadius;  // 底面半径
    float height;        // 高度，从顶点开始
};

// 初始化函数
Cone CreateCone(float3 apex, float3 axis, float bottomRadius, float height)
{
    Cone cone;
    cone.apex = apex;
    cone.axis = normalize(axis);  // 确保方向是单位向量
    cone.bottomRadius = bottomRadius;
    cone.height = height;
    return cone;
}



#include "Assets/Shader/Library/Line.hlsl"

bool GetLineCrossCone(out float3 nearPoint, out float3 farPoint, Cone cone, Line inputLine)
{
    float3 Va = cone.axis; // 圆锥方向单位向量
    float3 V = inputLine.dir;              // 直线方向向量
    float3 deltaP = inputLine.origin - cone.apex;

    float cosTheta = cone.bottomRadius / sqrt(cone.bottomRadius * cone.bottomRadius + cone.height * cone.height);
    float cos2 = cosTheta * cosTheta;

    float3 VxVa = V - dot(V, Va) * Va;
    float3 deltaPxVa = deltaP - dot(deltaP, Va) * Va;

    float A = dot(VxVa, VxVa) - cos2 * dot(V, Va) * dot(V, Va);
    float B = 2 * (dot(VxVa, deltaPxVa) - cos2 * dot(V, Va) * dot(deltaP, Va));
    float C = dot(deltaPxVa, deltaPxVa) - cos2 * dot(deltaP, Va) * dot(deltaP, Va);

    float discriminant = B * B - 4 * A * C;
    if (discriminant < 0)
    {
        return false;
    }

    float sqrtDisc = sqrt(discriminant);
    float t1 = (-B - sqrtDisc) / (2 * A);
    float t2 = (-B + sqrtDisc) / (2 * A);

    // 保证 t1 是较小的交点
    if (t1 > t2)
    {
        float temp = t1;
        t1 = t2;
        t2 = temp;
    }

    float3 p1 = inputLine.origin + t1 * V;
    float3 p2 = inputLine.origin + t2 * V;

    float h1 = dot(p1 - cone.apex, Va);
    float h2 = dot(p2 - cone.apex, Va);

    // 检查两个点是否在合法高度内（0 到 height）
    bool valid1 = (h1 >= 0) && (h1 <= cone.height);
    bool valid2 = (h2 >= 0) && (h2 <= cone.height);

    if (valid1 && valid2)
    {
        nearPoint = p1;
        farPoint = p2;
        return true;
    }
    else if (valid1)
    {
        nearPoint = p1;
        farPoint = p1;
        return true;
    }
    else if (valid2)
    {
        nearPoint = p2;
        farPoint = p2;
        return true;
    }

    return false;
}


//从顶点开始
float GetRadiusAtHeight(Cone cone, float h)
{
    return (cone.bottomRadius/cone.height)*h;
}

