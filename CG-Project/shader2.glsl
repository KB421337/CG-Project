#version 430

layout(local_size_x = 1, local_size_y = 1) in;
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
uniform int xOrg;
uniform int yOrg;
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

struct Path
{
	int pathLen;
	Ray rays[10];
	RayHit rayhits[10];
	vec3 results[10];
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

struct Sph
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

/* Finding the tgn space given a normal */
mat3 GetTgnSpace(vec3 norm)
{
    vec3 helper = vec3(1, 0, 0);
    if (abs(norm.x) > 0.99f)
        helper = vec3(0, 0, 1);    
    vec3 tgn = normalize(cross(norm, helper));
    vec3 binorm = normalize(cross(norm, tgn)); 

    return mat3(tgn, binorm, norm);
}

/* Sampling the hemisph around the given normal and biases it based on the given alpha */
vec3 SampleHemi(vec3 norm, float alpha)
{
    float cosTheta = pow(rand(), 1.0f/(alpha + 1.0f));
    float sinTheta = sqrt(max(0.0f, 1.0f - cosTheta*cosTheta));
    float phi = 2 * 3.141593f * rand();
    vec3 tgnSpaceDir = vec3(cos(phi)*sinTheta, sin(phi)*sinTheta, cosTheta);
    return GetTgnSpace(norm)*tgnSpaceDir;
}

bool intersectTgl_MT97(Ray ray, vec3 vert0, vec3 vert1, vec3 vert2, inout float t, inout float u, inout float v)
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
		if (abs(denom) > 0.0001f) 
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
	if (abs(denom) > 0.0001f) 
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
		if (abs(denom) > 0.0001f) 
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
	if (abs(denom) > 0.0001f) 
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
		if (abs(denom) > 0.0001f) 
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
	if (abs(denom) > 0.0001f) 
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
		if (abs(denom) > 0.0001f) 
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
	if (abs(denom) > 0.0001f) 
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
		if (abs(denom) > 0.0001f) 
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
	if (abs(denom) > 0.0001f) 
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
		if (abs(denom) > 0.0001f) 
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
		bestHit.smoothness = 1;
		bestHit.skybox = false;
	}
}

/* Testing the intersection of a ray and a sph and modifying the previous best hit if the ground is visible to that ray */
void intersectSph(Ray ray, inout RayHit bestHit, Sph sph)
{
	vec3 d = ray.org - sph.pos;
	float p1 = -dot(ray.dir, d), p2sqr = p1*p1 - dot(d, d) + sph.rad*sph.rad;
    if (p2sqr < 0)
        return;
    float p2 = sqrt(p2sqr);
    float t = (p1 - p2) > 0 ? (p1 - p2) : (p1 + p2);
    if (t > 0.1f && (t < bestHit.dist || bestHit.dist == -1))
    {
        bestHit.dist = t;
        bestHit.pos = ray.org + t*ray.dir;
        bestHit.norm = normalize(bestHit.pos - sph.pos);
        bestHit.albedo = sph.albedo;
        bestHit.specular = sph.specular;
		bestHit.emission = sph.emission;
		bestHit.smoothness = sph.smoothness;
		bestHit.skybox = false;
    }
}

/* Driver tracing function to loop through all the objects in the scene and test interection */
RayHit Trace(Ray ray)
{
	RayHit bestHit = CreateRayHit();
	intersectRoom(ray, bestHit);
	intersectGroundPlane(ray, bestHit);
	//intersectSph(ray, bestHit, Sph(vec3(-17.0f, -9.0, -62.0f), 7.0, vec3(0.0), vec3(1.0, 0.78f, 0.34f), 1.0, vec3(1.0)));
	intersectSph(ray, bestHit, Sph(vec3(-15.0f, -12.6, -30.0f), 4.0, vec3(0.0), vec3(1.0, 1.0f, 1.0f), 1.2, vec3(0.0)));
	intersectSph(ray, bestHit, Sph(vec3(17.0f, -7.0, -45.0f), 3.0, vec3(1.0, 1.0, 1.0), vec3(1.0), 0.8, vec3(0.0, 10.0, 10.0)));
	intersectSph(ray, bestHit, Sph(vec3(-3.0f, -9.6, -75.0f), 7.0, vec3(0.0, 0.0, 0.0), vec3(1.0, 0.35, 0.45), 0.1, vec3(0.0)));
	intersectSph(ray, bestHit, Sph(vec3(1.0f, -14.6, -62.0f), 2.0, vec3(0.0, 0.0, 0.0), vec3(1.0, 1.0, 1.0), 0.0, vec3(0.0)));
	//intersectSph(ray, bestHit, Sph(vec3(8.0f, -11.0, -50.0f), 5.0, vec3(0.0, 0.0, 0.0), vec3(1.0, 1.0, 0.0), 0.8, vec3(1.0)));
	
	vec3 wallEmission = vec3(0);
	vec3 wallSpecular = vec3(0);
	vec3 wallAlbedo = vec3(1);
	float wallSmoothness = 1;

	vec3 v0 = vec3(-40, -17, -65);
	vec3 v1 = vec3(15, -17, -65);
	vec3 v2 = vec3(-40, 6, -65);
	float t, u, v;
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;//0.65f*vec3(1, 0.4f, 0.2f);
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
		}
	}

	v0 = vec3(-40, 6, -65);
	v1 = vec3(15, -17, -65);
	v2 = vec3(15, 6, -65);
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;//0.65f*vec3(1, 0.4f, 0.2f);
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
		}
	}

	v0 = vec3(-30, 6, -65);
	v1 = vec3(-25, 6, 35);
	v2 = vec3(-25, -17, 35);
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;//0.65f*vec3(1, 0.4f, 0.2f);
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
		}
	}

	v0 = vec3(-30, 6, -65);
	v1 = vec3(-25, -17, 35);
	v2 = vec3(-30, -17, -65);
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;//0.65f*vec3(1, 0.4f, 0.2f);
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
		}
	}

	v0 = vec3(-25, 6, 15);
	v1 = vec3(15, -17, 15);
	v2 = vec3(-25, -17, 15);
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;//0.65f*vec3(1, 0.4f, 0.2f);
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
		}
	}

	v0 = vec3(-25, 6, 15);
	v1 = vec3(15, 6, 15);
	v2 = vec3(15, -17, 15);
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;//0.65f*vec3(1, 0.4f, 0.2f);
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
		}
	}

	v0 = vec3(15, 6, 15);
	v1 = vec3(15, 6, -35);
	v2 = vec3(15, -17, -35);
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;//0.65f*vec3(1, 0.4f, 0.2f);
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
		}
	}

	v0 = vec3(15, 6, 15);
	v1 = vec3(15, -17, -35);
	v2 = vec3(15, -17, 15);
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;//0.65f*vec3(1, 0.4f, 0.2f);
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
		}
	}

	v0 = vec3(15, 6, -65);
	v1 = vec3(10, -17, -30);
	v2 = vec3(15, -17, -65);
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;//0.65f*vec3(1, 0.4f, 0.2f);
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
		}
	}

	v2 = vec3(15, 6, -65);
	v1 = vec3(10, -17, -30);
	v0 = vec3(15, -17, -65);
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;//0.65f*vec3(1, 0.4f, 0.2f);
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
		}
	}

	v2 = vec3(15, 6, -65);
	v1 = vec3(10, 6, -30);
	v0 = vec3(10, -17, -30);
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;//0.65f*vec3(1, 0.4f, 0.2f);
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
		}
	}

	v0 = vec3(15, 6, -65);
	v1 = vec3(10, 6, -30);
	v2 = vec3(10, -17, -30);
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;//0.65f*vec3(1, 0.4f, 0.2f);
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
		}
	}

	v0 = vec3(-40, 6, 20);
	v1 = vec3(-40, 6, -65);
	v2 = vec3(15, 6, -65);
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;//0.65f*vec3(1, 0.4f, 0.2f);
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
		}
	}

	v0 = vec3(15, 6, 15);
	v1 = vec3(-40, 6, 15);
	v2 = vec3(15, 6, -65);
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;//0.65f*vec3(1, 0.4f, 0.2f);
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
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

/*
float pd(int xl,  int ld) 
{
	if (ld >= 4 || ld <= 0)
		return 0;

	if (ld != 2)
		return 0.25;

	return 0.5;
}*/

int getLd(int xl)
{
	if (xl < 3)
		return 0;
	float d = rand();
	if (d <= 0.25)
		return 1;
	if (d <= 0.75)
		return 2;
	return int(floor( 3 - log2( 1 - 4 * (d - 0.75 )) ));
}

struct PathNode
{
	RayHit hit;
	Ray ray;
	vec3 result;
	int nextA;
	int nextM;
};

#define NUM_HITS 10
#define SAMPLES 10
#define MUTATIONS 0

// 10, 100, 0 converges after 50 frames. Took 7 minutes

PathNode nodePool[NUM_HITS*(MUTATIONS + SAMPLES) + 1];

int size = 0;
int newPathNode()
{
	int oldSize = size;
	size++;
	return oldSize;
}


/* Assuming tentative transition function is symmetric. */

int mutations = MUTATIONS;
int numHits = NUM_HITS;

float luminance(vec3 color)
{
	return 0.299 * color.x + 0.587 * color.y + 0.114 * color.z;
}

/* Function to loop through all pixels and fill them with a colour */
void main()
{
	ivec2 pixCoords = ivec2(gl_GlobalInvocationID.xy), dims = imageSize(img_output);
	float maxx = 5.0, maxy = 5.0, x = float(pixCoords.x*2 - dims.x)/dims.x, y = float(pixCoords.y*2 - dims.y)/dims.y;
	pix = vec4(pixCoords.x, pixCoords.y, 0.0, 1.0);

	int nSamples = SAMPLES;
	int lenX;
	int startX;
	int currentX;
	vec3 result = vec3(0.0, 0.0, 0.0);

	for (int j = 0; j < nSamples; j++)
	{
		Ray ray;
		ray.org = vec3(xOrg, yOrg, 10.0);
		vec4 initial = vec4(normalize(vec3(x*maxx, y*maxy, 0.0) - ray.org).xyzz);
		ray.dir = vec3((rotMat * initial).xyz);
		ray.nrg = vec3(1.0f);

		lenX = 0;
		startX = -1;
		currentX = startX;

		for (int i = 1; i <= numHits; i++)
		{
			RayHit hit = Trace(ray);
			result += ray.nrg*Shade(ray,hit); 
		
			if (mutations > 0)
			{
				if (currentX == -1)
				{
					startX = currentX = newPathNode();
				}
				else
				{
					nodePool[currentX].nextA = newPathNode();
					currentX = nodePool[currentX].nextA;
				}
				nodePool[currentX].hit = hit;
				nodePool[currentX].ray = ray;
				nodePool[currentX].result = result;
				lenX++;
			}

			if (ray.nrg.x == 0.0 && ray.nrg.y == 0.0 && ray.nrg.z == 0.0)
				break;
		}
	}

	// currentX is now Last x

	result /= nSamples;

	int n = startX;
	while (n <= currentX)
	{
		nodePool[n].result /= nSamples;
		n = nodePool[n].nextA;
	}

	vec3 mutateResult = vec3(0);

	float luminanceX = luminance(nodePool[currentX].result);
	vec3 colorX = nodePool[currentX].result;

	mutateResult += colorX;

	int tmp;

	for (int i = 0; i < mutations; i++) {
		//Path y = path;

		int lenY = lenX;
		int currentY = startX;
		
		int ld = getLd(lenY);
		if (ld != 0)
		{
			lenY -= ld;

			for (int j = 0; j < lenY-1; j++)
				currentY = nodePool[currentY].nextA;
			
			int divergeNodeId = currentY;
			int redLen = lenY;
			Ray ray = nodePool[currentY].ray;
			vec3 result = nodePool[currentY].result;
			
			for (int i = redLen + 1; i <= numHits; i++)
			{
				RayHit hit = Trace(ray);
				result += ray.nrg * Shade(ray, hit);

				int newNode = newPathNode();
				nodePool[newNode].hit = hit;
				nodePool[newNode].ray = ray;
				nodePool[newNode].result = result;

				if (i == redLen + 1)
				{
					nodePool[currentY].nextM = newNode;
				}
				else
				{
					nodePool[currentY].nextA = newNode;
				}
				currentY = newNode;
				lenY++;

				if (ray.nrg.x == 0.0 && ray.nrg.y == 0.0 && ray.nrg.z == 0.0)
					break;
			}
			
			// currentY is lastY
			
			float luminanceY = luminance(nodePool[currentY].result);
			vec3 colorY = nodePool[currentY].result;

			float axy = min(1, luminanceY / luminanceX);

			mutateResult += axy * colorX + (1-axy) * colorY;

			if (rand() < axy)
			{
				//path = y;

				//swap nextM and nextA of divergeNodeId
				tmp = nodePool[divergeNodeId].nextM;
				nodePool[divergeNodeId].nextM = nodePool[divergeNodeId].nextA;
				nodePool[divergeNodeId].nextA = tmp;

				lenX = lenY;

				colorX = colorY;
				luminanceX = luminanceY;
			}
		}

		else
		{
			mutateResult += colorX;
		}
	}
	
	if (mutations > 0)
		pix = vec4(mutateResult/(mutations + 1), 1.0);	
	else
		pix = vec4(result, 1.0);
	imageStore(img_output, pixCoords, pix);
}