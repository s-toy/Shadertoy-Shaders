#define	AA 2

struct Material 
{
	vec3 albedo;
    vec3 fresnelColor;
    float roughness;
};

vec3 rotateYX(vec3 vector, vec2 angle) 
{
    vector.yz = cos(angle.y) * vector.yz + sin(angle.y) * vec2(-1, 1) * vector.zy;
    vector.xz = cos(angle.x) * vector.xz + sin(angle.x) * vec2(-1, 1) * vector.zx;
    return vector;
}

vec3 rotateZ(in vec3 v, float a)
{
    return vec3(cos(a) * v.x - sin(a) * v.y, sin(a) * v.x + cos(a) * v.y, v.z);
}

float smax(float a, float b, float k)
{
    float h = max(k - abs(a - b), 0.0);
    return max(a, b) + h * h * 0.25 / k;
}

//distance operations
vec2 opUnion(vec2 a, vec2 b) { return a.x < b.x ? a : b; }

float opSub(float a, float b) { return max(-a, b); } //substraction

//distance functions
float sdSphere(vec3 pos, float radius) { return length(pos) - radius; }

float sdPlane(vec3 pos, vec3 normal) { return dot(pos, normal); }

float sdEllipsoid(vec3 pos, vec3 size)
{
    return (length( pos / size ) - 1.0) * min(min(size.x, size.y), size.z);
}