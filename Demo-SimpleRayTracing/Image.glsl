#define HASHSCALE3 vec3(.1031, .1030, .0973)

const int NUM_SAMPLES = 50;
const int MAX_REFLECTIONS = 5;

struct Material 
{
	vec3 albedo;
    float roughness;
};

Material shape_materials[] = Material[] (
    Material(vec3(0.0, 0.7, 0.7), 0.2f),
    Material(vec3(0.6, 0.6, 0.0), 0.8f),
    Material(vec3(0.4), 0.1f),
    Material(vec3(0.8), 0.0f),
    Material(vec3(0.8), 0.4f),
    Material(vec3(0.5), 0.9f)
);

struct RayCastHitInfo
{
    vec3 pos;
    vec3 normal;
    Material material;
};

mat3 lookAt(in vec3 eye, in vec3 center, in vec3 up)
{
	vec3 f = normalize(center - eye);
	vec3 s = normalize(cross(f, up));
	vec3 u = cross(s, f);
    return mat3(s, u, -f);
}

vec2 hash21(float p)
{
	vec3 p3 = fract(vec3(p) * HASHSCALE3);
	p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.xx+p3.yz)*p3.zy);
}

vec3 hash33(vec3 p3)
{
	p3 = fract(p3 * HASHSCALE3);
    p3 += dot(p3, p3.yxz+19.19);
    return fract((p3.xxy + p3.yxx)*p3.zyx);
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

vec2 mapScene(vec3 pos) 
{ 
    float shapeIndex = 0.0;
    vec2 res = vec2(sdSphere(pos - vec3(0, 0, 0), 1.0), shapeIndex++);
    res = opU(res, vec2(opI(sdBox(pos - vec3(3, 0, 0), vec3(0.8)), sdSphere(pos - vec3(3, 0, 0), 1.0)), shapeIndex++));
    res = opU(res, vec2(sdSphere(pos - vec3(-3, 0, 0), 1.0), shapeIndex++));
    res = opU(res, vec2(sdSphere(pos - vec3(0, 0, -3), 1.0), shapeIndex++));
    res = opU(res, vec2(opS(sdSphere(pos - vec3(0, 0, 3), 1.0), sdBox(pos - vec3(0, 0, 3), vec3(0.8))), shapeIndex++ ));
    res = opU(res, vec2(sdPlane(pos - vec3(0, -1, 0), vec3(0, 1, 0)), shapeIndex++));
    return res;
}

float sdScene(vec3 pos) { return mapScene(pos).x; }

vec3 calculateNormal(in vec3 point) 
{
    const vec3 step = vec3(0.01, 0.0, 0.0);
    float gradX = sdScene(point + step.xyy) - sdScene(point - step.xyy);
    float gradY = sdScene(point + step.yxy) - sdScene(point - step.yxy);
    float gradZ = sdScene(point + step.yyx) - sdScene(point - step.yyx);
    
    vec3 normal = vec3(gradX, gradY, gradZ);
    return normalize(normal);
}

vec2 rayMarch(vec3 rayOri, vec3 rayDir)
{
    const float MAX_TRACE_DISTANCE = 200.0;
    
    float totalDistance = 0.0, shapeIndex = -1.0;
    for (int i = 0; i < 128; ++i) {
        vec2 res = mapScene(rayOri + totalDistance * rayDir);
        float minHitDistance = 0.0005 * totalDistance;
        if (res.x < minHitDistance) {
            shapeIndex = res.y; break; 
        }
        if (totalDistance > MAX_TRACE_DISTANCE) break;
        totalDistance += res.x;
    }
    
	return vec2(totalDistance, shapeIndex);
}

bool scatter(in vec3 rayDir,in RayCastHitInfo hitInfo, out vec3 scatteredDir, out vec3 attenuation)
{
    Material mat = hitInfo.material;
	scatteredDir = reflect(rayDir, hitInfo.normal) + hash33(1.e4 * hitInfo.pos) * mat.roughness;
	attenuation = mat.albedo;
    return dot(scatteredDir, hitInfo.normal) > 0.0;
}

vec3 render(in vec3 rayOri, in vec3 rayDir)
{
	vec3 rayColor = vec3(1.0);
    for (int i = 0; i <= MAX_REFLECTIONS; ++i)
    {
		vec2 res = rayMarch(rayOri, rayDir);
    	int shapeIndex = int(res.y);
        bool hit = shapeIndex >= 0;
        
    	if (hit) {
            RayCastHitInfo hitInfo;
        	hitInfo.pos = rayOri + rayDir * res.x;
        	hitInfo.normal = calculateNormal(hitInfo.pos);
            hitInfo.material = shape_materials[shapeIndex];
 
            vec3 scatteredDir, attenuation;
            if (scatter(rayDir, hitInfo, scatteredDir, attenuation)) {
            	rayColor *= attenuation;
            	rayOri = hitInfo.pos;
            	rayDir = scatteredDir;
            }
    	}
        else {
        	break;
        }    
    }
    
    vec3 bgColor = texture(iChannel0, rayDir).rgb;
	rayColor *= bgColor;
    
    return rayColor;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) 
{
    vec3 totalColor = vec3(0.0);
    vec2 angle = (iMouse.z > 0.5) ? 4.0*(2.0*iMouse.xy/iResolution.xy-1.0) : vec2(0.0);
    vec3 rayOri = vec3(12.0*cos(angle.x), angle.y+3.0, 12.0*sin(angle.x));
    vec3 rayTgt = vec3(0.0);
    mat3 viewMat = lookAt(rayOri, rayTgt, vec3(0.0, 1.0, 0.0));
    
    for (int i = 0; i < NUM_SAMPLES; ++i) {
        vec2 offset = vec2(hash21(float(i)));
        vec2 uv = (fragCoord + offset - iResolution.xy * 0.5) / iResolution.x;
		vec3 rayDir = normalize(viewMat * vec3(uv, -1.0));

   		vec3 color = render(rayOri, rayDir);
        totalColor += color;
    }         
    
	totalColor /= float(NUM_SAMPLES);
    totalColor = pow(totalColor, vec3(1.0/2.2));
	fragColor = vec4(totalColor, 1.0);
}