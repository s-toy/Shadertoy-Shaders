#define PI 3.1415926

#define SIZE 				0.2
#define MAX_DEPTH 			7
#define SPLIT_ANGLE 		PI / 6.0
#define LENGTH_VARIATOPN	0.5
#define FLOWER_PROBABILITY	0.7

struct Branch
{
	vec2  pos;
    float len;
    float angle;
    float width;
    int   depth;
};

float hash11(float p)
{
    p = fract(p * .1031);
    p *= p + 19.19;
    p *= p + p;
    return fract(p);
}

float udLine(in vec2 p, in vec2 a, in vec2 b)
{
    vec2 pa = p-a, ba = b-a;
    float h = clamp(dot(pa,ba)/dot(ba,ba), 0.0, 1.0);
    return length(pa - ba*h);
}

#define V2(len, angle) vec2(len*sin(angle), len*cos(angle))
float udFlower(in vec2 p, float id)
{
    float sz = 0.003*(1.0+0.5*hash11(1436.986*id));
    float angle = PI * hash11(7491.143*id);
    float d = udLine(p, -V2(sz, angle), V2(sz, angle));
    d = min(d, udLine(p, -V2(sz, angle+PI*0.25), V2(sz, angle+PI*0.25)));
    d = min(d, udLine(p, -V2(sz, angle+PI*0.5), V2(sz, angle+PI*0.5)));
    d = min(d, udLine(p, -V2(sz, angle+PI*0.75), V2(sz, angle+PI*0.75)));
    return d;
}

vec3 render(in vec2 uv)
{
    vec3 color = vec3(0.0);
    
    Branch stack[MAX_DEPTH + 1];
    stack[0] = Branch(vec2(0.5, 0.0), SIZE, 0.0, 0.01, 0); //push
	float branchID = 0.0;
    
    for (int stackPos = 0; stackPos >= 0; branchID += 1.0) //execute loop until the stack is empty
    {
        Branch branch = stack[stackPos--]; //pop
        float prob = hash11(9375.264*branchID);
        branch.angle += 0.05*(sin(iTime)*prob);
        
        float len = branch.len * (1.0 + LENGTH_VARIATOPN * (prob-0.5));
        vec2 start = branch.pos;
        vec2 end = start + vec2(len*sin(branch.angle), len*cos(branch.angle));
        float ud =  udLine(uv, start, end);
        
        color += vec3(1.0 - smoothstep(0.0, branch.width, ud));
        
        if (branch.depth < MAX_DEPTH)
        {
            float len = branch.len * (0.67);
        	float width = max(0.001, branch.width * 0.7);
        	stack[++stackPos] = Branch(end, len, branch.angle+SPLIT_ANGLE, width, branch.depth+1); //push
        	stack[++stackPos] = Branch(end, len, branch.angle-SPLIT_ANGLE, width, branch.depth+1); //push
        }
        
        if (branch.depth == MAX_DEPTH)
        {
            float ud = udFlower(uv - end, branchID);
            if (ud < 0.001 && prob < FLOWER_PROBABILITY)
        		color = vec3(1.0, 0.7, 0.8) * (1.0 - smoothstep(0.0, 0.001, ud));
        }
    }
 	
    return color;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    fragColor = vec4(render(fragCoord/iResolution.x), 1.0);
}