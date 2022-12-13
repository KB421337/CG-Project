/**
 * @file ShaderImpl.cpp
 * @author
 * @brief Contains the C++ implementation of the Path Tracing MLT Shader
 * @version 0.1
 * @date 2022-12-14
 * 
 * @copyright Copyright (c) 2022
 * 
 */

#include <algorithm>
#include <iostream>

#include "MltPixel.hpp"

using namespace std;

/**
 * @brief Initializes a RayHit object
 * 
 * @return RayHit object initialized
 */
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

/**
 * @brief Generates a random float from [0, 1] based on the
 * uniform distribution
 * 
 * @param e2 Random number generator engine
 * @param dist Uniform Distribution object
 * @return float Random float between 0 and 1
 */
float randfloat(mt19937& e2, uniform_real_distribution<float>& dist)
{
	return dist(e2);
}

/**
 * @brief Returns the clamped output (between 0 and 1) of the dot
 * product of the vectors multiplied with a float.
 * 
 * @param x first vector
 * @param y second vector
 * @param f float to multiply with
 * @return float clamped output between 0 and 1
 */
float sdot(vec3 x, vec3 y, float f)
{
	return glm::clamp(dot(x, y)*f, 0.0f, 1.0f);
}

/**
 * @brief Utility function to average the three colour channels
 * 
 * @param colour The colour channel to average.
 * @return float Energy/Intensity of the colour
 */
float nrg(vec3 colour)
{
	return dot(colour, vec3(1.0/3.0));
}

/**
 * @brief Converts a smoothness value to alpha for scattering distribution
 * 
 * @param s Smoothness Value
 * @return float Alpha
 */
float SmoothnessToPhongAlpha(float s)
{
	return pow(1000.0, s*s);
}

/**
 * @brief Find the tangent space given a normal
 * 
 * @param norm Normal of the surface
 * @return mat3 Tangent Space of the normal
 */
mat3 GetTgnSpace(vec3 norm)
{
	vec3 helper = vec3(1, 0, 0);
	if (abs(norm.x) > 0.99)
		helper = vec3(0, 0, 1);
	vec3 tgn = normalize(cross(norm, helper));
	vec3 binorm = normalize(cross(norm, tgn));

	return mat3(tgn, binorm, norm);
}

/**
 * @brief Sampling the hemisphere around the given normal and biases it based on the given alpha
 * 
 * @param norm Perfectly Reflected Ray off the hemisphere surface
 * @param alpha Alpha
 * @param e2 Random Number Generator
 * @param dist Uniform Distribution
 * @return vec3 Sampled Reflected Ray
 */
vec3 SampleHemi(vec3 norm, float alpha, mt19937& e2, uniform_real_distribution<float>& dist)
{
	float cosTheta = pow(randfloat(e2, dist), 1.0/(alpha + 1.0));
	float sinTheta = sqrt(max(0.0, 1.0 - cosTheta*cosTheta));
	float phi = 2*3.141593*randfloat(e2, dist);
	vec3 tgnSpaceDir = vec3(cos(phi)*sinTheta, sin(phi)*sinTheta, cosTheta);
	return GetTgnSpace(norm)*tgnSpaceDir;
}

/**
 * @brief Tests the given ray's intersection with the given triangle
 * 
 * @param ray Ray to test intersection with
 * @param vert0 First Vertex of the Triangle in AntiClockWise Order
 * @param vert1 Second Vertex of the Triangle in AntiClockWise Order
 * @param vert2 Third Vertex of the Triangle in AntiClockWise Order
 * @param t Barycentric Coordinate 1 of the Triangle in case of intersection
 * @param u Barycentric Coordinate 2 of the Triangle in case of intersection
 * @param v Barycentric Coordinate 3 of the Triangle in case of intersection
 * @return true Triangle intersects the ray and the intersection can be computed based on the
 * Barycentric coordinates
 * @return false Triangle does not intersect the ray
 */
bool intersectTgl_MT97(Ray ray, vec3 vert0, vec3 vert1, vec3 vert2, float& t, float& u, float& v)
{
	vec3 edge1 = vert1 - vert0, edge2 = vert2 - vert0;
	vec3 pvec = cross(ray.dir, edge2);
	float det = dot(edge1, pvec);
	if (det < 0.001)
		return false;
	float invDet = 1.0/det;
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

/**
 * @brief Tests ray intersection with the skybox/room at Infinity
 * 
 * @param ray Ray to intersect with
 * @param bestHit Returns the RayHit of the hit skybox if the skybox is visible to the ray
 */
void intersectRoom(Ray ray, RayHit& bestHit)
{
	float halfLen = 10000, nearestDist = 10000000.0, denom;
	bool testBack = true, testDown = true, testLeft = true;
	vec3 nearest, norm = vec3(0), pPt, pNorm;

	/* Front face */
	pPt = vec3(0.0, 0.0, -halfLen), pNorm = vec3(0.0, 0.0, 1.0);
	denom = dot(pNorm, ray.dir);
	if (abs(denom) > 0.0001f) 
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
		bestHit.albedo = vec3(0.1);
		bestHit.emission = vec3(0.0);
		bestHit.norm = norm;
		bestHit.pos = ray.org + nearestDist*ray.dir;
		bestHit.specular = vec3(0.1);
	}
}

/**
 * @brief Tests the intersection of the ray with the Ground and updates the bestHit
 * in case the ground plane is visible to the ray
 * 
 * @param ray Ray to test intersection with
 * @param bestHit RayHit to change after finding that the ground plane is visible
 */
void intersectGroundPlane(Ray ray, RayHit& bestHit)
{
	float t = (-ray.org.y - 17.0f)/ray.dir.y;
	if (t > 0.1f && (t < bestHit.dist || bestHit.dist == -1))
	{
		bestHit.dist = t;
		bestHit.pos = ray.org + t*ray.dir;
		bestHit.norm = vec3(0.0, 1.0, 0.0);
		bestHit.albedo = vec3(1.0);
		bestHit.specular = vec3(1.0);
		bestHit.emission = vec3(0.0);
		bestHit.smoothness = 1;
		bestHit.skybox = false;
	}
}

/* */
/**
 * @brief  Testing the intersection of a ray and a sphere and modifying the 
 * previous best hit if the sphere is visible to that ray
 * @param ray Ray to test intersection with
 * @param bestHit bestHit to modify in case of visibility
 * @param sph Sphere to test intersection and visibility with
 */
void intersectSph(Ray ray, RayHit& bestHit, Sph sph)
{
	vec3 d = ray.org - sph.pos;
	float p1 = -dot(ray.dir, d), p2sqr = p1*p1 - dot(d, d) + sph.rad*sph.rad;
	if (p2sqr < 0)
		return;
	float p2 = sqrt(p2sqr);
	float t = (p1 - p2) > 0 ? (p1 - p2) : (p1 + p2);
	if (t > 0.1 && (t < bestHit.dist || bestHit.dist == -1))
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

/**
 * @brief Goes through all the objects in the scene and bounces the
 * given ray off the closest object visible to it.
 * 
 * @param ray Ray to bounce off
 * @return RayHit Point at which the ray has bounced off
 */
RayHit Trace(Ray ray)
{
	RayHit bestHit = CreateRayHit();
	intersectRoom(ray, bestHit);
	intersectGroundPlane(ray, bestHit);
	intersectSph(ray, bestHit, Sph(vec3(-15.0f, -12.6, -30.0f), 4.0, vec3(0.0), vec3(1.0, 1.0f, 1.0f), 1.2, vec3(0.0)));
	intersectSph(ray, bestHit, Sph(vec3(-3.0f, -9.6, -75.0f), 7.0, vec3(0.0, 0.0, 0.0), vec3(1.0, 0.35, 0.45), 0.1, vec3(0.0)));
	intersectSph(ray, bestHit, Sph(vec3(1.0f, -14.6, -62.0f), 2.0, vec3(0.0, 0.0, 0.0), vec3(1.0, 1.0, 1.0), 0.0, vec3(0.0)));
	intersectSph(ray, bestHit, Sph(vec3(17.0f, -7.0, -45.0f), 3.0, vec3(1.0), vec3(0.1), 0.8, vec3(0.0, 10.0, 10.0)));

	vec3 wallEmission = vec3(0);
	vec3 wallSpecular = vec3(0.1);
	vec3 wallAlbedo = vec3(1);
	float wallSmoothness = 1;

	vec3 v0 = vec3(-40.0, -17.0, -65.0);
	vec3 v1 = vec3(15.0, -17.0, -65.0);
	vec3 v2 = vec3(-40.0, 6.0, -65.0);
	float t, u, v;
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
		}
	}

	v0 = vec3(-40.0, 6.0, -65.0);
	v1 = vec3(15.0, -17.0, -65.0);
	v2 = vec3(15.0, 6.0, -65.0);
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
		}
	}

	v0 = vec3(-30.0, 6.0, -65.0);
	v1 = vec3(-25.0, 6.0, 35.0);
	v2 = vec3(-25.0, -17.0, 35.0);
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
		}
	}

	v0 = vec3(-30, 6, -65.0);
	v1 = vec3(-25, -17, 35.0);
	v2 = vec3(-30, -17, -65.0);
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
		}
	}

	v0 = vec3(-25.0, 6.0, 15.0);
	v1 = vec3(15.0, -17.0, 15.0);
	v2 = vec3(-25.0, -17.0, 15.0);
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
		}
	}

	v0 = vec3(-25.0, 6.0, 15.0);
	v1 = vec3(15.0, 6.0, 15.0);
	v2 = vec3(15.0, -17.0, 15.0);
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
		}
	}

	v0 = vec3(15.0, 6.0, 15.0);
	v1 = vec3(15.0, 6.0, -35.0);
	v2 = vec3(15.0, -17.0, -35.0);
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
		}
	}

	v0 = vec3(15.0, 6.0, 15.0);
	v1 = vec3(15.0, -17.0, -35.0);
	v2 = vec3(15.0, -17.0, 15.0);
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
		}
	}

	v0 = vec3(15.0, 6.0, -65.0);
	v1 = vec3(11.0, -17.0, -30.0);
	v2 = vec3(15.0, -17.0, -65.0);
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
		}
	}

	v2 = vec3(15.0, 6.0, -65.0);
	v1 = vec3(11.0, -17.0, -30.0);
	v0 = vec3(15.0, -17.0, -65.0);
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
		}
	}

	v2 = vec3(15.0, 6.0, -65.0);
	v1 = vec3(11.0, 6.0, -30.0);
	v0 = vec3(11.0, -17.0, -30.0);
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
		}
	}

	v0 = vec3(15.0, 6.0, -65.0);
	v1 = vec3(11.0, 6.0, -30.0);
	v2 = vec3(11.0, -17.0, -30.0);
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
		}
	}

	v0 = vec3(-40.0, 6.0, 20.0);
	v1 = vec3(-40.0, 6.0, -65.0);
	v2 = vec3(15.0, 6.0, -65.0);
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
		}
	}

	v0 = vec3(15.0, 6.0, 15.0);
	v1 = vec3(-40.0, 6.0, 15.0);
	v2 = vec3(15.0, 6.0, -65.0);
	if (intersectTgl_MT97(ray, v0, v1, v2, t, u, v))
	{
		if (t > 0 && t < bestHit.dist)
		{
			bestHit.dist = t;
			bestHit.pos = ray.org + t*ray.dir;
			bestHit.norm = normalize(cross(v1 - v0, v2 - v0));
			bestHit.albedo = wallAlbedo;
			bestHit.specular = wallSpecular;
			bestHit.smoothness = wallSmoothness;
			bestHit.emission = wallEmission;
			bestHit.skybox = false;
		}
	}

	return bestHit;
}

/**
 * @brief Returns the color contribution from the hitting of the given ray at the rayhit
 * and updates the ray to the new reflected direction and its other properties.
 * 
 * @param ray Ray that raycasted
 * @param hit RayHit where the raycasted ray had hit
 * @param e2 Random Number Generator
 * @param dist Uniform Distribution Object
 * @return vec3 Color contribution by the ray and its ray hit
 */
vec3 Shade(Ray& ray, RayHit hit, mt19937& e2, uniform_real_distribution<float>& dist)
{
	if (hit.dist > 0.01)
	{
		if (hit.skybox)
		{
			ray.nrg *= hit.albedo;
			return hit.emission;
		}
		hit.albedo = min(1.0f - hit.specular, hit.albedo);

		float specProb = nrg(hit.specular), diffProb = nrg(hit.albedo), roulette = randfloat(e2, dist);

		float sum = specProb + diffProb;
		specProb /= sum;
		diffProb /= sum;
		if (roulette < specProb)
		{
			/* Diffuse reflection */
			ray.org = hit.pos + hit.norm*0.001f;
			float alpha = SmoothnessToPhongAlpha(hit.smoothness);
			ray.dir = SampleHemi(reflect(ray.dir, hit.norm), alpha, e2, dist);
			float f = (alpha + 2)/(alpha + 1.f);
			ray.nrg *= (1.0f/specProb)*hit.specular*sdot(hit.norm, ray.dir, f);
		}
		else
		{
			/* Specular reflection */
			ray.org = hit.pos + hit.norm*0.001f;
			ray.dir = SampleHemi(hit.norm, 1.0f, e2, dist);
			ray.nrg *= (1.0f/diffProb)*hit.albedo;
		}

		return hit.emission;
	}
	else
	{
		ray.nrg = vec3(0.0f);
		return vec3(0.0, 0.0, 0.0);
	}
}

/**
 * @brief Returns the number of nodes in the path
 * to delete.
 * 
 * @param xl Length of the path.
 * @param e2 Random Number Generator
 * @param dist Normal Distribution Object
 * @return int Number of nodes in the path to delete
 */
int getLd(int xl, mt19937& e2, normal_distribution<float>& dist)
{
	return dist(e2);
}

/* Assuming tentative transition function is symmetric. */

const int mutations = MUTATIONS;
const int numHits = NUM_HITS;

/**
 * @brief Return the luminance of the color throughput
 * 
 * @param colour Color for which the luminance has to be returned
 * @return float Luminance of the given color
 */
float luminance(vec3 colour)
{
	return 0.299*colour.x + 0.587*colour.y + 0.114*colour.z;
}

/**
 * @brief Sets the color of a single pixel.
 * Bottom Left is (0, 0), Top Right is (imgWidth-1, imgHeight-1)
 * @param x x-coordinate of the pixel
 * @param y y-coordinate of the pixel
 * @param imgWidth width of the framebuffer window
 * @param imgHeight height of the framebuffer window
 * @param frameBuffer pointer to the framebuffer
 * @param done Atomic int to track how many pixels have been rendered
 */
void drawPixel(int x, int y, int imgWidth, int imgHeight, vec4* frameBuffer, atomic<int>& done)
{
	random_device rd;
	mt19937 e2(rd());
	uniform_real_distribution<float> dist(0, 1);
	vec4 pix;
	ivec2 pixCoords = ivec2(x, y), dims = ivec2(imgWidth, imgHeight);
	float maxx = 5.0, maxy = 5.0, xD = float(pixCoords.x*2 - dims.x)/dims.x, yD = float(pixCoords.y*2 - dims.y)/dims.y;
	float xOrg = 1, yOrg = 2;
	int nSamples = SAMPLES, lenX = 0;
	vec3 rslt = vec3(0.0, 0.0, 0.0);
	bool flag = false;
	Path px, py;
	
	for (int j = 0; j < nSamples; j++)
	{

#ifndef BIDIR
		Ray ray;
		ray.org = vec3(xOrg, yOrg, 10.0);
		vec4 initial = vec4(normalize(vec3(xD*maxx, yD*maxy, 0.0) - ray.org), 1.0);
		ray.dir = vec3((initial));
		ray.nrg = vec3(1.0f);
		int lenX = 0;
		for (int i = 1; i <= numHits; i++)
		{
			RayHit hit = Trace(ray);
			rslt += ray.nrg*Shade(ray, hit, e2, dist);
			px.nodes[i - 1].hit = hit;
			px.nodes[i - 1].ray = ray;
			px.nodes[i - 1].rslt = rslt;
			lenX++;
			if (ray.nrg.x == 0.0 && ray.nrg.y == 0.0 && ray.nrg.z == 0.0)
				break;
		}

#else

		/*
		Sample Length of Camera Path
		lastLightPathVertex and Rslt
		lastCameraPathVertex and Rslt
		Check if unobstructed
		if yes, combine, else reject.
		*/

		// number of nodes = numHits + 1
		// cameraPathNodes max and min numHits - 1, 2
		int cameraPathNodes = randFloat()*(numHits - 3);
		cameraPathNodes++;
		int lightPathNodes = numHits + 1 - cameraPathNodes;


#endif

	}

	rslt /= nSamples;
	float luminanceX = luminance(rslt);
	vec3 colourX = rslt/luminanceX;
	vec3 mutRslt = vec3(0);
	mutRslt += colourX;
	list<float> dummy;
	float stddev = 1;
	normal_distribution<float> ldDist(numHits/2, stddev);

	for (int j = 0; j < mutations; j++)
	{
		int lenY = lenX;
		int ld = getLd(lenY, e2, ldDist);
		if (ld > 0)
		{
			ld = ld < (lenX - 1) ? ld : (lenX - 1);
			lenY -= ld;
			for (int i = 0; i < lenY; i++)
				py.nodes[i] = px.nodes[i];
			int redLen = lenY;
			Ray ray = py.nodes[lenY - 1].ray;
			vec3 rslt = py.nodes[lenY - 1].rslt;		
			for (int i = redLen + 1; i <= numHits; i++)
			{
				RayHit hit = Trace(ray);
				rslt += ray.nrg*Shade(ray, hit, e2, dist);
				py.nodes[i - 1].ray = ray;
				py.nodes[i - 1].hit = hit;
				py.nodes[i - 1].rslt = rslt;
				lenY++;
			}
			float luminanceY = luminance(rslt);
			vec3 colourY = rslt/luminanceY;
			float axy = min(1.0f, luminanceY/luminanceX);
			mutRslt += axy*colourX + (1 - axy)*colourY;
			if (randfloat(e2, dist) < axy)
			{
				px = py;
				colourX = colourY;
				luminanceX = luminanceY;
				lenX = lenY;
			}
		}
		else
			mutRslt += colourX;
	}
	mutRslt /= (mutations + 1.0);
	if (mutations > 0)
		pix = vec4(mutRslt.r, mutRslt.g, mutRslt.b, 1.0);
	else
		pix = vec4(rslt.r, rslt.g, rslt.b, 1.0);
	frameBuffer[y*imgWidth + x] = pix;
	done++;
}