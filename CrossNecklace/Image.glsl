#define	AA 2
#define PI 3.1415926
#define TAO (2.0*PI)

struct Material {
	vec3 albedo;
    float roughness;
    float metallic;
};

Material shape_materials[] = Material[] (
    Material(vec3(0.85, 0.7, 0.2), 0.3, 0.9),
    Material(vec3(1.0, 1.0, 1.0), 0.3, 0.9)
);

vec2 rotate(vec2 v, float a) { return cos(a)*v + sin(a)*vec2(v.y,-v.x); }

mat3 lookAt(vec3 eye, vec3 center, vec3 up) {
	vec3 f = normalize(center - eye);
	vec3 s = normalize(cross(f, up));
	vec3 u = cross(s, f);
    return mat3(s, u, -f);
}

vec2 opU(vec2 a, vec2 b) { return a.x < b.x ? a : b; }

float sdRoundBox(vec3 p, vec3 b, float r) { return length(max(abs(p) - b, 0.0)) - r; }

float sdTorus(vec3 p, vec2 t) {
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q) - t.y;
}

float sdLink(vec3 p, float le, float r1, float r2) {
    vec3 q = vec3(p.x, max(abs(p.y)-le,0.0), p.z);
    return length(vec2(length(q.xy)-r1,q.z)) - r2;
}

vec2 mapScene(vec3 p) { 
    float shapeIndex = 0.0;
    
    p.y += 0.8;
    vec3 p1 = p - vec3(0, 6.06, 0), p2 = p1;
    float d = TAO/32.0, a = atan(p1.x, -p1.y)*1.0/d;
 	p1.xy = rotate(p1.xy, floor(0.5+a)*d) + vec2(0, 4.0);
    p2.xy = rotate(p2.xy, (floor(a)+0.5)*d) + vec2(0, 4.0);
    
    vec2 res = vec2(sdLink(p1.yxz, 0.125, 0.1, 0.03), shapeIndex);
    res = opU(res, vec2(sdLink(p2.zxy, 0.125, 0.1, 0.03), shapeIndex++));
    res = opU(res, vec2(sdRoundBox(p, 	vec3(1.4, 0.2, 0.1), 0.1), shapeIndex));
    res = opU(res, vec2(sdRoundBox(p  -	vec3(0, -1.0, 0), vec3(0.2, 2.4, 0.1), 0.1), shapeIndex));
    res = opU(res, vec2(sdTorus(p.yxz - vec3(2.0, 0, 0), vec2(0.25, 0.06)), shapeIndex));
    res = opU(res, vec2(sdTorus(p.xzy - vec3(0, 0, 1.7), vec2(0.18, 0.05)), shapeIndex++));
    return res;
}

float sdScene(vec3 pos) { return mapScene(pos).x; }

vec3 calculateNormal(in vec3 point) {
    const vec3 step = vec3(0.01, 0.0, 0.0);
    float gradX = sdScene(point + step.xyy) - sdScene(point - step.xyy);
    float gradY = sdScene(point + step.yxy) - sdScene(point - step.yxy);
    float gradZ = sdScene(point + step.yyx) - sdScene(point - step.yyx);
    
    vec3 normal = vec3(gradX, gradY, gradZ);
    return normalize(normal);
}

vec2 rayMarch(vec3 ray_origin, vec3 ray_direction) {
    const float MAX_TRACE_DISTANCE = 200.0;
    
    float totalDistance = 0.0, shapeIndex = -1.0;
    for (int i = 0; i < 128; ++i) {
        vec2 res = mapScene(ray_origin + totalDistance * ray_direction);
        float minHitDistance = 0.0005 * totalDistance;
        if (res.x < minHitDistance) {
            shapeIndex = res.y; break; 
        }
        if (totalDistance > MAX_TRACE_DISTANCE) break;
        totalDistance += res.x;
    }
    
	return vec2(totalDistance, shapeIndex);
}

vec3 render(vec3 ray_origin, vec3 ray_direction) {
	vec3 color = pow(texture(iChannel0, ray_direction).rgb, vec3(2.2));
    
    vec2 res = rayMarch(ray_origin, ray_direction);
    int shapeIndex = int(res.y);
    if (shapeIndex >= 0) {
        vec3 p = ray_origin + ray_direction * res.x;
        vec3 N = calculateNormal(p);
		vec3 L = normalize(vec3(1, 1, 1));
		float NdotL = max(0.0, dot(N, L));
        
		vec3 ambient = mix(vec3(0.07), vec3(0.05, 0.1, 0.15), N.y * 0.5 + 0.5);
		vec3 lightCol = vec3(1.0 ,0.9, 0.8);

        Material mat = shape_materials[shapeIndex];
		color = mat.albedo * (NdotL * lightCol + ambient);
       
		vec3 reflection = reflect(ray_direction, N);
		vec3 refMap = pow(texture(iChannel0, reflection).rgb, vec3(2.2));
        vec3 F0 = mix(vec3(0.04), mat.albedo, mat.metallic);
		vec3 fresnel = mix(F0, vec3(1.0 - mat.roughness), pow(dot(N, ray_direction) + 1.0, 5.0));
		color = mix(color.rgb, refMap, fresnel);
    }
    
    return color;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec3 totalColor = vec3(0.0);
    float angle = iMouse.z > 0.0 ? (iMouse.x / iResolution.x - 0.5) * 3.14 : -0.1;
    vec3 rayOrigin = 9.0*vec3(sin(angle), 0.3, cos(angle));
    mat3 viewMat = lookAt(rayOrigin, vec3(0.0), vec3(0.0, 1.0, 0.0));
    
    for (int i = 0; i < AA; ++i)  {
    	for (int k = 0; k < AA; ++k)  {
        	vec2 offset = vec2(float(i) + .5, float(k) + .5) / float(AA) - .5;
        	vec2 uv = (fragCoord + offset - iResolution.xy * 0.5) / iResolution.y;
    		vec3 rayDirection = normalize(viewMat * vec3(uv, -1.0));
        	totalColor += render(rayOrigin, rayDirection);
            totalColor = totalColor * (1.0 - dot(uv, uv) * 0.5);
        }
    }         
    
	totalColor /= float(AA * AA);
    totalColor = pow(totalColor, vec3(0.4545));
    
	fragColor = vec4(totalColor, 1.0);
}