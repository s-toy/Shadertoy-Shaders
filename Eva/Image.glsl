Material shape_materials[] = Material[] (
    Material(vec3(1.0, 1.0, 1.0), vec3(0.05), 0.5f),
    Material(vec3(1.0, 1.0, 1.0), vec3(0.05), 0.5f),
    Material(vec3(0.0, 0.0, 0.0), vec3(0.05), 0.5f),
    Material(vec3(0.0, 0.4, 1.0), vec3(0.05), 0.5f),   
    Material(vec3(1.0, 1.0, 1.0), vec3(0.05), 0.5f),
    Material(vec3(1.0, 1.0, 1.0), vec3(0.0), 0.9f)
);

float mapBody(vec3 pos)
{
	return opSub(sdSphere(pos - vec3(0, 3.5, 0), 2.0), sdEllipsoid(pos - vec3(0, 2.0, 0), vec3(1.0, 3.0, 0.8)));
}

float mapHead(vec3 pos)
{
    return smax(sdSphere(pos - vec3(0, 2.2, 0), 0.95), sdEllipsoid(pos - vec3(0, 5.0, 0), vec3(2.0, 3.3, 2.0)), 0.1);
}

float mapFace(vec3 pos)
{
    return sdEllipsoid(pos - vec3(0, 2.4, 0.45), vec3(0.7, 0.5, 0.58));
}

float mapEye(vec3 pos)
{
    float lEye = sdEllipsoid(rotateYX(pos - vec3(0.3, 2.5, 0.925), vec2(0.4, 0)), vec3(0.2, 0.1, 0.04));
    float rEye = sdEllipsoid(rotateYX(pos - vec3(-0.3, 2.5, 0.925), vec2(-0.4, 0)), vec3(0.2, 0.1, 0.04));
    return min(lEye, rEye);
}

float mapArm(vec3 pos)
{
	float lArm = sdEllipsoid(rotateZ(pos - vec3(1.2, 0.6, 0), -0.15), vec3(0.2, 1.0, 0.3));
    float rArm = sdEllipsoid(rotateZ(pos - vec3(-1.2, 0.6, 0), 0.15), vec3(0.2, 1.0, 0.3));
    return min(lArm, rArm);
}

vec2 mapScene(vec3 pos) 
{ 
    vec3 c = vec3(4, 0, 6);
    pos = mod(pos, c) - 0.5 * c; //repetition
    
    float shapeIndex = 0.0;
    vec2 res = vec2(mapBody(pos), shapeIndex++);
    res = opUnion(res, vec2(mapHead(pos), shapeIndex++));
    res = opUnion(res, vec2(mapFace(pos), shapeIndex++));
    res = opUnion(res, vec2(mapEye(pos), shapeIndex++));
    res = opUnion(res, vec2(mapArm(pos), shapeIndex++));
    res = opUnion(res, vec2(sdPlane(pos - vec3(0, -1.0, 0), vec3(0, 1, 0)), shapeIndex++));
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

float shadowRayMarch(vec3 ray_origin, vec3 ray_direction) 
{
    const float HIT_DISTANCE = 0.001, MIN_TRACE_DISTANCE = 0.05, MAX_TRACE_DISTANCE = 4.5;
    
    float totalDistance = MIN_TRACE_DISTANCE; // step away from the surface
    float shadow = 1.0;
    for (int i = 0; i < 32; ++i) {
        float sd = sdScene(ray_origin + ray_direction * totalDistance);
        shadow = min(shadow, 1.0 * sd / totalDistance);
        totalDistance += clamp(sd, 0.01, 0.2);
        if (sd < HIT_DISTANCE || totalDistance > MAX_TRACE_DISTANCE) break;    
    }
    
    return clamp(shadow, 0.0, 1.0);
}

vec2 rayMarch(vec3 ray_origin, vec3 ray_direction)
{
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

float calculateAO( in vec3 pos, in vec3 normal )
{
	float occlusionSum = 0.0;
    float weight = 1.0;
    for (int i = 0; i < 5; ++i)
    {
        float hr = 0.01 + 0.15 * float(i) / 4.0;
        vec3 aoPos =  normal * hr + pos;
        float sd = sdScene(aoPos);
        occlusionSum += -(sd - hr) * weight;
        weight *= 0.95;
    }
    return pow(clamp(1.0 - occlusionSum, 0.0, 1.0), 4.0);
}

vec3 render(vec3 ray_origin, vec3 ray_direction)
{
	vec3 color = pow(texture(iChannel0, ray_direction).rgb, vec3(2.2));
    
    vec2 res = rayMarch(ray_origin, ray_direction);
    int shapeIndex = int(res.y);
    if (shapeIndex >= 0) {
        vec3 pos = ray_origin + ray_direction * res.x;
        vec3 normal = calculateNormal(pos);
		vec3 lightDir = normalize(vec3(1, 1, 1));
		float diff = max(0.0, dot(normal, lightDir));
        float ao = calculateAO(pos, normal);
        float shadow = shadowRayMarch(pos, lightDir);
		
		vec3 ambient = mix(vec3(0.07), vec3(0.05, 0.1, 0.15), normal.y * 0.5 + 0.5);
		vec3 lightCol = vec3(1.0 ,0.7, 0.6);
    
		vec3 lighting = shadow * diff * lightCol + ambient * ao;

        Material mat = shape_materials[shapeIndex];
		color = mat.albedo * lighting;
       
   		// reflection mapping
		vec3 reflection = reflect(ray_direction, normal);
		vec3 refMap = pow(texture(iChannel0, reflection).rgb, vec3(2.2));
		vec3 fresnel = mix(mat.fresnelColor, vec3(1.0 - mat.roughness), pow(dot(normal, ray_direction) + 1.0, 5.0));
		color = mix(color.rgb, refMap, fresnel);
    }
    
    return color;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) 
{
    vec3 totalColor = vec3(0.0);
    vec3 rayOrigin = vec3(0.0, 1.0, 20.0);
    
    vec2 angle = vec2(0.2 * iTime, -0.4);
	if (iMouse.z > 0.0) angle.x = (iMouse.x / iResolution.x - 0.5) * 3.14;
    rayOrigin = rotateYX(rayOrigin, angle);
    
    for (int i = 0; i < AA; ++i)
    for (int k = 0; k < AA; ++k)
    {
        vec2 offset = vec2(float(i) + .5, float(k) + .5) / float(AA) - .5;
        vec2 uv = (fragCoord + offset - iResolution.xy * 0.5) / iResolution.x;
        
      	vec3 rayDirection = normalize(vec3(uv, -1.0));
		rayDirection = rotateYX(rayDirection, angle);

   		vec3 color = render(rayOrigin, rayDirection);
        color = pow(color, vec3(0.4545));
        
        totalColor += color;
    }         
    
	totalColor /= float(AA * AA);
	fragColor = vec4(totalColor, 1.0);
}