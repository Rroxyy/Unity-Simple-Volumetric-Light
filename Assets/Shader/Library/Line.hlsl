struct Line
{
    float3 origin;      // 不再用 point，改用 origin 更通用
    float3 dir;         // direction 改成 dir
};

//罗德里格斯公式
//v:旋转的向量
//axis：旋转轴
//angle：旋转弧长
//大拇指方向是axis
float3 RotateAroundAxis(float3 v, float3 axis, float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

Line CreateLine(float3 _origin, float3 _dir)
{
    Line l;
    l.origin = _origin;
    l.dir = normalize(_dir); // 可选：方向归一化
    return l;
}

float3 GetLinePointByLen(Line l,float _len)
{
    return l.origin + _len*l.dir;
}

//某点到直线距离
float GetLineDistance(Line l,float3 targetPoint)
{
    float3 dir=targetPoint-l.origin;
    float3 crossVec=cross(dir,l.dir);
    return length(crossVec);
}

//直线上距离目标点最近的点（点对线做投影）
float3 GetClosestPointOnLine(Line l, float3 p)
{
    float3 v = p - l.origin;
    float t = dot(v, l.dir);  
    return l.origin + t * l.dir;
}

//返回弧度
float GetAngleRad(Line l1,Line l2)
{
    float3 a =l1.dir;
    float3 b =l2.dir;

    return acos(dot(normalize(a), normalize(b)));
}

//返回弧度
float GetAngleRad(float3 a,float3 b)
{
    return acos(dot(normalize(a), normalize(b)));
}