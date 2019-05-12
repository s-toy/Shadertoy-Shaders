#define	AA 2

struct Material 
{
	vec3 albedo;
    vec3 fresnelColor;
    float roughness;
};

void rotate(inout vec3 vector, vec2 angle) 
{
    vector.yz = cos(angle.y) * vector.yz + sin(angle.y) * vec2(-1, 1) * vector.zy;
    vector.xz = cos(angle.x) * vector.xz + sin(angle.x) * vec2(-1, 1) * vector.zx;
}

//distance operations
vec2 opU(vec2 a, vec2 b) { return a.x < b.x ? a : b; } //union

float opI(float a, float b) { return max(a, b); } //intersection

float opS(float a, float b) { return max(-a, b); } //substraction

//distance functions
float sdSphere(vec3 pos, float radius) { return length(pos) - radius; }

float sdPlane(vec3 pos, vec3 normal) { return dot(pos, normal); }

float sdBox(vec3 pos, vec3 size) 
{
    vec3 d = abs(pos) - size;
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}