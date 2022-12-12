#version 430

layout(local_size_x = 1, local_size_y = 1) in;
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
uniform float seed;
uniform mat4 rotMat;
uniform samplerCube skybox;
layout(rgba32f, binding = 0) uniform image2D img_output;
layout(std140, binding = 0) uniform MESH_IN
{
	vec3 verts[1000];
} vertices;
vec4 pix;

struct Ray
{
	vec3 dir;
    vec3 nrg;
    vec3 org;
};

struct RayHit
{
    float dist;
	float smoothness;
	bool skybox;
    vec3 albedo;
	vec3 emission;
	vec3 norm;
	vec3 pos;
    vec3 specular;	
};

RayHit CreateRayHit()
{
    RayHit hit;
    hit.dist = -1;
	hit.smoothness = 0.0f;
	hit.skybox = false;    
    hit.albedo = vec3(0.0f, 0.0f, 0.0f);
	hit.emission = vec3(0, 0, 0);
	hit.norm = vec3(0.0f, 0.0f, 0.0f);
    hit.pos = vec3(0.0f, 0.0f, 0.0f);
    hit.specular = vec3(0.0f, 0.0f, 0.0f);	
    return hit;
}

struct Sphere
{
    vec3 pos;
    float rad;
    vec3 albedo;
    vec3 specular;
	float smoothness;
	vec3 emission;
};

float internalSeed = seed;
/* Generating random float between [ 0.0, 1.0 ) with almost uniform probability distribution */
float rand()
{
    float rslt = fract(sin(internalSeed/100.0f * dot(pix.xy, vec2(12.9898f, 78.233f))) * 43758.5453f);
	internalSeed += 1.0f;
	return rslt;
}

/* Utility function to dot two vectors and clamp them between 0 and 1 */
float sdot(vec3 x, vec3 y, float f)
{
    return clamp(dot(x, y)*f, 0.0, 1.0);
}
 
/* Utility function to average the 3 colour channels */
float nrg(vec3 colour)
{
    return dot(colour, vec3(1.0f/3.0f));
}

/* Converting a smoothness value to alpha for the scattering distribution */
float SmoothnessToPhongAlpha(float s)
{
    return pow(1000.0f, s*s);
}

/* Finding the tangent space given a normal */
mat3 GetTangentSpace(vec3 norm)
{
    vec3 helper = vec3(1, 0, 0);
    if (abs(norm.x) > 0.99f)
        helper = vec3(0, 0, 1);    
    vec3 tangent = normalize(cross(norm, helper));
    vec3 binorm = normalize(cross(norm, tangent)); 
    return mat3(tangent, binorm, norm);
}

/* Sampling the hemisphere around the given normal and biases it based on the given alpha */
vec3 SampleHemi(vec3 norm, float alpha)
{
    float cosTheta = pow(rand(), 1.0f/(alpha + 1.0f));
    float sinTheta = sqrt(max(0.0f, 1.0f - cosTheta*cosTheta));
    float phi = 2 * 3.141593f * rand();
    vec3 tangentSpaceDir = vec3(cos(phi)*sinTheta, sin(phi)*sinTheta, cosTheta);
    return GetTangentSpace(norm)*tangentSpaceDir;
}

bool intersectTriangle_MT97(Ray ray, vec3 vert0, vec3 vert1, vec3 vert2, inout float t, inout float u, inout float v)
{
    vec3 edge1 = vert1 - vert0, edge2 = vert2 - vert0;
    vec3 pvec = cross(ray.dir, edge2);
    float det = dot(edge1, pvec);
    if (det < 0.001f)
        return false;
    float invDet = 1.0f/det;
    vec3 tvec = ray.org - vert0;
    u = dot(tvec, pvec)*invDet;
    if (u < 0.0 || u > 1.0f)
        return false;
    vec3 qvec = cross(tvec, edge1);
    v = dot(ray.dir, qvec)*invDet;
    if (v < 0.0 || (u + v) > 1.0f)
        return false;
    t = dot(edge2, qvec)*invDet;
    return true;
}

void intersectRoom(Ray ray, inout RayHit bestHit)
{
	float halfLen = 10000, nearestDist = 10000000.0, denom;
	bool testBack = true, testDown = true, testLeft = true;
	vec3 nearest, norm, pPt, pNorm;

	/* Front face */
	pPt = vec3(0.0, 0.0, -halfLen), pNorm = vec3(0.0, 0.0, 1.0);
	denom = dot(pNorm, ray.dir);
	if (abs(denom) > 0.0001f) // epsilon val can be changed
	{
		float t = dot(pPt - ray.org, pNorm)/denom;
		if (t > 0.0001f) 
		{
			testDown = false;
			nearest = ray.org + t*ray.dir;
			nearestDist = t;
			norm = pNorm;
		}
	}
	else testBack = false;

	/* Back face */
	if (testBack)
	{
		pPt = vec3(0.0, 0.0, halfLen), pNorm = vec3(0.0, 0.0, -1.0);
		denom = dot(pNorm, ray.dir);
		if (abs(denom) > 0.0001f) // epsilon val can be changed
		{
			float t = dot(pPt - ray.org, pNorm)/denom;
			if (t > 0.0001f) 
			{
				float dist = t;
				if (dist < nearestDist)
				{
					nearest = ray.org + t*ray.dir;
					nearestDist = dist;
					norm = pNorm;
				}
			}
		}
	}

	/* Up face */
	pPt = vec3(0.0, halfLen, 0.0), pNorm = vec3(0.0, -1.0, 0.0);
	denom = dot(pNorm, ray.dir);
	if (abs(denom) > 0.0001f) // epsilon val can be changed
	{
		float t = dot(pPt - ray.org, pNorm)/denom;
		if (t > 0.0001f) 
		{
			testDown = false;
			float dist = t;
			if (dist < nearestDist)
			{
				nearest = ray.org + t*ray.dir;
				nearestDist = dist;
				norm = pNorm;
			}
		}
	}
	else testDown = false;

	/* Down face */
	if (testDown)
	{
		pPt = vec3(0.0, -halfLen, 0.0), pNorm = vec3(0.0, 1.0, 0.0);
		denom = dot(pNorm, ray.dir);
		if (abs(denom) > 0.0001f) // epsilon val can be changed
		{
			float t = dot(pPt - ray.org, pNorm)/denom;
			if (t > 0.0001f) 
			{
				float dist = t;
				if (dist < nearestDist)
				{
					nearest = ray.org + t*ray.dir;
					nearestDist = dist;
					norm = pNorm;
				}
			}
		}
	}

	/* Right face */
	pPt = vec3(halfLen, 0.0, 0.0), pNorm = vec3(-1.0, 0.0, 0.0);
	denom = dot(pNorm, ray.dir);
	if (abs(denom) > 0.0001f) // epsilon val can be changed
	{
		float t = dot(pPt - ray.org, pNorm)/denom;
		if (t > 0.0001f) 
		{
			testLeft = false;
			float dist = t;
			if (dist < nearestDist)
			{
				nearest = ray.org + t*ray.dir;
				nearestDist = dist;
				norm = pNorm;
			}
		}
	}
	else testLeft = false;

	/* Left face */
	if (testLeft)
	{
		pPt = vec3(-halfLen, 0.0, 0.0), pNorm = vec3(1.0, 0.0, 0.0);
		denom = dot(pNorm, ray.dir);
		if (abs(denom) > 0.0001f) // epsilon val can be changed
		{
			float t = dot(pPt - ray.org, pNorm)/denom;
			if (t > 0.0001f) 
			{
				float dist = t;
				if (dist < nearestDist)
				{
					nearest = ray.org + t*ray.dir;
					nearestDist = dist;
					norm = pNorm;
				}
			}
		}
	}

	if (nearestDist < bestHit.dist || bestHit.dist == -1)
	{
		bestHit.dist = nearestDist;
		bestHit.smoothness = 0.0;
		bestHit.skybox = true;		
		bestHit.albedo = vec3(texture(skybox, normalize(nearest)).xyz);
		bestHit.emission = vec3(0.25);
		bestHit.norm = norm;
		bestHit.pos = ray.org + nearestDist*ray.dir;
		bestHit.specular = vec3(0.0);		
	}
}

/* Function returning the colour of the pixel in the background intersected by a ray */
vec3 drawBackground(vec3 rOrg, vec3 rDir)
{
	float halfLen = 10000, nearestDist = 10000000.0, denom;
	bool testBack = true, testDown = true, testLeft = true;
	vec3 nearest, pPt, pNorm;

	/* Front face */
	pPt = vec3(0.0, 0.0, -halfLen), pNorm = vec3(0.0, 0.0, 1.0);
	denom = dot(pNorm, rDir);
	if (abs(denom) > 0.0001f) // epsilon val can be changed
	{
		float t = dot(pPt - rOrg, pNorm)/denom;
		if (t > 0.0001f) 
		{
			testBack = false;
			nearest = rOrg + t*rDir;
			nearestDist = length(t*rDir);
		}
	}
	else testBack = false;

	/* Back face */
	if (testBack)
	{
		pPt = vec3(0.0, 0.0, halfLen), pNorm = vec3(0.0, 0.0, -1.0);
		denom = dot(pNorm, rDir);
		if (abs(denom) > 0.0001f) // epsilon val can be changed
		{
			float t = dot(pPt - rOrg, pNorm)/denom;
			if (t > 0.0001f) 
			{
				float dist = length(t*rDir);
				if (dist < nearestDist)
				{
					nearest = rOrg + t*rDir;
					nearestDist = dist;
				}
			}
		}
	}

	/* Up face */
	pPt = vec3(0.0, halfLen, 0.0), pNorm = vec3(0.0, -1.0, 0.0);
	denom = dot(pNorm, rDir);
	if (abs(denom) > 0.0001f) // epsilon val can be changed
	{
		float t = dot(pPt - rOrg, pNorm)/denom;
		if (t > 0.0001f) 
		{
			testDown = false;
			float dist = length(t*rDir);
			if (dist < nearestDist)
			{
				nearest = rOrg + t*rDir;
				nearestDist = dist;
			}
		}
	}
	else testDown = false;

	/* Down face */
	if (testDown)
	{
		pPt = vec3(0.0, -halfLen, 0.0), pNorm = vec3(0.0, 1.0, 0.0);
		denom = dot(pNorm, rDir);
		if (abs(denom) > 0.0001f) // epsilon val can be changed
		{
			float t = dot(pPt - rOrg, pNorm)/denom;
			if (t > 0.0001f) 
			{
				float dist = length(t*rDir);
				if (dist < nearestDist)
				{
					nearest = rOrg + t*rDir;
					nearestDist = dist;
				}
			}
		}
	}

	/* Right face */
	pPt = vec3(halfLen, 0.0, 0.0), pNorm = vec3(-1.0, 0.0, 0.0);
	denom = dot(pNorm, rDir);
	if (abs(denom) > 0.0001f) // epsilon val can be changed
	{
		float t = dot(pPt - rOrg, pNorm)/denom;
		if (t > 0.0001f) 
		{
			testLeft = false;
			float dist = length(t*rDir);
			if (dist < nearestDist)
			{
				nearest = rOrg + t*rDir;
				nearestDist = dist;
			}
		}
	}
	else testLeft = false;

	/* Left face */
	if (testLeft)
	{
		pPt = vec3(-halfLen, 0.0, 0.0), pNorm = vec3(1.0, 0.0, 0.0);
		denom = dot(pNorm, rDir);
		if (abs(denom) > 0.0001f) // epsilon val can be changed
		{
			float t = dot(pPt - rOrg, pNorm)/denom;
			if (t > 0.0001f) 
			{
				float dist = length(t*rDir);
				if (dist < nearestDist)
				{
					nearest = rOrg + t*rDir;
					nearestDist = dist;
				}
			}
		}
	}

	return vec3(texture(skybox, normalize(nearest)).xyz);
}

/* Testing the intersection of a ray and the ground plane and modifying the previous best hit if the ground is visible to that ray */
void intersectGroundPlane(Ray ray, inout RayHit bestHit)
{
	float t = (- ray.org.y - 17.0f)/ray.dir.y;
	if (t > 0.1f && (t < bestHit.dist || bestHit.dist == -1))
	{
		bestHit.dist = t;
		bestHit.pos = ray.org + t*ray.dir;
		bestHit.norm = vec3(0.0, 1.0, 0.0);
		bestHit.albedo = vec3(1.0);
		bestHit.specular = vec3(1.0);
		bestHit.emission = vec3(0.0, 0.0, 0.0);
		bestHit.smoothness = 0.6;
		bestHit.skybox = false;
	}
}

/* Testing the intersection of a ray and a sphere and modifying the previous best hit if the ground is visible to that ray */
void intersectSphere(Ray ray, inout RayHit bestHit, Sphere sphere)
{
	vec3 d = ray.org - sphere.pos;
	float p1 = -dot(ray.dir, d), p2sqr = p1*p1 - dot(d, d) + sphere.rad*sphere.rad;
    if (p2sqr < 0)
        return;
    float p2 = sqrt(p2sqr);
    float t = (p1 - p2) > 0 ? (p1 - p2) : (p1 + p2);
    if (t > 0.1f && (t < bestHit.dist || bestHit.dist == -1))
    {
        bestHit.dist = t;
        bestHit.pos = ray.org + t*ray.dir;
        bestHit.norm = normalize(bestHit.pos - sphere.pos);
        bestHit.albedo = sphere.albedo;
        bestHit.specular = sphere.specular;
		bestHit.emission = sphere.emission;
		bestHit.smoothness = sphere.smoothness;
		bestHit.skybox = false;
    }
}

/* Driver tracing function to loop through all the objects in the scene and test interection */
RayHit Trace(Ray ray)
{
	RayHit bestHit = CreateRayHit();
	intersectRoom(ray, bestHit);
	intersectGroundPlane(ray, bestHit);
	intersectSphere(ray, bestHit, Sphere(vec3(-17.0f, -9.0, -62.0f), 7.0, vec3(0.0), vec3(1.0, 0.78f, 0.34f), 1.0, vec3(1.0)));
	intersectSphere(ray, bestHit, Sphere(vec3(-15.0f, -12.6, -30.0f), 4.0, vec3(0.0), vec3(1.0, 1.0f, 1.0f), 1.2, vec3(0.0)));
	intersectSphere(ray, bestHit, Sphere(vec3(-5.0f, -13.0, -45.0f), 3.0, vec3(1.0, 1.0, 1.0), vec3(1.0), 0.8, vec3(0.0, 10.0, 10.0)));
	intersectSphere(ray, bestHit, Sphere(vec3(-3.0f, -9.6, -75.0f), 7.0, vec3(0.0, 0.0, 0.0), vec3(1.0, 0.35, 0.45), 0.1, vec3(0.0)));
	intersectSphere(ray, bestHit, Sphere(vec3(1.0f, -14.6, -62.0f), 2.0, vec3(0.0, 0.0, 0.0), vec3(1.0, 1.0, 1.0), 0.0, vec3(0.0)));
	intersectSphere(ray, bestHit, Sphere(vec3(8.0f, -11.0, -50.0f), 5.0, vec3(0.0, 0.0, 0.0), vec3(1.0, 1.0, 0.0), 0.8, vec3(1.0)));
	
	vec3 v0 = vec3(-10, -17, -55), v1 = vec3(0, -17, -55), v2 = vec3(-5, -6, -55);
	float t, u, v;
	if (intersectTriangle_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = vec3(0.0f);
			bestHit.specular = 0.65f*vec3(1, 0.4f, 0.2f);
			bestHit.smoothness = 0.9f;
			bestHit.emission = vec3(0.0f);
		}
	}
 
    return bestHit;
}

/* Driver colouring function to colours pixels based on hit properties, and then modify the ray to denote the new reflection dir */
vec3 Shade(inout Ray ray, RayHit hit)
{
	if (hit.dist > 0.01f)
	{
		if (hit.skybox)
		{
			ray.nrg *= hit.albedo;
			return hit.emission;
		}
		hit.albedo = min(1.0f - hit.specular, hit.albedo);
		float specProb = nrg(hit.specular), diffProb = nrg(hit.albedo), roulette = rand();
		float sum = specProb + diffProb;
		specProb /= sum;
		diffProb /= sum;
		if (roulette < specProb)
		{
			/* Diffuse reflection */
			ray.org = hit.pos + hit.norm*0.001f;
			float alpha = SmoothnessToPhongAlpha(hit.smoothness);
			ray.dir = SampleHemi(reflect(ray.dir, hit.norm), alpha);
			float f = (alpha + 2)/(alpha + 1);
			ray.nrg *= (1.0f/specProb) * hit.specular * sdot(hit.norm, ray.dir, f);
		}
		else
		{
			/* Specular reflection */
			ray.org = hit.pos + hit.norm*0.001f;
			ray.dir = SampleHemi(hit.norm, 1.0f);
			ray.nrg *= (1.0f/diffProb) * hit.albedo;
		}
		return hit.emission; 
	}
	else
	{
		ray.nrg = vec3(0.0f);
		return vec3(0.0, 0.0, 0.0);
	}
}

/* Function to loop through all pixels and fill them with a colour */
void main()
{
	int numHits = 5;
	ivec2 pixCoords = ivec2(gl_GlobalInvocationID.xy), dims = imageSize(img_output);
	float maxx = 5.0, maxy = 5.0, x = float(pixCoords.x*2 - dims.x)/dims.x, y = float(pixCoords.y*2 - dims.y)/dims.y;
	pix = vec4(pixCoords.x, pixCoords.y, 0.0, 1.0);
	Ray ray;
	ray.org = vec3(0.0, 0.0, 10.0);
	vec4 initial = vec4(normalize(vec3(x*maxx, y*maxy, 0.0) - ray.org).xyzz);
	ray.dir = vec3((rotMat * initial).xyz);
	ray.nrg = vec3(1.0f);
	vec3 rslt = vec3(0.0, 0.0, 0.0);
	for (int i = 1; i <= numHits; i++)
	{
        RayHit hit = Trace(ray);
        rslt += ray.nrg*Shade(ray,hit);    
        if (ray.nrg.x == 0.0 && ray.nrg.y == 0.0 && ray.nrg.y == 0.0)
			break;
    }
	pix = vec4(rslt, 1.0);	
	imageStore(img_output, pixCoords, pix);
}