#define PI 3.1415927

struct Light
{
    vec3  pos;
    vec3  col1, col2;
    float rad1, rad2;
    mat3  rotMat;
};

Light lights[4];

mat3 lookAt(vec3 eye, vec3 target, vec3 up)
{
    vec3 w = normalize(target - eye);
    vec3 u = normalize(cross(w, up));
    vec3 v = cross(u, w);
    return mat3(u, v, -w);
}

mat3 rotate(vec3 axis, float angle)
{
    axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;
    
    return mat3(oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,
                oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,
                oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c          );
}

float sdCappedCylinder(vec3 p, float h, float r)
{
  vec2 d = abs(vec2(length(p.xz),p.y)) - vec2(r,h);
  return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

float sdRing(vec3 p, float r1, float r2)
{
    vec2 v = vec2(abs(length(p.xy)-r1), p.z);
    return length(v)-r2;
}

float smin(float a, float b, float k)
{
    float d = max(k-abs(a-b), 0.0);
    return min(a,b) - d*d/k/4.0;
}

vec2 sincos(float t) { return vec2(sin(t), cos(t));}

vec2 mapScene(vec3 p)
{
    float objID = 1.0;

    //rings
    float d = sdRing(p, 1.0, 0.03);
    d = smin(d, sdRing(lights[2].rotMat*p, 1.0, 0.03), 0.02);
    d = smin(d, sdRing(lights[3].rotMat*p, 1.0, 0.03), 0.02);
    
    vec3 p2 = p-vec3(0.0,-1.9,0.0);
    float h = 1.0;
    float x = (1.0-clamp((p2.y+h)/(2.0*h), 0.0, 1.0));
    float r = 0.05*(15.0*pow(x,6.0)+1.0);

    //body
    float d2 = sdCappedCylinder(p2, h, r);
    d2 = smin(d2, length(p2-vec3(0.0,1.0,0.0))-0.1, 0.05);
    vec3 p3 = p2-vec3(0.0,0.0,0.0); p3.y *= 2.0;
    d2 = smin(d2, length(p3)-0.18, 0.2);
    p3= p2-vec3(0.0,-0.3,0.0); p3.y *= 2.0;
    d2 = smin(d2, length(p3)-0.2, 0.2);
    
    d2 = smin(d2, sdCappedCylinder(p3-vec3(0.0,2.0,0.0), 0.06, 0.4), 0.2);
    d2 = smin(d2, sdCappedCylinder(p3-vec3(0.0,1.75,0.0), 0.06, 0.6), 0.2);
    d2 = smin(d2, sdCappedCylinder(p3-vec3(0.0,1.5,0.0), 0.1, 0.5), 0.2);
    if (d2 < d) objID = 2.0;
    d = min(d, d2);
    
    return vec2(d, objID);
}

vec3 calculateNormal(vec3 p)
{
    vec3 dt = vec3(0.01, 0.0, 0.0);
    return normalize( vec3(	mapScene(p+dt.xyy).x-mapScene(p-dt.xyy).x,
                         	mapScene(p+dt.yxy).x-mapScene(p-dt.yxy).x,
                          	mapScene(p+dt.yyx).x-mapScene(p-dt.yyx).x ) );
}

float calculateAO(vec3 pos, vec3 normal)  //ambient occlusion
{
    float ao = 0.0, sca = 1.0;
    for (int i = 0; i < 5; ++i)
    {
   		float h = 0.01 + 0.11*float(i)/4.0;
        vec3 p = pos + h * normal;
        float d = mapScene(p).x;
        ao += (h-d)*sca;
        sca *= 0.95;
    }
    
    return pow(clamp(1.0-2.0*ao, 0.0, 1.0), 2.0);
}

vec3 noise(vec3 pos, vec3 nor)
{
	vec3 x = texture(iChannel0, pos.yz).xyz;
	vec3 y = texture(iChannel0, pos.zx).xyz;
	vec3 z = texture(iChannel0, pos.xy).xyz;
	return x*abs(nor.x) + y*abs(nor.y) + z*abs(nor.z);
}

vec3 hash31(float p)
{
   vec3 p3 = fract(vec3(p) * vec3(.1031, .1030, .0973));
   p3 += dot(p3, p3.yzx+33.33);
   return fract((p3.xxy+p3.yzz)*p3.zyx); 
}

vec3 background(vec3 ro, vec3 rd)
{
    vec3 color = vec3(0.0);
    for (int i = 0; i < 64; ++i)
    {
        vec3 noise = hash31(float(i)*215.4);
        vec3 lv = (10.0*noise-5.0) - ro;
        float ll = length(lv);
        float angle = acos(clamp(dot(rd, lv/ll), 0.0, 1.0));
        float t = (1.0-smoothstep(0.0, 1.5 + 1.0*noise.x, angle*ll));
        color += 0.05 * (0.6*noise+vec3(0.1)) *pow(t, 4.0); 	
    }
    return color;
}

vec3 render(vec3 ro, vec3 rd)
{
    //init lights
    float st = 0.8 + 0.1*sin(5.0*iTime);
    lights[0] = Light(vec3(0.0), 0.5*vec3(0.5,1.0,1.0), 8.0*vec3(0.5,1.0,1.0), 4.0*st, 0.8*st, mat3(0.0));
    lights[1] = Light(vec3(0.0), 0.5*vec3(1.0,0.0,0.0), 2.0*vec3(1.0), 		   0.8*st, 0.4, mat3(0.0));
    lights[2] = Light(vec3(0.0), 0.5*vec3(0.0,1.0,0.0), 2.0*vec3(1.0), 		   0.8*st, 0.4, mat3(0.0));
    lights[3] = Light(vec3(0.0), 0.5*vec3(0.0,0.0,1.0), 2.0*vec3(1.0), 		   0.8*st, 0.4, mat3(0.0));
    
    //update lights
    float t = iTime-0.5;
	lights[1].pos = vec3(sincos(t), 0.0);	    	
    lights[2].rotMat = rotate(vec3(1.0,0.2,0.0), PI/3.0);
    lights[2].pos = vec3(sincos(t-PI/1.5), 0.0) * lights[2].rotMat;
    lights[3].rotMat = rotate(vec3(1.0,-0.2,0.0), -PI/3.0);
    lights[3].pos = vec3(sincos(-t-PI/0.75), 0.0) * lights[3].rotMat;
    
  	vec3 color = background(ro, rd);
    //ray marching
    float tmin = 0.1, tmax = 8.0;
    vec2 res;
    for (float t = tmin; t < tmax;)
    {
        vec3 pos = ro + t * rd;
        res = mapScene(pos);
        float dist = res.x;
        
        if (dist < 0.05)
        {
            vec3 nor = calculateNormal(pos);
            float ao = calculateAO(pos, nor);
            
            vec3 albedo = vec3(0.0);
            if (res.y < 1.5)
            {
            	albedo = vec3(5.0);
            }
            else if (res.y < 2.5)
            {
                albedo = vec3(1.0);
                float w = 0.5 + 0.5*sin(iTime);
            	nor = normalize(nor + 0.5*w*(noise(w*pos, nor)-0.5)); //alter normal
            }
                
            if (dist < 0.02)
            {
            	for (int i = 0; i < 4; ++i) //apply lights
            	{
                	vec3  l = lights[i].pos - pos;
                    float d = length(l);
                    float attenuation = 1.0 / (0.2*d*d+0.5*d+1.0);
                    float diffuse = max(0.0,dot(normalize(l),nor));
                    float sepcular = pow(max(dot(normalize(reflect(l,nor)),rd),0.0), 16.0);

                    vec3 col = 0.01*albedo * lights[i].col2 * diffuse;
                    col += 4.0*sepcular*lights[i].col1;
                    col *= attenuation * pow(ao,4.0);
                    color += 0.07 * col;
                }
            }

            color += 0.002*vec3(0.0,1.0,0.9)*pow(1.0-smoothstep(0.0, 0.1, dist), 1.0);
        }
        
        t += max(0.005, (dist-0.1)*0.5);
    }
    
    for (int i = 0; i < 4; ++i) //draw lights
    {
        vec3 lv = lights[i].pos - ro;
        float ll = length(lv);
        float angle = acos(clamp(dot(rd, lv/ll), 0.0, 1.0));
        float t = (1.0-smoothstep(0.0, lights[i].rad1, angle*ll));
        color += lights[i].col1*pow(t, 4.0);
        t = (1.0-smoothstep(0.0, lights[i].rad2, angle*ll));
        color += lights[i].col2*pow(t, 4.0);
    }
    
    return color;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2  uv = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    float an = PI/2.0 + 0.4*iTime;
    
    vec3  rayOri = 4.0 * vec3(sin(an), 0.1, cos(an));
    mat3  viewMat = lookAt(rayOri, vec3(0.0,-1.0,0.0), vec3(0.0,1.0,0.0));
    vec3  rayDir = viewMat * normalize(vec3(uv, -1.5));	//rotate camera
    
    vec3 color = render(rayOri, rayDir);
    
    //gamma correction
    color = pow(color, vec3(0.4545)); 
    
    //contrast
	color = clamp(color, 0.0, 1.0);
	color = color * color * (3.0 - 2.0 * color);

	//saturation
	float sat = 0.2;
	color = color * (1.0 + sat) - sat * dot(color, vec3(0.33));
    
    fragColor = vec4(color, 1.0);
}