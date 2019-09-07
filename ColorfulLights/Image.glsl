#define PI 3.1415927
#define LIGHT_NUM  73

struct Light
{
    vec3  pos;
    vec3  col1, col2;
    float rad1, rad2;
};

Light lights[LIGHT_NUM];

mat3 lookAt(vec3 eye, vec3 target, vec3 up) //calculate view matrix
{
    vec3 w = normalize(target - eye);
    vec3 u = normalize(cross(w, up));
    vec3 v = cross(u, w);
    return mat3(u, v, -w);
}

void rotate(inout vec2 v, float a) { v = cos(a)*v+sin(a)*vec2(-v.y,v.x); }

vec3 render(vec3 ro, vec3 rd)
{
    //init lights
    lights[0] = Light(vec3(0.0), 0.5*vec3(1.0,0.8,0.3), 8.0*vec3(1.0,0.6,0.3), 6.0, 0.8);
    for (int i = 1; i < LIGHT_NUM; ++i)
    {
        vec3 col[3] = vec3[](vec3(1.0,0.0,0.0),vec3(0.0,1.0,0.0),vec3(0.0,0.0,1.0));
        lights[i] = Light(vec3(0.0), 0.4*col[i%3], 2.0*vec3(1.0), 2.0, 0.3);
    }
    
    //update lights
    const int N = (LIGHT_NUM-1)/3;
    float an = 0.0, dt = 2.0*PI/float(N); 
    for (int i = 1; i < LIGHT_NUM; ++i)
    {
	    lights[i].pos.xy = 2.0 * vec2(sin(iTime+an),cos(iTime+an));    	
        if (i%3==0) an += dt;
    }
    
    for (int i = 0; i < N; ++i) 
    {
        rotate(lights[3*i+2].pos.yz, PI/3.0);
        rotate(lights[3*i+3].pos.yz, -PI/3.0); 
    }
    
    //draw lights
    vec3 color = vec3(0.0);
    for (int i = 0; i < LIGHT_NUM; ++i)
    {
        vec3  lv = lights[i].pos - ro;
        float an = acos(dot(rd, lv/length(lv)));
	#define T(r) (1.0-smoothstep(0.0, r, an*length(lv)))
        float w = (i == 0) ? 1.0 : 0.1;
        color += lights[i].col1 * pow(T(lights[i].rad1), 	 4.0) * w;
        color += lights[i].col1 * pow(T(lights[i].rad2*2.0), 4.0);
        color += lights[i].col2 * pow(T(lights[i].rad2), 	 4.0);
    }
    return color;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2  uv = (2.0*(fragCoord)-iResolution.xy)/iResolution.y;
    float an = PI/2.0 + 0.3 + 0.4*iTime;
    vec3  rayOri = 5.0 * vec3(sin(an), 0.0, cos(an));
    mat3  viewMat = lookAt(rayOri, vec3(0.0), vec3(0.0,1.0,0.0));
    vec3  rayDir = viewMat * normalize(vec3(uv, -1.5));
 
   	vec3 color = render(rayOri, rayDir);
    color = pow(color, vec3(0.95+0.4*sin(iTime)));
    fragColor = vec4(color, 1.0);
}