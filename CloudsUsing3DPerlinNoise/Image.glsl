#define MAX_DISTANCE 		10.0
#define NUM_OCTAVES 		4
#define HASHSCALE 			0.1031
#define PI					3.1415926

float fade(float t) 
{
    return t*t*t*(t*(6.0*t-15.0)+10.0); 
}

float hash13(vec3 pos)
{
    vec2 uv = pos.xy + pos.z;
    return texture(iChannel0, (uv+ 0.5)/256.0).x;
}

float grad3D(float hash, vec3 pos) 
{
    int h = int(1e4*hash) & 15;
	float u = h<8 ? pos.x : pos.y,
 		  v = h<4 ? pos.y : h==12||h==14 ? pos.x : pos.z;
    return ((h&1) == 0 ? u : -u) + ((h&2) == 0 ? v : -v);
}

float perlinNoise3D(vec3 pos)
{
	vec3 pi = floor(pos); 
    vec3 pf = pos - pi;
    
    float u = fade(pf.x);
    float v = fade(pf.y);
    float w = fade(pf.z);
    
    return mix( mix( mix( grad3D(hash13(pi + vec3(0, 0, 0)), pf - vec3(0, 0, 0)),
                           grad3D(hash13(pi + vec3(1, 0, 0)), pf - vec3(1, 0, 0)), u ),
            	      mix( grad3D(hash13(pi + vec3(0, 1, 0)), pf - vec3(0, 1, 0)), 
                	 	   grad3D(hash13(pi + vec3(1, 1, 0)), pf - vec3(1, 1, 0)), u ), v ),
        		 mix( mix( grad3D(hash13(pi + vec3(0, 0, 1)), pf - vec3(0, 0, 1)), 
                		   grad3D(hash13(pi + vec3(1, 0, 1)), pf - vec3(1, 0, 1)), u ),
            		  mix( grad3D(hash13(pi + vec3(0, 1, 1)), pf - vec3(0, 1, 1)), 
                		   grad3D(hash13(pi + vec3(1, 1, 1)), pf - vec3(1, 1, 1)), u ), v ), w );
}

float fbm(vec3 pos, int octaves) 
{
    float noiseSum = 0.0, frequency = 1.0, amplitude = 1.0;
    
    for(int i = 0; i < octaves; ++i) 
    {
        noiseSum += perlinNoise3D(pos * frequency) * amplitude;
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    return noiseSum;
}

mat3 lookAt(vec3 eye, vec3 center, vec3 up)
{
	vec3 f = normalize(center - eye);
	vec3 s = normalize(cross(f, up));
	vec3 u = cross(s, f);
    return mat3(s, u, -f);
}

vec3 getSkyColor(vec3 ray)
{
	vec3 color = vec3(0.0);

	//sun
    vec3 sunDir = normalize(vec3(0.0, 0.1, 1.0));
	float sundot = clamp(dot(ray, sunDir), 0.0, 1.0);
	color += 0.05 * vec3(0.9, 0.3, 0.9) * pow(sundot, 1.0);
	color += 0.1 * vec3(1.0, 0.7, 0.7) * pow(sundot, 2.0);
	color += 0.9 * vec3(1.0) * pow(sundot, 256.0);

	//sky color
	vec3 blueSky = vec3(0.3, 0.55, 0.8);
	vec3 redSky = vec3(0.8, 0.8, 0.6);
	vec3 skyColor = mix(blueSky, redSky, 1.5 * pow(sundot, 8.0));
	color += skyColor * (1.0 - 0.8 * ray.y);

	return color;
}

vec3 render(vec3 rayOrigin, vec3 rayDirection)
{
    vec3 skyColor = getSkyColor(rayDirection);
    vec3 color = skyColor;
    
    for (float dist = MAX_DISTANCE; dist > 0.0; dist -= 0.05)
    {
        vec3 position = dist * rayDirection + rayOrigin;
        position.z += iTime;
        
        float noise = 0.7 * fbm(position, NUM_OCTAVES);

        const float heightOffset = 0.2;
        float cloudSignedDistance = position.y + noise + heightOffset;
        
        if (cloudSignedDistance < 0.0) 
        {
            float cloudDensity = clamp(-cloudSignedDistance, 0.0, 1.0);
            vec3 cloudColor = vec3(1.0) - cloudDensity * skyColor.zyx;
        	color = mix(color, cloudColor, cloudDensity * 0.4);
        }
	}
    
    //contrast
	color = clamp(color, 0.0, 1.0);
	color = color * color * (3.0 - 2.0 * color);

	//saturation
	float sat = 0.2;
	color = color * (1.0 + sat) - sat * dot(color, vec3(0.33));
    
    return color;
}

void mainImage(out vec4 fragColor,vec2 fragCoord)
{
    vec2 uv = (fragCoord-0.5*iResolution.xy) / iResolution.y;
   
    vec2 angle = (iMouse.z > 0.5) ? 4.0*(2.0*iMouse.xy/iResolution.xy-1.0) : vec2(0.0);
    vec3 rayOrigin = vec3(0.0, 0.5*(sin(iTime)+1.0), 0.0);
    vec3 rayTarget = vec3(8.0*sin(angle.x), angle.y-1.0, 8.0*cos(angle.x));
    
    mat3 viewMat = lookAt(rayOrigin, rayTarget, vec3(0.0, 1.0, 0.0));
    vec3 rayDirection = normalize(viewMat * vec3(uv, -1.0));
    
   	vec3 color = render(rayOrigin, rayDirection);
    
    fragColor = vec4(color, 1.0);
}