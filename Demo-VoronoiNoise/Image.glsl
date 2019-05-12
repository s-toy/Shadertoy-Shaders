#define PI 3.1415926

vec2 hash2(vec2 p) { p=vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))); return fract(sin(p)*43758.5453); }

mat3 lookAt( in vec3 eye, in vec3 center, in vec3 up )
{
	vec3 f = normalize(center - eye);
	vec3 s = normalize(cross(f, up));
	vec3 u = cross(s, f);
    return mat3(s, u, -f);
}

float voronoiDistance( in vec2 pos )
{
	vec2 p = floor(pos), f = fract(pos);
    float u = 0.5 * (sin(iTime-0.5*PI) + 1.0);
    
	vec2 res = vec2(8.0);
	for(int i = -1; i <= 1; i ++)
	for(int k = -1; k <= 1; k ++)
	{
		vec2 b = vec2(i, k);
		vec2 r = b - f + hash2(p + b) * u;
			
		float d = dot(r, r);
        
		if(d < res.x){
            res.y = res.x; 
            res.x = d; 
        } 
        else if(d < res.y){
            res.y = d; 
        }
	}
	return res.y - res.x;
}

vec3 render( in vec3 rayOri, in vec3 rayDir )
{
    float theta = 2.0 * (acos(0.5*rayDir.x) / PI) - 1.0;
    float phi = atan(rayDir.y, rayDir.z) / PI;
    vec2 uv = vec2(theta, phi);
    
    float v = 0.0;
	for(float i = 0., a = .6, f = 8.; i < 3.; ++i, f*=2., a*=.6)
	{	
		float v1 = 1.0 - smoothstep(0.0, 0.2, voronoiDistance(uv * f));
		float v2 = 1.0 - smoothstep(0.0, 0.2, voronoiDistance(uv * f * 0.5 + iTime));
        float intensity = 0.5 * (cos(iTime) + 1.0);
		v += a * (pow(v1 * (0.5 + v2), 2.0) + v1 * intensity + 0.1);
	}
	
	vec3 c = vec3(8.0, 3.0, 2.0);
	vec3 col = vec3(pow(v, c.x), pow(v, c.y), pow(v, c.z)) * 2.0;
	
    return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 uv = (2.0*fragCoord - iResolution.xy) / iResolution.y;

    vec3 rayOri = vec3(0.0);
    vec2 mouse = (iMouse.z > 0.5) ? 5.0*(2.0*iMouse.xy/iResolution.xy-1.0) : vec2(0.0);
    vec3 rayTgt = vec3(cos(mouse.x), mouse.y, sin(mouse.x));
    
    mat3 viewMat = lookAt(rayOri, rayTgt, vec3(0.0, 1.0, 0.0));
    vec3 rayDir = normalize(viewMat * vec3(uv, -1.0));

    vec3 col = render(rayOri, rayDir);
    
	fragColor = vec4(col, 1.0);
}